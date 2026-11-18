---
name: plan-step-vs-pr-granularity
description: "plan step은 사고 단위, PR은 머지 단위. 동일 마이그레이션/도메인에 묶이면 N step이라도 단일 PR이 자연스럽다"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e1a288cd-b2f4-40b8-b74c-508786217e27
---

plan을 N step으로 분해해도, 그 step들이 동일 마이그레이션·도메인 변경에 종속되면 단일 PR로 묶는 게 정상이다. step 수 = PR 수가 아니다.

**Why:**
- backup-substitute-per-service plan은 T1~T11(마이그레이션/schemas/queries/actions/mail-template/mail-actions/EditForm/View/page/tests)로 분해됐지만 머지는 단일 PR #102 (commit 578a4ba). 모든 step이 동일 마이그레이션 `20260524_backup_request_services_substitute.sql`에 종속이라 stacked 분리가 회귀 회피·리뷰 이득 없이 비효율만 늘림.
- 반대로 회귀 안전망 spec 추가(#108/#110/#111)는 *독립 영향*이라 PR 분리가 맞았다 — 각 spec이 다른 도메인을 검증하므로 머지 순서/리뷰 영역이 분리됨.

**How to apply:**
- plan 작성 시 step 수와 별개로 "PR 경계"를 먼저 정한다. 기준: ① 같은 마이그레이션에 묶이면 동일 PR ② 같은 도메인의 schema·action·UI 변경은 동일 PR ③ 회귀 spec·viewer 가드처럼 독립 적용 가능한 변경은 분리 PR.
- plan 파일에 `pr_boundary:` 메타(optional) 또는 step 그룹화 표기로 의도 명시하면 후속 세션이 stacked 분리 유혹에 안 휘둘림.
- 머지 후 plan `status: in_progress` 자동 close 안 되므로, PR 머지 직후 plan front-matter에 `status: completed` + `pr:` + `completed:` 명시. 후속 세션의 stale plan 혼란 회피.

연관: [[feedback_stacked_pr_threshold]] — 역방향 케이스(stacked 5+ 누적 시 epic 조기 종료)와 짝.
