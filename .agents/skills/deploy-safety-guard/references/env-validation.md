# 환경변수 검증 (Fail-Fast) 가이드

애플리케이션 시작 시 필수 환경변수를 스키마로 검증하여, 잘못된 설정으로 인한 런타임 장애를 원천 차단한다. t3-env + Zod 기반 타입 안전한 환경변수 관리와 Edge Functions secrets, CI/CD 파이프라인 검증까지 다룬다.

---

## 핵심 개념

### Fail-Fast 원칙

서버가 시작되는 순간 모든 환경변수를 검증하여, 누락이나 형식 오류가 있으면 즉시 프로세스를 종료한다. 런타임에서 `undefined` 참조로 인한 장애보다 배포 실패가 훨씬 안전하다.

### 환경변수 분류

| 구분 | 접두사 | 노출 범위 | 예시 |
|------|--------|----------|------|
| 서버 전용 | 없음 | 서버 코드만 접근 | `DATABASE_URL`, `API_SECRET` |
| 클라이언트 | `NEXT_PUBLIC_` | 브라우저에 번들됨 | `NEXT_PUBLIC_API_URL` |
| 빌드 타임 | 없음 | 빌드 시점만 사용 | `SENTRY_AUTH_TOKEN` |
| Edge Functions | 없음 | Supabase 런타임 | `SUPABASE_SERVICE_ROLE_KEY` |

---

## 구현 패턴

### Before: 직접 process.env 접근 (위험)

```typescript
// 타입 안전성 없음, 누락 시 런타임 에러
const db = createClient(process.env.DATABASE_URL!); // undefined 가능!
const apiUrl = process.env.NEXT_PUBLIC_API_URL; // 오타 감지 불가
```

### After: t3-env 스키마 검증

```typescript
// src/env.ts
import { createEnv } from "@t3-oss/env-nextjs";
import { z } from "zod";

export const env = createEnv({
  server: {
    DATABASE_URL: z.string().url().startsWith("postgresql://"),
    API_SECRET: z.string().min(32, "API_SECRET must be at least 32 characters"),
    SENTRY_DSN: z.string().url().optional(),
    NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
    SUPABASE_SERVICE_ROLE_KEY: z.string().startsWith("eyJ"),
    REDIS_URL: z.string().url().startsWith("redis").optional(),
  },
  client: {
    NEXT_PUBLIC_API_URL: z.string().url(),
    NEXT_PUBLIC_SUPABASE_URL: z.string().url().includes(".supabase.co"),
    NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().startsWith("eyJ"),
    NEXT_PUBLIC_SENTRY_DSN: z.string().url().optional(),
  },
  // 실험적 기능: 빌드 타임 전용 변수
  experimental__runtimeEnv: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL,
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    NEXT_PUBLIC_SENTRY_DSN: process.env.NEXT_PUBLIC_SENTRY_DSN,
  },
  // 빈 문자열을 undefined로 처리
  emptyStringAsUndefined: true,
});
```

### 사용

```typescript
// 어디서든 타입 안전하게 접근
import { env } from "@/env";

const db = createClient(env.DATABASE_URL); // 타입: string (guaranteed)
const apiUrl = env.NEXT_PUBLIC_API_URL;    // 타입: string (guaranteed)
```

### Zod 고급 검증 예시

```typescript
server: {
  // URL 형식 + 특정 프로토콜
  DATABASE_URL: z.string().url().startsWith("postgresql://"),

  // 최소 길이 (보안 키)
  API_SECRET: z.string().min(32),

  // 열거형 (특정 값만 허용)
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),

  // 숫자 변환
  PORT: z.coerce.number().int().min(1000).max(65535).default(3000),

  // 불린 변환
  ENABLE_CACHE: z
    .string()
    .transform((v) => v === "true")
    .default("false"),

  // 콤마 구분 배열
  ALLOWED_ORIGINS: z
    .string()
    .transform((v) => v.split(",").map((s) => s.trim()))
    .default("http://localhost:3000"),

  // 조건부 필수 (프로덕션에서만)
  SENTRY_DSN: z.string().url().optional().refine(
    (val) => process.env.NODE_ENV !== "production" || val !== undefined,
    "SENTRY_DSN is required in production"
  ),
},
```

### Edge Functions secrets 관리

```bash
# secrets 등록 (프로젝트 연결 후)
supabase secrets set MY_SECRET_KEY=secret_value
supabase secrets set OPENAI_API_KEY=sk-...

# secrets 목록 확인
supabase secrets list

# 여러 secrets 한 번에 등록
supabase secrets set --env-file ./supabase/.env

# secrets 삭제
supabase secrets unset MY_SECRET_KEY
```

Edge Function 내에서 접근:

```typescript
// supabase/functions/my-function/index.ts
Deno.serve(async (req) => {
  // Deno.env.get()으로 접근
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    return new Response("Missing OPENAI_API_KEY", { status: 500 });
  }
  // ...
});
```

### Dev/Prod DB 분리 검증 스크립트

```typescript
// scripts/verify-env-separation.ts
import * as fs from "node:fs";
import * as path from "node:path";
import * as dotenv from "dotenv";

function loadEnv(filename: string): Record<string, string> {
  const filepath = path.resolve(process.cwd(), filename);
  if (!fs.existsSync(filepath)) return {};
  return dotenv.parse(fs.readFileSync(filepath));
}

function verify() {
  const devEnv = loadEnv(".env.local");
  const prodEnv = loadEnv(".env.production");

  const criticalKeys = [
    "NEXT_PUBLIC_SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "DATABASE_URL",
  ];

  const issues: string[] = [];

  for (const key of criticalKeys) {
    const devVal = devEnv[key];
    const prodVal = prodEnv[key];

    if (!devVal || !prodVal) {
      issues.push(`${key}: missing in ${!devVal ? ".env.local" : ".env.production"}`);
      continue;
    }

    if (devVal === prodVal) {
      issues.push(`${key}: IDENTICAL in dev and prod (dangerous!)`);
    }
  }

  if (issues.length > 0) {
    console.error("Environment separation issues found:");
    issues.forEach((issue) => console.error(`  - ${issue}`));
    process.exit(1);
  }

  console.log("Environment separation verified: dev and prod are properly isolated.");
}

verify();
```

### CI/CD 환경변수 검증 (GitHub Actions)

```yaml
# .github/workflows/deploy.yml
jobs:
  verify-env:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify required env vars
        run: |
          MISSING=""
          for VAR in DATABASE_URL SENTRY_DSN NEXT_PUBLIC_API_URL NEXT_PUBLIC_SUPABASE_URL; do
            if [ -z "${!VAR}" ]; then
              MISSING="$MISSING $VAR"
            fi
          done
          if [ -n "$MISSING" ]; then
            echo "Missing environment variables:$MISSING"
            exit 1
          fi
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          SENTRY_DSN: ${{ secrets.SENTRY_DSN }}
          NEXT_PUBLIC_API_URL: ${{ vars.NEXT_PUBLIC_API_URL }}
          NEXT_PUBLIC_SUPABASE_URL: ${{ vars.NEXT_PUBLIC_SUPABASE_URL }}
```

### .env.example 템플릿

```bash
# .env.example
# 서버 전용 (절대 NEXT_PUBLIC_ 붙이지 않기)
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
API_SECRET=your-secret-key-min-32-characters-long
SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIs...

# 클라이언트 (브라우저에 노출됨)
NEXT_PUBLIC_API_URL=http://localhost:3000/api
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIs...

# 선택사항
REDIS_URL=redis://localhost:6379
LOG_LEVEL=debug
```

---

## 체크리스트

- [ ] `@t3-oss/env-nextjs` + `zod` 설치
- [ ] `src/env.ts` 파일 생성 (서버/클라이언트 분리)
- [ ] 모든 `process.env` 직접 접근을 `env.XXX`로 교체
- [ ] `.env.example` 파일 존재 및 최신 상태
- [ ] `emptyStringAsUndefined: true` 설정
- [ ] 프로덕션 필수 변수에 `.optional()` 미사용 확인
- [ ] Zod 검증에 의미 있는 에러 메시지 추가
- [ ] Edge Functions secrets 등록 (`supabase secrets set`)
- [ ] Dev/Prod DB URL이 서로 다른 호스트
- [ ] CI/CD 파이프라인에 환경변수 사전 검증 스텝 추가
- [ ] 보안 키에 최소 길이 검증 (`.min(32)`)
- [ ] `NEXT_PUBLIC_` 접두사 오용 없음 (서버 전용 키에 사용 금지)

---

## 일반적 실수 & 해결

### 1. process.env 직접 접근 남발

**증상:** 오타로 인한 `undefined`, 타입 불일치
**원인:** `env.ts`를 만들었지만 기존 코드에서 `process.env` 직접 접근
**해결:** ESLint 규칙으로 강제:
```javascript
// eslint.config.js
{
  rules: {
    "no-restricted-syntax": [
      "error",
      {
        selector: "MemberExpression[object.name='process'][property.name='env']",
        message: "Use env from '@/env' instead of process.env",
      },
    ],
  },
}
```

### 2. 서버 전용 키에 NEXT_PUBLIC_ 접두사

**증상:** `DATABASE_URL`, `API_SECRET`이 클라이언트 번들에 노출
**원인:** `NEXT_PUBLIC_DATABASE_URL`로 잘못 설정
**해결:** 서버 전용 키는 접두사 없이 사용. t3-env의 `server`/`client` 분리가 이를 강제함

### 3. .env.local을 Git에 커밋

**증상:** 실제 시크릿이 리포지토리에 노출
**원인:** `.gitignore`에 `.env.local` 미포함
**해결:**
```bash
# .gitignore
.env
.env.local
.env.production
.env*.local
!.env.example
```

### 4. 빈 문자열을 유효한 값으로 처리

**증상:** 환경변수가 `""`로 설정되어 검증 통과 후 런타임 에러
**원인:** `emptyStringAsUndefined` 미설정
**해결:** `createEnv`에 `emptyStringAsUndefined: true` 추가

### 5. Edge Functions에서 환경변수 접근 실패

**증상:** `Deno.env.get("KEY")`가 `undefined` 반환
**원인:** `supabase secrets set`으로 등록하지 않음
**해결:**
```bash
supabase secrets set MY_KEY=my_value
# 배포 후 확인
supabase functions invoke my-function --debug
```

### 6. 환경별 .env 우선순위 혼동

**증상:** 프로덕션에서 개발 DB에 연결됨
**원인:** Next.js의 .env 파일 로딩 순서 오해
**해결:** Next.js 로딩 순서 (높은 우선순위 순):
1. `process.env` (시스템 환경변수)
2. `.env.$(NODE_ENV).local` (환경별 로컬)
3. `.env.local` (`test` 환경에서는 무시됨)
4. `.env.$(NODE_ENV)` (환경별)
5. `.env` (기본)

---

## 검증 명령어

```bash
# 1. t3-env 패키지 확인
grep -n "@t3-oss/env" package.json

# 2. 환경변수 스키마 파일 존재 확인
ls src/env.ts src/env.mjs env.ts env.mjs 2>/dev/null

# 3. process.env 직접 접근 건수 (0에 가까울수록 좋음)
grep -rn "process\.env\." --include="*.ts" --include="*.tsx" | grep -v "node_modules\|env.ts\|env.mjs\|next.config" | wc -l

# 4. .env.example 존재 확인
ls .env.example 2>/dev/null

# 5. NEXT_PUBLIC_ 서버 키 오용 확인
grep -n "NEXT_PUBLIC_.*SECRET\|NEXT_PUBLIC_.*PASSWORD\|NEXT_PUBLIC_.*DATABASE\|NEXT_PUBLIC_.*SERVICE_ROLE" .env* 2>/dev/null

# 6. .gitignore에 .env 파일 포함 확인
grep "\.env" .gitignore 2>/dev/null

# 7. Edge Functions secrets 확인
supabase secrets list 2>/dev/null || echo "Supabase CLI not available"

# 8. Dev/Prod DB 분리 확인
grep "SUPABASE_URL" .env.local .env.production 2>/dev/null | sort

# 9. 하드코딩된 DB URL 검출
grep -rn "supabase\.co" --include="*.ts" --include="*.tsx" | grep -v "node_modules\|\.env\|env\.ts" | head -5

# 10. CI/CD 환경변수 검증 스텝 확인
grep -rn "MISSING\|required.*env\|verify.*env" .github/workflows/*.yml 2>/dev/null | head -5
```
