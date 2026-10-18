---
name: stacked-pr-threshold
description: 4~5개 stacked PR이 누적되면 epic 조기 종료가 자연스러운 임계점. ROI 낮은 잔여 phase는 backlog로
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 25b0a44e-fed8-45b1-a59e-84141e808fce
---

Stacked PR이 4개를 넘으면 epic 조기 종료 판단을 적극 검토한다.

**Why**: 2026-05-12 InspectorListBody refactor epic에서 Phase 4까지 진행 후 PR #75~#78 (4개 stacked PR) 누적. Phase 5~7 진행 시 base retarget 부담 + 리뷰 부담 + 잔여 phase ROI 낮음 (primary goal "800줄 상한" 이미 달성). 추진력으로 계속하지 않고 사용자가 "B (조기 종료)" 추천 수용. 매몰비용 편향 회피.

**How to apply**:
- Stacked PR 3개까지는 무난, 4개부터는 의식적 평가
- Primary success criteria 달성 후 잔여 phase가 "nice-to-have" 부채 정리면 epic 조기 종료 추천
- 절대 멈추는 신호: (1) 매몰비용 사고 "여기까지 왔으니 끝까지", (2) 사용자 검토 시간 부족, (3) 다른 영역(이번 경우 ListPattern) 손대기 시작
- 종료 시 plan frontmatter `status: completed_partial` + `phases_done`/`phases_skipped` + 종료 근거 명시
