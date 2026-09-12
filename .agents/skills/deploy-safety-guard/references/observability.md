# Observability (가시성 확보) 가이드

Sentry를 중심으로 Next.js 앱의 에러 추적, 성능 모니터링, 알림 설정을 다룬다. 프로덕션 장애를 빠르게 감지하고 근본 원인을 추적하는 데 필요한 모든 설정을 포함한다.

---

## 핵심 개념

### 왜 Observability가 필요한가

- **MTTD(Mean Time To Detect)** 단축: 유저 제보 전에 에러를 감지
- **MTTR(Mean Time To Resolve)** 단축: 스택 트레이스 + 컨텍스트로 원인 빠르게 파악
- **프로액티브 대응**: 에러율 급증, 성능 저하를 알림으로 즉시 인지

### Sentry의 3가지 계층

| 계층 | 역할 | 설정 파일 |
|------|------|----------|
| Client | 브라우저 에러 캡처 | `sentry.client.config.ts` |
| Server | Node.js 서버 에러 캡처 | `sentry.server.config.ts` |
| Edge | Edge Runtime 에러 캡처 | `sentry.edge.config.ts` |

---

## 구현 패턴

### Before: Sentry 미설정 (에러 사각지대)

```typescript
// app/api/payment/route.ts
export async function POST(request: Request) {
  const body = await request.json();
  // 에러 발생 시 로그만 남기고 유실됨
  try {
    const result = await processPayment(body);
    return Response.json(result);
  } catch (error) {
    console.error("Payment failed:", error);
    return Response.json({ error: "Payment failed" }, { status: 500 });
  }
}
```

### After: Sentry 통합 에러 캡처

```typescript
// app/api/payment/route.ts
import * as Sentry from "@sentry/nextjs";

export async function POST(request: Request) {
  const body = await request.json();
  try {
    const result = await processPayment(body);
    return Response.json(result);
  } catch (error) {
    Sentry.captureException(error, {
      tags: { module: "payment", action: "process" },
      extra: { userId: body.userId, amount: body.amount },
    });
    return Response.json({ error: "Payment failed" }, { status: 500 });
  }
}
```

### Client 초기화

```typescript
// sentry.client.config.ts
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NEXT_PUBLIC_VERCEL_ENV || "development",

  // 프로덕션: 10% 샘플링, 개발: 전수 캡처
  tracesSampleRate: process.env.NODE_ENV === "production" ? 0.1 : 1.0,

  // 세션 리플레이 (프로덕션만)
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  integrations: [
    Sentry.replayIntegration({
      maskAllText: true,
      blockAllMedia: true,
    }),
  ],

  // PII 필터링
  beforeSend(event) {
    if (event.request?.cookies) {
      delete event.request.cookies;
    }
    if (event.request?.headers) {
      delete event.request.headers["authorization"];
      delete event.request.headers["cookie"];
    }
    return event;
  },
});
```

### Server 초기화

```typescript
// sentry.server.config.ts
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.VERCEL_ENV || "development",
  tracesSampleRate: process.env.NODE_ENV === "production" ? 0.2 : 1.0,

  beforeSend(event) {
    // 서버 측 PII 필터링
    if (event.user) {
      delete event.user.ip_address;
      delete event.user.email;
    }
    return event;
  },
});
```

### Edge 초기화

```typescript
// sentry.edge.config.ts
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.VERCEL_ENV || "development",
  tracesSampleRate: 0.1,
});
```

### next.config 통합 (Source Map 업로드)

```typescript
// next.config.ts
import { withSentryConfig } from "@sentry/nextjs";

const nextConfig = {
  // 기존 설정
};

export default withSentryConfig(nextConfig, {
  org: process.env.SENTRY_ORG,
  project: process.env.SENTRY_PROJECT,
  authToken: process.env.SENTRY_AUTH_TOKEN,

  silent: true,
  widenClientFileUpload: true,
  hideSourceMaps: true,
  disableLogger: true,

  // 빌드 시간 절약: CI에서만 소스맵 업로드
  sourcemaps: {
    deleteSourcemapsAfterUpload: true,
  },
});
```

### 커스텀 에러 바운더리

```typescript
// app/global-error.tsx
"use client";

import * as Sentry from "@sentry/nextjs";
import { useEffect } from "react";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);

  return (
    <html>
      <body>
        <main role="alert">
          <h1>문제가 발생했습니다</h1>
          <p>잠시 후 다시 시도해주세요.</p>
          <button onClick={reset}>다시 시도</button>
        </main>
      </body>
    </html>
  );
}
```

```typescript
// app/error.tsx
"use client";

import * as Sentry from "@sentry/nextjs";
import { useEffect } from "react";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);

  return (
    <section role="alert">
      <h2>오류가 발생했습니다</h2>
      <p>페이지를 새로고침하거나 다시 시도해주세요.</p>
      <button onClick={reset}>다시 시도</button>
    </section>
  );
}
```

### 알림 규칙 설정

Sentry 대시보드에서 설정하는 권장 알림 규칙:

| 알림 조건 | 임계값 | 채널 |
|----------|--------|------|
| 새로운 이슈 발생 | 즉시 | Slack #alerts |
| 에러율 급증 | 5분간 10건 초과 | Slack #critical |
| 트랜잭션 지연 | p95 > 3초 | Slack #performance |
| 이슈 재발(regression) | 즉시 | Slack #alerts + 이메일 |

---

## 체크리스트

- [ ] `@sentry/nextjs` 설치
- [ ] `sentry.client.config.ts` 생성 및 DSN 설정
- [ ] `sentry.server.config.ts` 생성 및 DSN 설정
- [ ] `sentry.edge.config.ts` 생성 (Edge Runtime 사용 시)
- [ ] `next.config.ts`에 `withSentryConfig` 래핑
- [ ] Source Map 업로드 설정 (`SENTRY_AUTH_TOKEN`)
- [ ] `app/global-error.tsx` 생성
- [ ] `app/error.tsx` 생성
- [ ] PII 필터링 (`beforeSend`) 설정
- [ ] 환경별 DSN 분리 (dev/staging/prod)
- [ ] `tracesSampleRate` 환경별 조정
- [ ] Slack/Discord 알림 연동

---

## 일반적 실수 & 해결

### 1. Source Map이 업로드되지 않음

**증상:** Sentry에서 minified 코드만 보임
**원인:** `SENTRY_AUTH_TOKEN` 미설정 또는 CI 환경에서 누락
**해결:**
```bash
# Vercel 환경변수에 추가
vercel env add SENTRY_AUTH_TOKEN production
vercel env add SENTRY_ORG production
vercel env add SENTRY_PROJECT production
```

### 2. 클라이언트 에러가 캡처되지 않음

**증상:** 서버 에러만 Sentry에 기록됨
**원인:** `sentry.client.config.ts` 누락 또는 `NEXT_PUBLIC_SENTRY_DSN` 미설정
**해결:** 클라이언트용 DSN은 반드시 `NEXT_PUBLIC_` 접두사 필요

### 3. PII 유출

**증상:** Sentry에 사용자 이메일, IP 등 개인정보 노출
**원인:** `beforeSend` 필터 미설정
**해결:** 위 PII 필터링 패턴 적용. `event.user`, `event.request.headers`, `event.request.cookies` 필터링

### 4. 과도한 이벤트 비용

**증상:** Sentry 월간 할당량 초과
**원인:** `tracesSampleRate: 1.0`으로 프로덕션 운영
**해결:**
- 프로덕션: `tracesSampleRate: 0.1` (10% 샘플링)
- `ignoreErrors`로 무시할 에러 패턴 등록
- `denyUrls`로 써드파티 스크립트 에러 필터

```typescript
Sentry.init({
  ignoreErrors: [
    "ResizeObserver loop",
    "Non-Error promise rejection",
    /Loading chunk \d+ failed/,
  ],
  denyUrls: [
    /extensions\//i,
    /^chrome:\/\//i,
    /^moz-extension:\/\//i,
  ],
});
```

### 5. 개발 환경에서 Sentry 노이즈

**증상:** 개발 중 의도적 에러까지 Sentry에 기록
**원인:** 환경 분기 없이 모든 환경에서 Sentry 활성화
**해결:**
```typescript
Sentry.init({
  enabled: process.env.NODE_ENV === "production",
  // 또는 특정 환경만
  enabled: ["production", "staging"].includes(
    process.env.VERCEL_ENV ?? ""
  ),
});
```

---

## 검증 명령어

```bash
# 1. Sentry 패키지 설치 확인
grep -n "@sentry/nextjs" package.json

# 2. 3개 설정 파일 존재 확인
ls sentry.client.config.ts sentry.server.config.ts sentry.edge.config.ts 2>/dev/null

# 3. next.config에 withSentryConfig 래핑 확인
grep -n "withSentryConfig" next.config.*

# 4. 에러 바운더리 파일 확인
ls app/global-error.tsx app/error.tsx 2>/dev/null

# 5. DSN 환경변수 설정 확인
grep -n "SENTRY_DSN\|NEXT_PUBLIC_SENTRY" .env* 2>/dev/null

# 6. PII 필터링 설정 확인
grep -n "beforeSend" sentry.*.config.ts 2>/dev/null

# 7. Source Map 설정 확인
grep -n "SENTRY_AUTH_TOKEN\|sourcemaps\|hideSourceMaps" next.config.* sentry.*.config.ts 2>/dev/null

# 8. 에러 캡처 사용 확인
grep -rn "Sentry.captureException\|Sentry.captureMessage" --include="*.ts" --include="*.tsx" | grep -v node_modules | wc -l
```
