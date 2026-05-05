---
name: sleep-build Phase 1 운영 한계
description: /sleep-build Phase 1만으로는 진짜 노트북 꺼도 되는 자율 불가 — 세션 alive 필요. Phase 2 (CronCreate 통합) 진입 전까지 (a) 세션 유지가 유일 운영 경로
type: project
originSessionId: f4ab8511-b7e1-4a20-91fe-9b3518ab81ac
---
**현재 상태 (2026-05-06 기준)**: vibe-flow v1.6.0 + dashboard v1.1.0. `/sleep-build` Phase 1 + Phase 1.1 머지 완료. 자율 사이클 (P0~P5+P-end + safety hook) 동작.

**Why:** Phase 1은 단발 사이클의 brainstorm→plan→TDD→commit→PR 시퀀스만 다룬다. Claude Code 세션이 active한 동안만 모델이 turn-by-turn 진행하고, 세션이 닫히면 사이클 중단. 즉 **maker가 자기 전 노트북 절전 끄고 Claude Code 세션 열어둔 채로** 자야 하는 한계가 있음. brainstorm spec의 Phase 2 (task 큐 + CronCreate 야간 스케줄) 진입 전까지는 진짜 "set and forget" 자율 불가.

**How to apply:**
- 사용자가 "지금 /sleep-build 돌릴 수 있나?" / "야간 자율 어떻게?" 물으면 **현재 4가지 운영 경로 중 (a) 세션 유지가 가장 단순/검증된 유일 경로**임을 명시:
  - (a) 노트북 절전 X + Claude Code 세션 열어둔 채 잠 (검증됨, dogfooding 1회 완료)
  - (b) `/loop` dynamic 결합 — ScheduleWakeup self-pace, **미검증**
  - (c) `/schedule` cron — Phase 2의 CronCreate 통합 필요, **미구현**
  - (d) tmux/nohup — OS 의존, 별도 setup
- 첫 실 야간 dogfooding 후 token cap 130k 적정성 calibration 데이터 수집 — Phase 2 진입 결정 입력
- Phase 2 진입 전 **단발 사이클** 가치 검증이 우선. maker 첫 실 야간 dogfooding 1회면 calibration 충분
- Phase 2 작업은 별도 brainstorm 후 진입 — `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md` 의 Phase 2 섹션이 출발점
