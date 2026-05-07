---
name: deploy-safety-guard
description: '"배포 안전 점검", "운영 체크", "인프라 검증", "Sentry 확인", "환경변수 검증", "백엔드 점검" 요청 시 사용.'
user-invocable: false
---

# Deploy Safety Guard

기업 운영 환경 배포 전 5단계 안전장치 점검 스킬

---

## Overview

이 스킬은 프로덕션 배포 전 백엔드/운영 안정성을 보장하기 위해 5단계 점검을 수행합니다:

| 단계 | 항목 | 점검 내용 |
|------|------|----------|
| 1 | 가시성 확보 | Sentry/Datadog 연동, 에러 리포팅 |
| 2 | 환경변수 검증 | Fail-Fast 패턴, 스키마 검증(Zod/t3-env) |
| 3 | 가용성 가드레일 | Timeout 설정, 지수 백오프 재시도 |
| 4 | 자원/비용 통제 | Rate Limit, Cost 상한, Idempotency |
| 5 | LLM 토큰 관리 | max_tokens, 입력 검증, 컨텍스트 압축 |

---

## Workflow

### Step 1: 가시성 확보 (Observability)

에러 추적 및 모니터링 도구 연동 상태를 확인합니다.

**체크리스트:**
- [ ] Sentry 또는 유사 에러 트래킹 SDK 설치
- [ ] 환경별 DSN 설정 (dev/staging/prod 분리)
- [ ] Source Map 업로드 설정
- [ ] 커스텀 에러 바운더리 구현
- [ ] 주요 트랜잭션 트레이싱 설정

```bash
# Sentry 패키지 확인
grep -n "@sentry" package.json

# Sentry 초기화 확인
grep -rn "Sentry.init\|sentry.init" --include="*.ts" --include="*.tsx" --include="*.js" | head -5

# 에러 바운더리 확인
grep -rn "ErrorBoundary\|error.tsx" --include="*.tsx" | head -5

# DSN 환경변수 확인
grep -rn "SENTRY_DSN\|NEXT_PUBLIC_SENTRY" --include="*.ts" --include="*.tsx" --include=".env*" | head -5
```

**권장 패턴:** [references/observability.md](references/observability.md) 참조

---

### Step 2: 환경변수 검증 (Fail-Fast)

애플리케이션 시작 시 필수 환경변수를 검증하는 Fail-Fast 패턴을 확인합니다.

**체크리스트:**
- [ ] 환경변수 스키마 정의 (Zod 또는 t3-env)
- [ ] 런타임 시작 시 검증 실행
- [ ] 누락된 변수에 대한 명확한 에러 메시지
- [ ] 타입 안전한 환경변수 접근
- [ ] .env.example 파일 존재

```bash
# t3-env 또는 Zod 환경변수 검증 확인
grep -rn "createEnv\|z.object" --include="env*.ts" --include="*.mjs" | head -10

# 환경변수 스키마 파일 확인
ls src/env.ts src/env.mjs env.ts env.mjs 2>/dev/null

# .env.example 존재 확인
ls .env.example .env.local.example 2>/dev/null

# process.env 직접 접근 (안티패턴) 확인
grep -rn "process\.env\." --include="*.ts" --include="*.tsx" | grep -v "node_modules\|env.ts\|env.mjs" | wc -l
```

**권장 패턴 (t3-env):**
```typescript
// src/env.ts
import { createEnv } from "@t3-oss/env-nextjs";
import { z } from "zod";

export const env = createEnv({
  server: {
    DATABASE_URL: z.string().url(),
    API_SECRET: z.string().min(32),
  },
  client: {
    NEXT_PUBLIC_API_URL: z.string().url(),
  },
  runtimeEnv: {
    DATABASE_URL: process.env.DATABASE_URL,
    API_SECRET: process.env.API_SECRET,
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL,
  },
});
```

#### 2-1. Edge Functions 환경변수 검증

Edge Functions 배포 및 실행에 필요한 환경변수를 확인합니다.

**체크리스트:**
- [ ] `SUPABASE_URL` 설정됨
- [ ] `SUPABASE_ANON_KEY` 설정됨
- [ ] `SUPABASE_SERVICE_ROLE_KEY` 설정됨 (관리자 함수용)
- [ ] Edge Functions 전용 시크릿 등록 (`supabase secrets list`)
- [ ] 로컬 `.env` 파일에 함수별 환경변수 정의

```bash
# Edge Functions 시크릿 목록 확인
supabase secrets list 2>/dev/null || echo "Supabase CLI not linked"

# Edge Functions 존재 확인
ls supabase/functions/*/index.ts 2>/dev/null | wc -l

# 함수 내 하드코딩된 키/URL 검출
grep -rn "sb-.*supabase\.co\|eyJhbGci" supabase/functions/ 2>/dev/null | head -5
```

#### 2-2. DB 환경 분리 검증

개발(dev)과 프로덕션(prod) 데이터베이스가 물리적으로 분리되어 있는지 확인합니다.

**체크리스트:**
- [ ] Dev/Prod DB URL이 서로 다른 호스트를 가리킴
- [ ] 코드에 DB URL 하드코딩 없음 (환경변수만 사용)
- [ ] 환경별 .env 파일 분리 (.env.local / .env.production)
- [ ] Supabase 사용 시 프로젝트가 환경별로 분리됨
- [ ] 시드 데이터가 프로덕션에 포함되지 않음

```bash
# Dev/Prod DB URL 분리 확인 (Supabase 호스트 비교)
grep "SUPABASE_URL" .env.local .env.production 2>/dev/null | sort

# 하드코딩된 DB URL 검출
grep -rn "supabase\.co\|\.supabase\." --include="*.ts" --include="*.tsx" | grep -v "node_modules\|.env" | head -10

# 환경별 .env 파일 존재 확인
ls .env.local .env.production .env.development 2>/dev/null

# 시드 스크립트가 환경 체크하는지 확인
grep -rn "NODE_ENV\|production" --include="seed*.ts" --include="seed*.sql" | head -5
```

**검증 판단 기준:**
- .env.local과 .env.production의 `SUPABASE_URL` 호스트가 **반드시** 다를 것
- `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`도 환경별로 다를 것
- 시드/마이그레이션 스크립트에 프로덕션 실행 방지 가드가 있을 것

---

### Step 3: 가용성 가드레일 (Resilience)

외부 서비스 호출의 안정성을 보장하는 패턴을 확인합니다.

**체크리스트:**
- [ ] API 호출 Timeout 설정 (기본 10초 이하 권장)
- [ ] 지수 백오프(Exponential Backoff) 재시도 로직
- [ ] Circuit Breaker 패턴 적용 (선택)
- [ ] 폴백(Fallback) 응답 정의
- [ ] 헬스체크 엔드포인트 구현
- [ ] Edge Functions 타임아웃 준수 (CPU 2초 / Wall Clock 150초)

```bash
# Timeout 설정 확인
grep -rn "timeout\|AbortController\|signal" --include="*.ts" --include="*.tsx" | grep -v node_modules | head -10

# 재시도 로직 확인
grep -rn "retry\|backoff\|exponential" --include="*.ts" --include="*.tsx" | head -5

# fetch 호출에 timeout 없는 경우 (위험)
grep -rn "fetch(" --include="*.ts" --include="*.tsx" | grep -v "timeout\|signal\|AbortController" | head -10

# 헬스체크 엔드포인트 확인
ls app/api/health/route.ts pages/api/health.ts 2>/dev/null
```

**권장 패턴:**
```typescript
// lib/fetch-with-retry.ts
async function fetchWithRetry(
  url: string,
  options: RequestInit & { timeout?: number; maxRetries?: number } = {}
) {
  const { timeout = 10000, maxRetries = 3, ...fetchOptions } = options;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    try {
      const response = await fetch(url, {
        ...fetchOptions,
        signal: controller.signal,
      });
      clearTimeout(timeoutId);
      if (response.ok) return response;
    } catch (error) {
      clearTimeout(timeoutId);
      if (attempt === maxRetries - 1) throw error;
      // 지수 백오프: 1s, 2s, 4s...
      await new Promise(r => setTimeout(r, Math.pow(2, attempt) * 1000));
    }
  }
}
```

---

### Step 4: 자원/비용 통제 (Cost Control)

API 남용 방지 및 비용 통제 메커니즘을 확인합니다.

**체크리스트:**
- [ ] Rate Limiting 구현 (IP/사용자별)
- [ ] API 비용 상한 설정 (월간/일간) — **(수동) 외부 대시보드에서 확인**
- [ ] Idempotency Key 적용 (결제/중요 작업)
- [ ] 요청 크기 제한 (bodyParser limit)
- [ ] 동시 요청 수 제한

```bash
# Rate Limiting 확인
grep -rn "rateLimit\|rate-limit\|upstash" --include="*.ts" --include="*.tsx" | head -5

# Idempotency 확인
grep -rn "idempotency\|Idempotent" --include="*.ts" --include="*.tsx" | head -5

# 요청 크기 제한 확인
grep -rn "bodyParser\|sizeLimit\|maxBodyLength" --include="*.ts" --include="*.tsx" --include="next.config.*" | head -5

# Redis/Upstash 사용 확인 (Rate Limiting용)
grep -n "upstash\|redis\|ioredis" package.json
```

**권장 패턴 (Upstash Rate Limiting):**
```typescript
// middleware.ts
import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, "10 s"), // 10초당 10요청
  analytics: true,
});

export async function middleware(request: NextRequest) {
  const ip = request.ip ?? "127.0.0.1";
  const { success, limit, remaining } = await ratelimit.limit(ip);

  if (!success) {
    return new Response("Too Many Requests", { status: 429 });
  }
}
```

**Idempotency 패턴:**
```typescript
// 결제 API에서 idempotency key 검증
const idempotencyKey = request.headers.get("Idempotency-Key");
if (!idempotencyKey) {
  return new Response("Idempotency-Key header required", { status: 400 });
}

const cached = await redis.get(`idempotent:${idempotencyKey}`);
if (cached) return Response.json(cached);
```

---

### Step 5: LLM 토큰 관리 (Token Management)

LLM API 사용 시 토큰 비용과 안정성을 관리합니다.

**체크리스트:**
- [ ] max_tokens 파라미터 명시적 설정
- [ ] 입력 길이 검증 (토큰 수 제한)
- [ ] 컨텍스트 압축/요약 전략
- [ ] 토큰 사용량 로깅
- [ ] 비용 알림 설정 (월간 상한) — **(수동) 외부 대시보드에서 확인**

```bash
# max_tokens 설정 확인
grep -rn "max_tokens\|maxTokens" --include="*.ts" --include="*.tsx" | head -10

# LLM 관련 패키지 확인
grep -n "openai\|anthropic\|@ai-sdk\|langchain" package.json

# 토큰 카운팅 확인
grep -rn "tiktoken\|countTokens\|tokenCount" --include="*.ts" --include="*.tsx" | head -5

# 스트리밍 응답 사용 확인
grep -rn "stream.*true\|streaming\|StreamingTextResponse" --include="*.ts" --include="*.tsx" | head -5
```

**권장 패턴:**
```typescript
// lib/llm-client.ts
const MAX_INPUT_TOKENS = 4000;
const MAX_OUTPUT_TOKENS = 1000;

async function callLLM(prompt: string) {
  // 입력 검증
  const inputTokens = countTokens(prompt);
  if (inputTokens > MAX_INPUT_TOKENS) {
    throw new Error(`Input too long: ${inputTokens} tokens (max: ${MAX_INPUT_TOKENS})`);
  }

  const response = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [{ role: "user", content: prompt }],
    max_tokens: MAX_OUTPUT_TOKENS, // 항상 명시!
    temperature: 0.7,
  });

  // 사용량 로깅
  console.log(`LLM Usage: ${response.usage?.total_tokens} tokens`);

  return response;
}
```

---

## Report Format

점검 완료 후 다음 형식으로 보고:

```markdown
# Deploy Safety Guard Report

**프로젝트:** {project_name}
**점검일:** {date}

---

## 1. 가시성 확보 (Observability)

| 항목 | 상태 | 비고 |
|------|------|------|
| Sentry 연동 | ✅/❌ | @sentry/nextjs 설치됨 |
| DSN 설정 | ✅/❌ | 환경별 분리 |
| Source Map | ✅/❌ | ... |
| 에러 바운더리 | ✅/❌ | ... |

**점수: X/10**

---

## 2. 환경변수 검증 (Fail-Fast)

| 항목 | 상태 | 비고 |
|------|------|------|
| 스키마 검증 | ✅/❌ | t3-env 사용 |
| Fail-Fast | ✅/❌ | 시작 시 검증 |
| .env.example | ✅/❌ | 존재함 |
| 타입 안전성 | ✅/❌ | ... |
| Edge Functions 환경변수 | ✅/❌ | SUPABASE_SERVICE_ROLE_KEY 등록 |
| Edge Functions 시크릿 | ✅/❌ | supabase secrets list 확인 |
| Dev/Prod DB 분리 | ✅/❌ | 호스트 상이 확인 |
| DB URL 하드코딩 없음 | ✅/❌ | 환경변수만 사용 |
| 환경별 .env 분리 | ✅/❌ | .env.local / .env.production |

**점수: X/10**

---

## 3. 가용성 가드레일 (Resilience)

| 항목 | 상태 | 비고 |
|------|------|------|
| Timeout 설정 | ✅/❌ | 10초 |
| 재시도 로직 | ✅/❌ | 지수 백오프 |
| 헬스체크 | ✅/❌ | /api/health |
| 폴백 응답 | ✅/❌ | ... |

**점수: X/10**

---

## 4. 자원/비용 통제 (Cost Control)

| 항목 | 상태 | 비고 |
|------|------|------|
| Rate Limiting | ✅/❌ | Upstash 사용 |
| Idempotency | ✅/❌ | 결제 API 적용 |
| 요청 크기 제한 | ✅/❌ | 10MB |
| 비용 상한 | ✅/❌ | ... |

**점수: X/10**

---

## 5. LLM 토큰 관리 (Token Management)

| 항목 | 상태 | 비고 |
|------|------|------|
| max_tokens 설정 | ✅/❌ | 1000 |
| 입력 검증 | ✅/❌ | 4000 토큰 제한 |
| 스트리밍 | ✅/❌ | 사용 중 |
| 사용량 로깅 | ✅/❌ | ... |

**점수: X/10**

---

## 종합 점수: X/50

| 영역 | 점수 | 등급 |
|------|------|------|
| 가시성 | X/10 | ⭐⭐⭐ |
| 환경변수 | X/10 | ⭐⭐⭐ |
| 가용성 | X/10 | ⭐⭐⭐ |
| 비용통제 | X/10 | ⭐⭐⭐ |
| LLM관리 | X/10 | ⭐⭐⭐ |

---

## 권장 조치

### 🔴 긴급 (배포 전 필수)
1. ...

### 🟠 권장 (1주 내 적용)
1. ...

### 🟢 개선 (점진적 적용)
1. ...
```

---

## Scoring Guide

각 단계별 10점 만점으로 채점:

| 점수 | 기준 |
|------|------|
| 10점 | 모든 항목 충족 + 베스트 프랙티스 |
| 8점 | 핵심 항목 충족 |
| 6점 | 기본 항목만 충족 |
| 4점 | 일부 항목 누락 |
| 2점 | 대부분 미구현 |
| 0점 | 완전 미구현 |

---

## References

- `references/observability.md` - Sentry/Datadog 연동 가이드
- `references/env-validation.md` - 환경변수 검증 패턴
- `references/resilience.md` - 가용성 패턴 (Timeout, Retry, Circuit Breaker)
- `references/rate-limiting.md` - Rate Limiting 구현
- `references/token-management.md` - LLM 토큰 관리 전략

---

## Quick Commands

```bash
# 전체 안전장치 빠른 점검
echo "=== 1. Observability ===" && grep -n "@sentry" package.json
echo "=== 2. Env Validation ===" && ls src/env.ts src/env.mjs 2>/dev/null
echo "=== 2-1. DB Separation ===" && grep "SUPABASE_URL" .env.local .env.production 2>/dev/null
echo "=== 3. Resilience ===" && grep -rn "timeout" --include="*.ts" | wc -l
echo "=== 4. Rate Limiting ===" && grep -n "upstash\|rateLimit" package.json
echo "=== 5. LLM Tokens ===" && grep -rn "max_tokens" --include="*.ts" | wc -l
```

---

## Troubleshooting

| 문제 | 원인 | 해결 |
|------|------|------|
| Sentry 이벤트 미수신 | DSN 미설정, 샘플링 0% | `SENTRY_DSN` 확인, `tracesSampleRate` 0.1 이상 설정 |
| 환경변수 검증 통과했는데 런타임 오류 | 타입만 검증하고 값 유효성 미검사 | Zod `.url()`, `.min(1)` 등 값 검증 추가 |
| Rate Limiting 미작동 | 미들웨어 순서 오류, Redis 미연결 | 미들웨어 체인 최상단 배치, `UPSTASH_REDIS_REST_URL` 확인 |
| Circuit Breaker 계속 OPEN | 임계값 너무 낮음 (1~2회) | `failureThreshold` 3~5회로 조정, `resetTimeout` 30초 |
| LLM 비용 폭발 | max_tokens 미설정, 스트리밍 미중단 | 요청별 `max_tokens` 필수, AbortController 타임아웃 적용 |
| 프로덕션 DB에 테스트 데이터 유입 | 환경 분리 미흡, 같은 SUPABASE_URL 사용 | `.env.local` / `.env.production` 분리, CI에서 검증 |

## Anti-patterns

| 패턴 | 문제 | 대안 |
|------|------|------|
| 환경변수 하드코딩 | 소스코드에 시크릿 노출 | `.env` + Zod 검증, Vercel Environment Variables |
| 모든 에러 `console.log`만 | 프로덕션에서 에러 추적 불가 | Sentry `captureException` + 알림 설정 |
| Retry 무한 반복 | 장애 전파, 비용 증가 | 최대 3회 + 지수 백오프 + Circuit Breaker |
| Rate Limit 없이 LLM API 노출 | 악의적 요청으로 비용 폭발 | IP/유저별 Rate Limiting 필수 적용 |
| 배포 전 점검 수동 실행만 | 점검 누락, 일관성 없음 | CI/CD 파이프라인에 자동화 통합 |
