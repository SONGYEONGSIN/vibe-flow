---
name: nightly-round-verification-trap
description: "야간 자율 라운드가 \"실패했다\"고 오판하게 만드는 두 가지 함정 — evolve/dash 공백과 원장 날짜 해석"
metadata: 
  node_type: memory
  type: project
  originSessionId: 6d405365-68f4-4f3b-8097-ea5407c0697b
  modified: 2026-08-01T09:42:10.928Z
---

`repick-dash-evolve-nightly`(18:00 UTC)의 성공 여부를 판단할 때 두 번 헛짚기 쉽다. 2026-08-01에 실제로 헛짚었다 — 정상 완주한 라운드를 "조용히 실패"로 사용자에게 보고했다.

**함정 1 — `git log main..origin/evolve/dash`가 비어 있는 것은 실패 증거가 아니다.**
주간 반증(`/dash-falsify apply`)이 라운드를 main에 머지하고 evolve/dash를 `reset --hard main` 하면, 성공한 라운드일수록 evolve/dash가 비어 보인다. 정상 상태와 실패 상태의 겉모습이 같다.

**함정 2 — `auto-ledger.jsonl`의 `date`는 발화일(UTC)이지 그 전날이 아니다.**
18:00Z 발화 = KST 익일 03:00이라 "어제 것"으로 착각한다. 실측: 07-30T18:00Z 발화 → `auto-login-r1`(date 2026-07-30), 07-31T18:01Z 발화 → `auto-404-r1`(date 2026-07-31).

**대신 볼 것 — 원격추적 reflog.**
`git reflog show origin/evolve/dash`에서 `fetch ...: fast-forward` 항목이 곧 클라우드 라운드가 푸시한 지점이다(`update by push`는 내가 민 것). 그 커밋의 `%cI`가 발화 시각 + 20~40분이면 완주한 것이다. `persist_session:false`라 RemoteTrigger에는 실행 로그가 없으므로 reflog가 사실상 유일한 사후 증거다.

**남은 진짜 미해결**: 프롬프트는 N=2("커밋 2개·entry 2건")를 요구하는데 07-15~07-31 전 발화가 라운드 1개만 냈다. 연속 라운드 절은 2026-08-01 #72에서야 스킬에 들어갔으므로, 08-01T18:00Z 발화가 2회를 실제로 도는지가 첫 관측 지점이다.

[[repick-dash-loop-state.md]]
