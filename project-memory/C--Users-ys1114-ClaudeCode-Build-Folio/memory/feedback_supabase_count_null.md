---
name: supabase-count-head-null
description: "supabase-js의 `select('*', { count: 'exact', head: true })` 응답에서 count: null + error: null이 나오면 RLS 차단이 아니라 테이블 부재일 수 있음 — 별도 select로 검증 필수"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 19eca088-be8d-4da4-b3f9-3c0dcc0c14ee
---

supabase-js로 prod schema 확인 시 `from(table).select('*', { count: 'exact', head: true })`만 호출하면 **테이블이 없어도 `error: null + count: null`로 응답되는 경우가 있다.** RLS 차단으로 오해하기 쉬움.

**Why:** PR-2 brainstorm에서 `backup_requests` 행수 확인할 때 count: null이 나와 "0행 (prod 적용 완료)"로 판단 → 실제로는 마이그레이션 미적용 상태였음. SQL Editor에서 `relation does not exist` 에러로 발견 + 사용자가 수동 적용해야 했음. brainstorm 가정 자체가 틀어진 case.

**How to apply:**
- prod 스키마 확인은 항상 **두 단계**:
  1. `select` 실제 컬럼 호출 (예: `select('id').limit(1)`) → 에러 검사 (`error?.message` 확인)
  2. 행수 count 확인은 그 다음
- count head=true 응답이 `null`이면 의심 — 테이블 부재 여부를 raw select로 재확인
- brainstorm/plan에서 "prod N행" 같은 가정을 세울 때 위 검증 필수
- 관련: [[plan-backup-services-fk]] PR-2 실 적용 시 발견된 함정
