---
name: codex-stall-watch
description: "Codex에 일을 넘기면 결과 파일과 함께 \"at capacity\" 등 오류를 감시 — 22시간 멈춘 걸 놓친 적 있음"
metadata:
  node_type: memory
  type: feedback
  originSessionId: b93db18f-8d8f-4238-ab03-9d8d2dc50701
  modified: 2026-10-27T12:29:01.830Z
---

Codex(오른쪽 분할 터미널)에 요청을 보낸 뒤에는 결과 파일만 기다리지 말고, `npm run codex -- tail`에서 "Selected model is at capacity" · rate/usage limit · stream error를 함께 감시한다(Monitor 루프로 1분 간격). 오류가 보이면 바로 다시 보내거나 사용자에게 알린다.

**Why:** 2026-10-26 r22 리뷰 요청이 "model at capacity"로 약 22시간 멈췄는데 결과 파일만 기다리다 놓쳤다. 사용자가 "작업 중?"을 두 번 물은 뒤에야 알아챘다.

**How to apply:** Codex send 직후 결과 파일 존재 + 오류 문구를 같이 보는 Monitor를 건다. 관련: [[verify-exit-code]]
