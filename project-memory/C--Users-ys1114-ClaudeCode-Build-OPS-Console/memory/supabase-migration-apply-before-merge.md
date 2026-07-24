---
name: supabase-migration-apply-before-merge
description: DB 스키마 변경 PR은 머지 전에 Supabase에 마이그레이션을 먼저 적용해야 함
metadata: 
  node_type: memory
  type: project
  originSessionId: d9101ff0-3022-4251-828f-56d57bfb1f20
---

`supabase/migrations/`의 마이그레이션은 파일로만 관리되고 Supabase에는 **수동 적용**된다(레포에 자동 apply 파이프라인 없음. `scripts/`는 점검만). 따라서 새 컬럼을 insert/select 하는 코드가 마이그레이션 적용 전에 배포되면 `column "X" does not exist`로 런타임 실패한다.

**Why:** Vercel은 main push 시 즉시 배포하는데, DB는 그 흐름과 분리되어 있다.

**How to apply:**
1. DB 스키마 변경 PR은 머지 전에 Supabase SQL Editor(또는 supabase CLI)로 마이그레이션 SQL을 먼저 실행하도록 안내.
2. **에이전트(이 작업 환경)는 DDL 직접 적용 불가** — `DATABASE_URL`(포트 6543 풀러) 직결이 ETIMEDOUT으로 차단되고, psql/pg도 미설치. service_role(REST)은 되지만 PostgREST는 DDL을 못 돌린다. → **사용자가 SQL Editor에서 직접 실행**해야 한다. (2026-06-08 weekly_report_runs 적용 시 확인)
3. 적용 여부는 service_role로 검증: `.env.local` 로드 후 `@supabase/supabase-js`로 `svc.from('<table>').select('<col>',{count:'exact',head:true})` — 에러 없으면 테이블 존재. insert→delete로 컬럼/check 제약, anon select로 RLS 차단까지 검증 가능.
4. 검증 통과 후 머지. [[ops-console-dev-workflow]]

**신규 테이블 GRANT 함정 (2026-07-07 contract_completion_snapshots에서 확인):** 새 public 테이블은 `grant all on public.<table> to service_role;`를 **반드시 마이그에 넣어야** 한다. `enable row level security` + service_role은 RLS를 우회하지만 **테이블 레벨 GRANT는 별도**라, 빠지면 service_role select/insert가 `42501 permission denied for table`로 실패한다. 기존 마이그 전부 `grant all ... to service_role` + `grant select/insert/update/delete ... to authenticated` 패턴을 따른다. (reports 테이블처럼 grant 없이도 되는 건 default privileges 우연. 명시 필수.)

**자동화 잡 수동 시딩 (cron 없이 즉시 실행):** 새 automation job은 기본 OFF라 cron 엔드포인트가 skip한다. ① REST로 `automation_settings` upsert `{job_id, enabled:true}` (on_conflict=job_id) → ② `POST http://localhost:3000/api/automations/run?jobId=<id>` `Authorization: Bearer $CRON_SECRET` 로 실행. 운영 cron은 cron-job.org에서 prod URL(`https://ops-console-psi.vercel.app/api/automations/run?jobId=<id>`) + 동일 Bearer 헤더로 등록(POST, 스케줄만 다름).
