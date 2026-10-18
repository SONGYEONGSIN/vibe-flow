# 가용성 가드레일 (Resilience) 가이드

외부 API 호출, 데이터베이스 쿼리 등 네트워크 I/O의 안정성을 보장하는 패턴을 다룬다. Timeout, 지수 백오프 재시도, Circuit Breaker, 폴백 전략, 헬스체크 엔드포인트 구현과 Edge Functions CPU 제한 대응까지 포함한다.

---

## 핵심 개념

### Resilience 3대 원칙

1. **Fail Fast**: 응답 없는 서비스에 무한 대기하지 않는다 (Timeout)
2. **Retry Smart**: 일시적 장애는 점진적으로 재시도한다 (Exponential Backoff)
3. **Degrade Gracefully**: 외부 서비스 장애 시 대체 응답을 제공한다 (Fallback)

### 장애 유형별 대응 전략

| 장애 유형 | 증상 | 대응 패턴 |
|----------|------|----------|
| 일시적 네트워크 오류 | 간헐적 timeout | 지수 백오프 재시도 |
| 서비스 완전 다운 | 모든 요청 실패 | Circuit Breaker + 폴백 |
| 느린 응답 | 응답 지연 증가 | Timeout + 조기 종료 |
| Rate Limit 초과 | 429 응답 | Retry-After 헤더 존중 |

---

## 구현 패턴

### Before: Timeout 없는 fetch (위험)

```typescript
// 외부 API 장애 시 무한 대기 → 서버 리소스 고갈
const response = await fetch("https://api.external.com/data");
const data = await response.json();
```

### After: AbortController Timeout 패턴

```typescript
async function fetchWithTimeout(
  url: string,
  options: RequestInit = {},
  timeoutMs: number = 10000
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    return response;
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error(`Request to ${url} timed out after ${timeoutMs}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
  }
}
```

### 지수 백오프 + Jitter 재시도

```typescript
interface RetryOptions {
  maxRetries?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
  timeoutMs?: number;
  retryableStatuses?: number[];
}

async function fetchWithRetry(
  url: string,
  options: RequestInit = {},
  retryOptions: RetryOptions = {}
): Promise<Response> {
  const {
    maxRetries = 3,
    baseDelayMs = 1000,
    maxDelayMs = 30000,
    timeoutMs = 10000,
    retryableStatuses = [408, 429, 500, 502, 503, 504],
  } = retryOptions;

  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const response = await fetchWithTimeout(url, options, timeoutMs);

      // 429: Retry-After 헤더 존중
      if (response.status === 429) {
        const retryAfter = response.headers.get("Retry-After");
        if (retryAfter && attempt < maxRetries) {
          const delayMs = Number(retryAfter) * 1000 || baseDelayMs;
          await sleep(delayMs);
          continue;
        }
      }

      // 재시도 가능한 상태 코드인지 확인
      if (!retryableStatuses.includes(response.status)) {
        return response;
      }

      if (attempt === maxRetries) return response;
    } catch (error) {
      lastError = error as Error;
      if (attempt === maxRetries) throw lastError;
    }

    // 지수 백오프 + jitter
    const exponentialDelay = baseDelayMs * Math.pow(2, attempt);
    const jitter = Math.random() * baseDelayMs;
    const delay = Math.min(exponentialDelay + jitter, maxDelayMs);
    await sleep(delay);
  }

  throw lastError ?? new Error("Max retries exceeded");
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
```

### Circuit Breaker 패턴

```typescript
type CircuitState = "CLOSED" | "OPEN" | "HALF_OPEN";

class CircuitBreaker {
  private state: CircuitState = "CLOSED";
  private failureCount = 0;
  private lastFailureTime = 0;

  constructor(
    private readonly failureThreshold: number = 5,
    private readonly resetTimeoutMs: number = 60000,
    private readonly halfOpenMaxAttempts: number = 1
  ) {}

  async execute<T>(fn: () => Promise<T>, fallback?: () => T): Promise<T> {
    if (this.state === "OPEN") {
      // 리셋 타임아웃 경과 시 HALF_OPEN 전환
      if (Date.now() - this.lastFailureTime > this.resetTimeoutMs) {
        this.state = "HALF_OPEN";
      } else {
        if (fallback) return fallback();
        throw new Error("Circuit breaker is OPEN");
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      if (fallback) return fallback();
      throw error;
    }
  }

  private onSuccess(): void {
    this.failureCount = 0;
    this.state = "CLOSED";
  }

  private onFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.failureCount >= this.failureThreshold) {
      this.state = "OPEN";
    }
  }

  getState(): CircuitState {
    return this.state;
  }
}

// 사용 예시
const externalApiBreaker = new CircuitBreaker(5, 60000);

async function getExternalData() {
  return externalApiBreaker.execute(
    // 주 로직
    async () => {
      const res = await fetchWithRetry("https://api.external.com/data");
      return res.json();
    },
    // 폴백
    () => ({ data: [], source: "cache", stale: true })
  );
}
```

### 폴백 전략

```typescript
// 전략 1: Stale Cache 폴백
async function getDataWithCacheFallback(key: string) {
  try {
    const fresh = await fetchFromApi(key);
    await cache.set(key, fresh, { ttl: 3600 });
    return fresh;
  } catch {
    const stale = await cache.get(key);
    if (stale) {
      console.warn(`Serving stale cache for key: ${key}`);
      return { ...stale, _stale: true };
    }
    throw new Error(`No data available for key: ${key}`);
  }
}

// 전략 2: Graceful Degradation
async function getRecommendations(userId: string) {
  try {
    return await fetchPersonalizedRecommendations(userId);
  } catch {
    // 개인화 실패 시 인기 콘텐츠로 대체
    return await fetchPopularContent();
  }
}

// 전략 3: 기본값 반환
async function getFeatureFlags() {
  try {
    return await fetchFeatureFlags();
  } catch {
    return {
      newCheckout: false,
      darkMode: true,
      // 보수적 기본값 (새 기능은 비활성화)
    };
  }
}
```

### 헬스체크 엔드포인트

```typescript
// app/api/health/route.ts
import { NextResponse } from "next/server";

interface HealthCheck {
  status: "healthy" | "degraded" | "unhealthy";
  timestamp: string;
  uptime: number;
  checks: Record<string, { status: string; latency?: number; error?: string }>;
}

export async function GET(): Promise<NextResponse<HealthCheck>> {
  const startTime = Date.now();
  const checks: HealthCheck["checks"] = {};

  // DB 연결 확인
  try {
    const dbStart = Date.now();
    await db.execute("SELECT 1");
    checks.database = { status: "ok", latency: Date.now() - dbStart };
  } catch (error) {
    checks.database = {
      status: "error",
      error: error instanceof Error ? error.message : "Unknown",
    };
  }

  // Redis 연결 확인
  try {
    const redisStart = Date.now();
    await redis.ping();
    checks.redis = { status: "ok", latency: Date.now() - redisStart };
  } catch (error) {
    checks.redis = {
      status: "error",
      error: error instanceof Error ? error.message : "Unknown",
    };
  }

  // 외부 API 확인
  try {
    const apiStart = Date.now();
    await fetchWithTimeout("https://api.external.com/health", {}, 5000);
    checks.externalApi = { status: "ok", latency: Date.now() - apiStart };
  } catch (error) {
    checks.externalApi = {
      status: "error",
      error: error instanceof Error ? error.message : "Unknown",
    };
  }

  const hasError = Object.values(checks).some((c) => c.status === "error");
  const allError = Object.values(checks).every((c) => c.status === "error");

  const health: HealthCheck = {
    status: allError ? "unhealthy" : hasError ? "degraded" : "healthy",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    checks,
  };

  const statusCode = allError ? 503 : 200;
  return NextResponse.json(health, { status: statusCode });
}
```

### Edge Functions CPU 2초 제한 대응

Supabase Edge Functions는 CPU 시간 2초, Wall Clock 150초 제한이 있다.

```typescript
// supabase/functions/heavy-task/index.ts
Deno.serve(async (req) => {
  // 1. 무거운 연산은 chunk 단위로 분리
  const items = await getItems();
  const CHUNK_SIZE = 50;

  for (let i = 0; i < items.length; i += CHUNK_SIZE) {
    const chunk = items.slice(i, i + CHUNK_SIZE);
    await processChunk(chunk); // 각 chunk는 CPU 제한 내에서 처리
  }

  // 2. 외부 API 호출은 Wall Clock 시간만 소모 (CPU 미사용)
  // → 여러 API 호출은 Promise.all()로 병렬화
  const [users, products, orders] = await Promise.all([
    fetchUsers(),
    fetchProducts(),
    fetchOrders(),
  ]);

  // 3. 정말 무거운 작업은 DB Function 또는 별도 서비스로 위임
  // await supabase.rpc('heavy_computation', { params })

  return new Response(JSON.stringify({ success: true }));
});
```

---

## 체크리스트

- [ ] 모든 외부 API 호출에 Timeout 설정 (10초 이하 권장)
- [ ] AbortController 기반 타임아웃 구현
- [ ] 지수 백오프 재시도 로직 (최소 3회 + jitter)
- [ ] 429 Retry-After 헤더 존중
- [ ] Circuit Breaker 적용 (핵심 외부 서비스)
- [ ] 폴백 응답 정의 (stale cache 또는 기본값)
- [ ] `/api/health` 헬스체크 엔드포인트 구현
- [ ] 헬스체크에 DB, Redis, 외부 API 상태 포함
- [ ] Edge Functions CPU 2초 제한 내 처리
- [ ] 무거운 작업은 chunk 분리 또는 DB Function 위임
- [ ] fetch 호출에 signal 전달 누락 없음

---

## 일반적 실수 & 해결

### 1. Timeout 없는 fetch 호출

**증상:** 외부 서비스 장애 시 요청이 무한 대기, 서버 커넥션 고갈
**원인:** 기본 fetch에 timeout이 없음
**해결:** 모든 fetch에 AbortController 적용. 유틸 함수로 래핑하여 강제

### 2. 고정 간격 재시도 (Fixed Interval Retry)

**증상:** 서비스 장애 시 재시도 요청이 동시에 몰려 "thundering herd" 발생
**원인:** `await sleep(1000)` 같은 고정 간격 재시도
**해결:** 지수 백오프 + jitter (랜덤 지연) 적용

### 3. 모든 에러를 재시도

**증상:** 400 Bad Request 같은 클라이언트 에러도 재시도하여 리소스 낭비
**원인:** HTTP 상태 코드 구분 없이 모든 에러 재시도
**해결:** `retryableStatuses`로 재시도 가능한 상태 코드 명시 (5xx, 408, 429만)

### 4. Circuit Breaker 없이 장애 전파

**증상:** 하나의 외부 서비스 장애가 전체 앱 응답 지연으로 전파
**원인:** 장애 서비스에 계속 요청을 보냄
**해결:** Circuit Breaker로 일정 실패 횟수 후 빠르게 폴백 반환

### 5. Edge Functions CPU 초과

**증상:** `Error: Worker exceeded CPU time limit`
**원인:** 루프 내 동기 연산이 CPU 2초 초과
**해결:**
- I/O 작업으로 대체 (I/O 대기는 CPU 시간에 포함되지 않음)
- 무거운 연산은 Postgres Function으로 위임
- chunk 단위 처리

### 6. 헬스체크가 항상 200 반환

**증상:** 서비스 장애인데 헬스체크는 정상
**원인:** 단순히 `{ status: "ok" }`만 반환하고 실제 의존성 확인 안 함
**해결:** DB, Redis, 핵심 외부 API까지 실제 연결 확인 후 상태 반환

---

## 검증 명령어

```bash
# 1. Timeout/AbortController 사용 확인
grep -rn "AbortController\|signal:" --include="*.ts" --include="*.tsx" | grep -v node_modules | wc -l

# 2. 재시도 로직 존재 확인
grep -rn "retry\|backoff\|exponential" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -10

# 3. timeout 없는 fetch 호출 탐지 (위험)
grep -rn "await fetch(" --include="*.ts" --include="*.tsx" | grep -v "signal\|timeout\|AbortController\|node_modules" | head -10

# 4. 헬스체크 엔드포인트 존재 확인
ls app/api/health/route.ts pages/api/health.ts 2>/dev/null

# 5. Circuit Breaker 구현 확인
grep -rn "CircuitBreaker\|circuit.*breaker\|OPEN.*HALF_OPEN\|CLOSED" --include="*.ts" | grep -v node_modules | head -5

# 6. Edge Functions CPU 사용 패턴 확인
grep -rn "for.*await\|while.*true\|JSON\.parse.*large" supabase/functions/ 2>/dev/null | head -5

# 7. 폴백 응답 구현 확인
grep -rn "fallback\|stale\|graceful\|degrade" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -5

# 8. 헬스체크 테스트 (로컬 서버 실행 중)
curl -s http://localhost:3000/api/health | jq '.status' 2>/dev/null
```
