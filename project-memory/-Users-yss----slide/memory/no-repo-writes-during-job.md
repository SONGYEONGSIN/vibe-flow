---
name: no-repo-writes-during-job
description: "실제 [만들기] 작업이 도는 동안 레포에 아무것도 쓰지 않는다 — Codex 리뷰 파일 하나로 6회차가 scope-violation 실패"
metadata:
  node_type: memory
  type: feedback
  originSessionId: b93db18f-8d8f-4238-ab03-9d8d2dc50701
  modified: 2026-10-27T13:02:45.226Z
---

실제 CLI 작업(job)이 generating/verifying 중일 때는 Claude도 Codex도 레포(docs/ · src/ · server/ · decks/ 등)에 파일을 쓰지 않는다. 리뷰 · 문서 수정 · 코드 수정은 작업이 끝난 뒤에 한다.

**Why:** 2026-10-27 6회차(j20261027124229-e4d9ba71)에서 제작 호출(19.5분)이 끝난 직후, 같은 시간에 Codex가 쓴 `docs/reviews/.../codex-impl-r25.md`를 앱의 범위 검사가 "보호 영역 변경"으로 잡아 scope-violation으로 실패했다. 검사는 누가 썼는지 구별하지 못한다(설계상 맞음). 사용자의 구독 시간이 낭비됐다.

**How to apply:** 작업을 시작하기 전에 Codex에 보낸 일이 모두 끝났는지 확인하고, 작업 중에는 읽기 전용 확인만 한다. src/ · server/ 수정은 개발 서버 재시작도 부를 수 있다. 관련: [[codex-stall-watch]]
