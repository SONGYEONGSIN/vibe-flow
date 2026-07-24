---
name: feedback-model-strategy-fable
description: "Fable 5 상시 운용 전략 — 기본 Fable+xhigh 유지, fan-out 서브에이전트는 반드시 model 오버라이드로 Fable 상속 차단"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e05e1af2-c9f3-40e4-bd57-dc2cb3ea6fd5
---

사용자 결정 (2026-07-11): 기본 모델 **Fable 5 + xhigh effort 유지** (Max 구독, $10/$50 = Opus 2×, thinking 상시 on). **서브에이전트는 전부 Opus + xhigh 단일화.**

**Why:** 메인 루프는 최고 품질(Fable), 위임은 품질/비용 균형점인 Opus xhigh로 통일. Fable은 5h/7d 한도를 Opus 대비 ~2배+ 소모하므로 fan-out이 세션 모델(Fable)을 상속하면 안 됨 — R10 감사 fan-out 기준 ~240K 토큰이 2배 요금이 될 뻔한 구조.

**How to apply:**
- **빌트인 fan-out** (`general-purpose`/`Explore`/`Plan`): Agent 도구 호출 시 **항상 `model: "opus"` 명시** (sonnet 아님 — 사용자 지시). effort는 Agent 도구에 파라미터 없음 → 세션 xhigh 상속으로 충족.
- **명명 에이전트 22개**: frontmatter `model: opus` + `effort: xhigh`로 전부 통일됨 (chore/agents-opus-xhigh, 2026-07-11 — 기존 opus9/sonnet12/haiku1 분포 및 PR #102 sonnet right-sizing을 사용자 지시로 되돌림). 조치 불필요.
- Workflow 스크립트 `agent()` 호출도 `opts.model: "opus"` (+`opts.effort: "xhigh"` 가능).
- 빠른 반복 작업 세션은 `/fast`(Opus 4.8 전용, Fable 불가) 고려.

관련: [[project-audit-20260601]] (R10 감사 fan-out 사례)
