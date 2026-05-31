---
name: db-migration-apply
description: OPS-Console에서 Supabase 마이그레이션(supabase/migrations/*.sql)을 운영 DB에 적용하는 방법
metadata: 
  node_type: memory
  type: reference
  originSessionId: 4ea42708-3b2c-4d16-9036-347a9ada1dcf
---

OPS-Console에는 Supabase CLI / psql / `pg` 패키지가 설치돼 있지 않다. `supabase/migrations/*.sql`은 보통 Supabase 대시보드 SQL editor로 수동 적용한다. `scripts/migration-status-check.mjs`는 적용이 아니라 **검증**(service_role count + anon RLS 차단)만 한다.

자동 적용이 필요하면: `.env`/`.env.local`의 `DATABASE_URL`(Supabase **트랜잭션 풀러**, host `aws-1-ap-northeast-2.pooler.supabase.com:6543`, `?pgbouncer=true`)을 사용한다. 절차:
1. `npm i pg --no-save` (package.json/lock 미변경)
2. node 인라인 스크립트로 `new pg.Client({ connectionString, ssl: { rejectUnauthorized: false } })` → `client.query(sqlFileText)` (멀티스테이트먼트 1회 실행, begin/commit 포함 OK)
3. 적용 후 `@supabase/supabase-js` service_role로 테이블 존재/write, anon으로 RLS 차단(42501) 검증

마이그레이션은 멱등(`create table if not exists` / `drop policy if exists`)으로 작성돼 재적용 안전. 추가 테이블은 신규 코드 배포 전에 먼저 적용해도 기존 코드와 무관(안전).

**Why:** 적용 경로가 repo에 자동화돼 있지 않고 CLI도 없어 매번 헤맬 수 있음. **How to apply:** 사용자가 "마이그레이션 적용" 요청 시 위 pg --no-save 인라인 방식 사용, 적용 후 반드시 RLS 검증.
