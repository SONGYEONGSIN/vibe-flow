---
name: auto-build는 야간 한정이 아닌 anytime 도구
description: /auto-build를 "maker가 자는 동안"으로만 프레이밍하면 안 됨 — 사용자가 언제든 트리거 가능한 자율 사이클 도구. 야간은 하나의 use case일 뿐
type: feedback
originSessionId: ded670e3-5091-423e-a9e5-8ae90b707796
---
`/auto-build`는 사용자가 **언제든** 트리거할 수 있는 자율 사이클 도구로 설계되어야 한다 (점심시간, 저녁, 주말, 또는 자기 전).

**Why:** 초기 brainstorm("노트북 켜놓고 잠")의 영향으로 메모리·plan·SKILL.md 전반에 "야간 / 수면 중 / maker가 자는 동안" 프레임이 박혔다. 사용자 의도는 더 넓다 — anytime 자율 cycle 도구. 야간은 가능한 use case 중 하나일 뿐 본질이 아님 (sleep-build → auto-build rename도 Phase 2 진입 후 동일 의도 재확인).

**How to apply:**
- "야간 dogfooding" 표현 지양 → "첫 실 task dogfooding" / "anytime 자율 사이클"
- 4 calibration 입력(token cap / iter cap / vote confidence / persona 일치율)은 시간대 무관하게 첫 실 task 1회면 수집됨
- 운영 경로 4가지 중 (a) 세션 유지의 의미: "자는 동안" 한정이 아닌 "사용자가 다른 일 하는 동안 무인 진행" — 야간/주간 무관
- 메모리·plan·SKILL.md 신규 또는 갱신 시 "야간 한정" 표현 회피, 야간은 예시로만 언급
- 사용자가 "지금 /auto-build 돌릴 수 있나?" 물으면 야간 가정 없이 답변
