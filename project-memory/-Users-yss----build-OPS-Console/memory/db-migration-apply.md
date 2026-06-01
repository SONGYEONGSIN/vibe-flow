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

**실제 drift 사고 (2026-06-01)**: 수동 적용이라 운영 DB가 drift함 — `receivables_mail_sends` / `receivables_match_runs` / `receivables_operator_mail_sends` 3개 이력 테이블이 운영에 미적용 상태였고, 잡들의 `admin.from(table).insert()`가 에러를 throw 안 하고 `{error: PGRST205}`로 조용히 무시(unchecked)해서 **이력이 안 남는데도 잡은 안 죽음**. 입금매칭 500의 진짜 원인은 별개(`SHAREPOINT_DEPOSIT_ITEM_ID` 미설정)였지만, 이 누락 테이블을 추적하다 발견. → 5개 마이그(테이블+RLS) pg로 적용 복구.

**재발 방지**: `.github/workflows/migration-drift-check.yml` + `scripts/migration-drift-check.mjs` 추가 — 매일 10:00 KST, 마이그의 `create table public.X`를 전부 추출해 운영 DB 존재 여부를 service_role로 점검, 누락 시 워크플로 실패. 드리프트 의심되면 이 워크플로 수동 dispatch 또는 `node scripts/migration-drift-check.mjs` 로컬 실행.

**Why:** 적용 경로가 repo에 자동화돼 있지 않고 CLI도 없어 매번 헤맬 수 있음 + 수동이라 drift 위험. **How to apply:** 사용자가 "마이그레이션 적용" 요청 시 위 pg --no-save 인라인 방식 사용, 적용 후 반드시 RLS 검증. drift 의심 시 migration-drift-check 실행.
