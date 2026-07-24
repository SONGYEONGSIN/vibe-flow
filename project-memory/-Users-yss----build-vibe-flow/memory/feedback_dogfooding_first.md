---
name: dogfooding-first principle
description: 자율/복잡 워크플로우는 5분 dogfooding이 1시간 plan보다 결정적 가치 — 실행 전 plan만으로는 design gap이 안 보인다
type: feedback
originSessionId: f4ab8511-b7e1-4a20-91fe-9b3518ab81ac
---
복잡한 자율/오케스트레이션 워크플로우(예: `/auto-build`)는 plan 단계만으로는 운영 결함이 안 보인다. **첫 dogfooding 사이클이 plan 1시간보다 결정적**이다.

**Why:** vibe-flow PR #30 (auto-build Phase 1) 머지 직후 dashboard PR #11 dogfooding (5분 watching)에서 4개 high/medium design gap (F1-F5) 즉시 발굴. plan 단계의 planner agent 분석 + 사용자 합의 게이트로도 못 잡은 결함들이 실행 5분에 드러남:
- F1 deployment fail-fast 부재
- F3 brainstorm clarification 무한 대기 위험
- F4 inline 등급 P2 skip 누락
- F5 verify project-aware 분기 누락

이 4건이 PR #32 (Phase 1.1)로 이어져 사이클 완결. dogfooding 없었으면 첫 실 야간 운영에서 silent fail로 발견됐을 항목.

**How to apply:**
- 자율/장시간/복잡 워크플로우 신기능은 **plan 머지 직후 dogfooding 사이클 1회 의무화** — 실 데이터 없이 다음 phase 진입 금지
- dogfooding은 watching 모드(현 세션 진행 + 즉시 finding 보고)면 충분, 실 야간/실 cron 굳이 안 필요
- 발견된 finding은 별도 issue + 후속 PR로 분리 — 첫 PR을 oversize 시키지 말 것
- 단순 추가 기능(작은 helper, 작은 hook)은 dogfooding 의무 X — 자율/복잡 영역 한정 적용

이 원칙은 auto-build뿐 아니라 향후 `/pair`, `/discuss`, 자율 retrospective 등 모든 오케스트레이션 워크플로우에 적용.
