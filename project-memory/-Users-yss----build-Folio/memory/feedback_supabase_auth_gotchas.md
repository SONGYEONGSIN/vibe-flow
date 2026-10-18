---
name: Supabase + Playwright e2e 셋업 시 함정 3가지
description: "Invalid login credentials" 에러는 두 가지 다른 원인 모두에 같은 메시지 / Supabase SQL "No rows returned" 해석 / Playwright는 .env.local 자동 로드 안 함
type: feedback
originSessionId: fa4d7468-5d81-4499-b474-305dc529d2ce
---
Folio 스텝 #1 셋업 중 발견한 함정. 다음 세션에서 같은 문제 만나면 바로 적용:

**1. `playwright.config.ts`에 `dotenv` 명시 로드 필수.**

```ts
import { config as loadEnv } from "dotenv";
loadEnv({ path: ".env.local" });
```

Next.js dev server는 `.env.local`을 자동 로드하지만 Playwright는 별도 Node 프로세스라서 `process.env.TEST_USER_*`가 `undefined`. spec 파일의 `test.skip(!process.env.TEST_USER_EMAIL, ...)` 가드가 항상 매칭돼서 모든 e2e가 영원히 skip되는 침묵형 실패. config 상단 한 줄로 해결.

**2. Supabase의 *"Invalid login credentials"*는 두 가지 다른 원인이 같은 메시지로 응답됨.**

원인 (구분 불가능):
- 비밀번호 불일치
- 이메일 미확인 (`email_confirmed_at IS NULL`)

보안상 user enumeration 방지 차원에서 의도. 진단 시 둘 다 한 번에 처리하는 SQL이 결정적:

```sql
UPDATE auth.users
SET
  email_confirmed_at = NOW(),
  encrypted_password = crypt('알려진_새_비밀번호', gen_salt('bf'))
WHERE email = '실_사용자_이메일';
```

`pgcrypto` extension은 Supabase에 기본 설치돼있음 (`crypt`/`gen_salt` 사용 가능).

**3. Supabase SQL Editor의 *"Success. No rows returned"*는 0 rows affected가 아님.**

UPDATE/INSERT/DELETE를 `RETURNING` 절 없이 실행하면 표시할 SELECT 결과가 없어서 이 메시지가 뜨는 것 — 실제 영향 받은 행 수와 무관. 정확히 확인하려면:

```sql
UPDATE ... WHERE ... RETURNING email, updated_at;
```

또는 별도 SELECT로 검증:

```sql
SELECT email, updated_at FROM auth.users WHERE email = '...';
```

**Why:** 2026-04-26 세션 — Folio가 Nexus와 Supabase 프로젝트 공유해서 e2e TEST_USER 셋업하려는데, 위 3가지 함정에 차례로 빠져 30분 지연. 사용자가 자기 GMAIL_USER/GMAIL_APP_PASSWORD 값을 TEST_USER_*로 헷갈려 SQL에 잘못 넣은 것도 한 원인.

**How to apply:**
- claude-builds 셋업 후 e2e 첫 실행 시 `playwright.config.ts`에 dotenv 로드 한 줄 명시 (Folio는 이미 추가됨).
- "Invalid login credentials" 보면 confirm 상태 + 비밀번호 둘 다 의심. 진단 SQL 먼저: `SELECT email, email_confirmed_at IS NOT NULL AS confirmed FROM auth.users;`
- Supabase SQL editor 결과 메시지 해석 시 "No rows returned" ≠ "0 rows affected". `RETURNING` 추가하거나 별도 SELECT로 검증.
- `.env.local`에 SMTP용 GMAIL_* 와 인증 테스트용 TEST_USER_* 둘 다 있을 때 사용자가 헷갈릴 수 있음. SQL 작성 시 길이/문자 패턴(예: Gmail App Password는 4자 4 그룹 공백 구분 16자)으로 변수 식별.
