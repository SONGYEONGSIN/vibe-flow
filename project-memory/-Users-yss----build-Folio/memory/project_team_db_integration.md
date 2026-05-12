---
name: 조직·권한(team) DB 연동 — EPIC CLOSED 2026-05-10
description: 팀 페이지 OPERATORS Supabase 영구 저장 epic 회고 + Supabase 운영 링크. 활성 추적 종료, reference 보존용
type: project
originSessionId: f1dae096-5cba-4988-9e0e-8dc18bebf09f
---

> **EPIC CLOSED — 2026-05-10**. 모든 핵심 항목 완료, 일회성 운영 도구(`scripts/restore-operator.mjs` GRANT 보강) 한 건만 우선순위 낮음으로 남음. 본 메모는 향후 reference(파일 위치 / Supabase 링크 / 마이그레이션 함정)로 보존.

## 브랜치 / PR
- 브랜치: `feat/dashboard-chrome-pivot` (PR #5)
- 가장 최근 commit: `c50bc9b` 기준 (deleted row 활성 목록에 표시 + 비활성화 시각)
- main에 squash merge 대기 중 (사용자가 작업 마무리 후 머지)

## 완료된 기능 (이번 작업 epic)

1. dashboard 상단 검정 띠 (AuthTitleBar) — login과 시각 통일
2. CrumbBar (washi-raised 띠) + ContentHead (cream) 분리 — mockup folio-dashboard.html 매칭
3. PageMeta over-line 4항목 (시프트 / 날짜 / count / 갱신)
4. PageHeader가 inspector wrapper 밖으로 — full width 보장
5. 조직·권한 페이지 DB 연동 (Supabase operators 테이블)
   - 17명 OPERATORS 영구 저장
   - 구성 편집 → 저장 시 createOperator/updateOperator server action
   - 직속 상사 select (자동 derive 또는 OPERATORS 16명 또는 본부장)
6. 상태 enum: `active / inactive / suspended / deleted`
   - 라벨: 활성 / 점검중 / 정지 / 삭제
   - deleted row는 활성 목록에 표시되되 `opacity-50 + line-through` 비활성 시각
   - 삭제 시 사유 textarea 필수
   - 복구: 상태=활성으로 변경 + 저장 (deleted_reason/at 자동 null)

## DB 마이그레이션 상태 (Supabase)

이미 실행됨:
- `20260509_operators_table.sql` — 테이블 + RLS + Seed 17명
- `20260509b_operators_grants.sql` — GRANT (42501 해결)
- `20260509c_operator_status_enum.sql` — 부분 실행됨. 다음 분리 SQL로 재실행:
  - `ALTER TABLE ... ADD COLUMN IF NOT EXISTS deleted_reason / deleted_at` ✓
  - `NOTIFY pgrst, 'reload schema'` ✓
  - `ALTER TABLE ... DROP/ADD CONSTRAINT operators_status_check` ✓

## 항목 트래킹 (closed)

1. ~~**Hydration mismatch**~~ ✅ d5a6691 + 9f4b4e3 (2026-05-10) — AuthStatusBar useSyncExternalStore로 해소
2. ~~**debug console.log 정리**~~ ✅ 4603449 (2026-05-09)
3. ~~**김지영 삭제/복구 흐름**~~ ✅ 2026-05-10 — 사용자 수동 사이클 검증 완료
4. ~~**TEST_USER_PASSWORD 동기화**~~ ✅ 2026-05-10 — `.env.local` ↔ Supabase user 정합 완료
5. ~~**모바일 sidebar 햄버거 트리거 회귀**~~ ✅ a864083 / PR #7 (2026-05-10) — AppBar 햄버거 재도입 + SidebarToggleProvider + e2e 2건 unskip
6. ~~**e2e parallel race**~~ ✅ CLAUDE.md 운영 메모로 흡수 (be89abb) — `--workers=1` 가이드 영구화
7. ~~**scripts/restore-operator.mjs**~~ ✅ 5f9d69e / PR #8 (2026-05-10) — `20260510c_operators_service_role_grant.sql` 마이그레이션이 `grant all on operators to service_role` 추가하여 동시 해결

## Supabase Dashboard 링크
- SQL Editor: https://supabase.com/dashboard/project/xvfckvihilmkkhzmqxnu/sql
- Auth Logs: https://supabase.com/dashboard/project/xvfckvihilmkkhzmqxnu/logs/auth-logs
- Auth Users: https://supabase.com/dashboard/project/xvfckvihilmkkhzmqxnu/auth/users
- Email Templates: https://supabase.com/dashboard/project/xvfckvihilmkkhzmqxnu/auth/templates
- Rate Limits: https://supabase.com/dashboard/project/xvfckvihilmkkhzmqxnu/auth/rate-limits
- Custom SMTP: https://supabase.com/dashboard/project/xvfckvihilmkkhzmqxnu/settings/auth

## 주요 파일 위치
- `src/app/dashboard/team/page.tsx` — server route (RSC + onPersist server action)
- `src/features/operators/queries.ts` — listOperators / listDeletedOperators / getOperatorById
- `src/features/operators/actions.ts` — create / update / restoreOperator
- `src/features/operators/schemas.ts` — zod + STATUS_LABEL export
- `src/app/dashboard/_components/patterns/ListPattern.tsx` — variant=team 분기, deleted opacity
- `src/app/dashboard/_components/inspector/InspectorListBody.tsx` — TeamView (인사 정보 + lookup)
- `supabase/migrations/` — 3개 마이그레이션 파일
