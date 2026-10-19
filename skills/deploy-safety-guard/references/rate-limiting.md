# Rate Limiting & 비용 통제 가이드

API 남용 방지, Idempotency Key를 통한 중복 요청 안전 처리, 요청 크기 제한, 부하 테스트 검증까지 다룬다. Upstash Redis 기반 슬라이딩 윈도우 구현을 중심으로 IP별/사용자별/엔드포인트별 전략을 포함한다.

---

## 핵심 개념

### Rate Limiting 알고리즘 비교

| 알고리즘 | 특징 | 적합한 상황 |
|---------|------|-----------|
| Fixed Window | 고정 시간 창 (e.g., 1분) | 단순한 API 제한 |
| Sliding Window | 이동 시간 창 | 균일한 트래픽 분산 |
| Token Bucket | 버스트 허용 + 평균 제한 | 순간 트래픽 허용 필요 시 |
| Leaky Bucket | 일정 속도 처리 | 균일한 처리량 필요 시 |

### 제한 대상별 전략

| 대상 | 식별자 | 권장 제한 | 용도 |
|------|--------|----------|------|
| IP | `request.ip` | 100req/10s | DDoS 방어 |
| 사용자 | `userId` (세션/JWT) | 60req/min | 공정 사용 보장 |
| 엔드포인트 | `path + method` | 개별 설정 | 리소스별 보호 |
| API Key | `x-api-key` 헤더 | 요금제별 | SaaS 과금 |

---

## 구현 패턴

### Before: Rate Limiting 없음 (위험)

```typescript
// 무제한 요청 허용 → 비용 폭주, DDoS 취약
export async function POST(request: Request) {
  const body = await request.json();
  const result = await callLLM(body.prompt); // 건당 $0.01
  return Response.json(result);
}
```

### After: Upstash 슬라이딩 윈도우

```typescript
// lib/rate-limit.ts
import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

const redis = Redis.fromEnv();

// IP 기반 글로벌 제한
export const globalLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(100, "10 s"),
  analytics: true,
  prefix: "ratelimit:global",
});

// 사용자 기반 API 제한
export const userLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(60, "1 m"),
  analytics: true,
  prefix: "ratelimit:user",
});

// LLM 엔드포인트 전용 (비용 높은 API)
export const llmLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(10, "1 m"),
  analytics: true,
  prefix: "ratelimit:llm",
});
```

### 미들웨어에서 글로벌 적용

```typescript
// middleware.ts
import { NextRequest, NextResponse } from "next/server";
import { globalLimiter } from "@/lib/rate-limit";

export async function middleware(request: NextRequest) {
  // API 라우트에만 적용
  if (!request.nextUrl.pathname.startsWith("/api")) {
    return NextResponse.next();
  }

  const ip = request.headers.get("x-forwarded-for") ?? "127.0.0.1";
  const { success, limit, remaining, reset } = await globalLimiter.limit(ip);

  if (!success) {
    return new NextResponse("Too Many Requests", {
      status: 429,
      headers: {
        "X-RateLimit-Limit": limit.toString(),
        "X-RateLimit-Remaining": "0",
        "X-RateLimit-Reset": reset.toString(),
        "Retry-After": Math.ceil((reset - Date.now()) / 1000).toString(),
      },
    });
  }

  const response = NextResponse.next();
  response.headers.set("X-RateLimit-Limit", limit.toString());
  response.headers.set("X-RateLimit-Remaining", remaining.toString());
  response.headers.set("X-RateLimit-Reset", reset.toString());
  return response;
}

export const config = {
  matcher: "/api/:path*",
};
```

### 엔드포인트별 사용자 제한

```typescript
// app/api/chat/route.ts
import { llmLimiter } from "@/lib/rate-limit";
import { auth } from "@/lib/auth";

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { success, remaining } = await llmLimiter.limit(session.user.id);
  if (!success) {
    return Response.json(
      { error: "Rate limit exceeded. Please wait before sending another message." },
      { status: 429 }
    );
  }

  const body = await request.json();
  const result = await callLLM(body.prompt);
  return Response.json(result);
}
```

### Idempotency Key 전체 구현

```typescript
// lib/idempotency.ts
import { Redis } from "@upstash/redis";

const redis = Redis.fromEnv();
const IDEMPOTENCY_TTL = 86400; // 24시간

interface IdempotentResult {
  statusCode: number;
  body: unknown;
  headers?: Record<string, string>;
}

export async function withIdempotency(
  key: string,
  fn: () => Promise<IdempotentResult>
): Promise<IdempotentResult> {
  // 1. 기존 결과 확인
  const cached = await redis.get<IdempotentResult>(`idempotent:${key}`);
  if (cached) {
    return cached;
  }

  // 2. 락 획득 (동시 실행 방지)
  const lockKey = `idempotent-lock:${key}`;
  const lockAcquired = await redis.set(lockKey, "1", { nx: true, ex: 30 });
  if (!lockAcquired) {
    // 이미 처리 중 → 잠시 대기 후 캐시 확인
    await new Promise((r) => setTimeout(r, 1000));
    const result = await redis.get<IdempotentResult>(`idempotent:${key}`);
    if (result) return result;
    throw new Error("Request is being processed. Please retry.");
  }

  try {
    // 3. 실제 로직 실행
    const result = await fn();

    // 4. 결과 캐싱
    await redis.set(`idempotent:${key}`, result, { ex: IDEMPOTENCY_TTL });

    return result;
  } finally {
    // 5. 락 해제
    await redis.del(lockKey);
  }
}
```

### 결제 API에 Idempotency 적용

```typescript
// app/api/payment/route.ts
import { withIdempotency } from "@/lib/idempotency";

export async function POST(request: Request) {
  const idempotencyKey = request.headers.get("Idempotency-Key");
  if (!idempotencyKey) {
    return Response.json(
      { error: "Idempotency-Key header is required" },
      { status: 400 }
    );
  }

  // UUID v4 형식 검증
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(idempotencyKey)) {
    return Response.json(
      { error: "Idempotency-Key must be UUID v4 format" },
      { status: 400 }
    );
  }

  const body = await request.json();

  const result = await withIdempotency(idempotencyKey, async () => {
    const payment = await processPayment({
      userId: body.userId,
      amount: body.amount,
      currency: body.currency,
    });

    return {
      statusCode: 200,
      body: { paymentId: payment.id, status: payment.status },
    };
  });

  return Response.json(result.body, { status: result.statusCode });
}
```

### 요청 크기 제한

```typescript
// next.config.ts
const nextConfig = {
  // API 라우트 요청 크기 제한
  experimental: {
    serverActions: {
      bodySizeLimit: "2mb",
    },
  },
};

export default nextConfig;
```

```typescript
// app/api/upload/route.ts
export async function POST(request: Request) {
  // Content-Length 사전 검증
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  const MAX_SIZE = 10 * 1024 * 1024; // 10MB

  if (contentLength > MAX_SIZE) {
    return Response.json(
      { error: `Request body too large. Maximum size: ${MAX_SIZE / 1024 / 1024}MB` },
      { status: 413 }
    );
  }

  const body = await request.json();
  // ...
}
```

### API Route별 크기 제한 (Route Segment Config)

```typescript
// app/api/chat/route.ts
export const runtime = "edge"; // 또는 "nodejs"

// Next.js 15+ route segment config
export const maxDuration = 30; // 초

export async function POST(request: Request) {
  // 텍스트 입력 크기 제한
  const body = await request.json();
  if (typeof body.message === "string" && body.message.length > 10000) {
    return Response.json(
      { error: "Message too long. Maximum 10,000 characters." },
      { status: 400 }
    );
  }
  // ...
}
```

### 429 응답 + Retry-After 클라이언트 처리

```typescript
// lib/api-client.ts
async function apiCall(url: string, options?: RequestInit): Promise<Response> {
  const response = await fetch(url, options);

  if (response.status === 429) {
    const retryAfter = response.headers.get("Retry-After");
    const waitMs = retryAfter ? Number(retryAfter) * 1000 : 60000;

    // UI에 남은 시간 표시 가능
    throw new RateLimitError(
      `Rate limited. Retry after ${Math.ceil(waitMs / 1000)}s`,
      waitMs
    );
  }

  return response;
}

class RateLimitError extends Error {
  constructor(
    message: string,
    public retryAfterMs: number
  ) {
    super(message);
    this.name = "RateLimitError";
  }
}
```

---

## 체크리스트

- [ ] Upstash Redis + `@upstash/ratelimit` 설치
- [ ] 글로벌 IP 기반 Rate Limiting (미들웨어)
- [ ] 사용자별 Rate Limiting (인증 필요 API)
- [ ] LLM/비용 높은 엔드포인트 별도 제한
- [ ] 429 응답에 `Retry-After` 헤더 포함
- [ ] 응답에 `X-RateLimit-Limit/Remaining/Reset` 헤더
- [ ] Idempotency Key 구현 (결제/중요 작업)
- [ ] Idempotency Key UUID 형식 검증
- [ ] 동시 실행 방지 락 (Redis NX)
- [ ] 요청 크기 제한 (Content-Length 사전 검증)
- [ ] 텍스트 입력 길이 제한
- [ ] 월간 API 비용 상한 알림 설정
- [ ] 부하 테스트로 Rate Limit 동작 검증

---

## 일반적 실수 & 해결

### 1. IP 기반 제한만 적용

**증상:** 같은 사용자가 여러 IP로 우회
**원인:** IP 기반 제한만 있고 사용자 기반 제한 없음
**해결:** IP + 사용자 ID 이중 제한 적용

### 2. Rate Limit 헤더 미반환

**증상:** 클라이언트가 남은 요청 수를 모르고 무작정 재시도
**원인:** 429 응답만 반환하고 `Retry-After` 헤더 미포함
**해결:** 모든 응답에 `X-RateLimit-*` 헤더, 429에 `Retry-After` 추가

### 3. Idempotency Key 없이 결제 API 운영

**증상:** 네트워크 오류 시 이중 결제 발생
**원인:** 클라이언트 재시도가 서버에서 새 결제로 처리됨
**해결:** Idempotency Key 필수화 + Redis 결과 캐싱

### 4. Redis 장애 시 Rate Limiting 중단

**증상:** Redis 다운 시 Rate Limiting 미적용 → 무제한 요청
**원인:** Redis 에러를 catch하고 요청을 통과시킴
**해결:**
```typescript
// Redis 장애 시 보수적으로 차단 or 인메모리 폴백
try {
  const { success } = await limiter.limit(ip);
  if (!success) return rateLimitResponse();
} catch {
  // 옵션 1: 보수적 차단 (보안 우선)
  return rateLimitResponse();
  // 옵션 2: 인메모리 폴백 (가용성 우선)
  // return inMemoryLimiter.check(ip) ? next() : rateLimitResponse();
}
```

### 5. 요청 크기 무제한

**증상:** 대용량 요청으로 서버 메모리 고갈
**원인:** `request.json()` 호출 전 크기 검증 없음
**해결:** `Content-Length` 사전 검증 + `next.config.ts` 크기 제한

### 6. 부하 테스트 미실시

**증상:** 프로덕션에서 Rate Limit 설정이 너무 엄격하거나 느슨함
**원인:** 실제 트래픽 패턴 미반영
**해결:**
```bash
# k6로 부하 테스트
k6 run --vus 50 --duration 30s load-test.js

# 또는 간단한 curl 테스트
for i in $(seq 1 20); do
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/chat
done
```

---

## 검증 명령어

```bash
# 1. Upstash 패키지 확인
grep -n "@upstash/ratelimit\|@upstash/redis" package.json

# 2. Rate Limiting 구현 확인
grep -rn "Ratelimit\|rateLimit\|rate-limit" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -10

# 3. 미들웨어에서 Rate Limiting 확인
grep -n "ratelimit\|rate.*limit\|429" middleware.ts 2>/dev/null

# 4. Idempotency 구현 확인
grep -rn "idempotency\|Idempotent\|idempotent" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -5

# 5. 요청 크기 제한 확인
grep -rn "bodySizeLimit\|content-length\|MAX_SIZE\|maxBodyLength" --include="*.ts" --include="next.config.*" | grep -v node_modules | head -5

# 6. 429 응답 + Retry-After 헤더 확인
grep -rn "Retry-After\|X-RateLimit" --include="*.ts" | grep -v node_modules | head -5

# 7. Redis 환경변수 확인
grep -n "UPSTASH_REDIS_REST_URL\|UPSTASH_REDIS_REST_TOKEN" .env* 2>/dev/null

# 8. Rate Limit 동작 테스트 (로컬)
for i in $(seq 1 15); do curl -s -o /dev/null -w "Request $i: %{http_code}\n" http://localhost:3000/api/chat; done
```
