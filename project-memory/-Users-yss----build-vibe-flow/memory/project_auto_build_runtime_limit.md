---
name: auto-build 운영 한계 (Phase 2 머지 후)
description: /auto-build Phase 2(Ralph loop + persona vote) 머지 완료. 자동 결정 + 분할 PR은 무인 처리되나 cron 스케줄(Phase 3) 전까지는 여전히 세션 alive 필요. 4 운영 경로 중 (a) 세션 유지만 검증됨, calibration 미수집
type: project
originSessionId: f4ab8511-b7e1-4a20-91fe-9b3518ab81ac
---

**현재 상태 (2026-05-08 기준)**: vibe-flow `main` Phase 2 머지 완료 (PR #39 + rename #40). `/auto-build` 자율 사이클이 multi-iteration Ralph loop + 24-agent persona vote로 확장됨. ambiguity 발생 시에도 사용자 입력 요청 없이 카테고리별 3~5 persona dispatch → moderator 중재 → 결정 자동 채택. file_cap 75% 도달 시 P5 push + 새 branch 진입을 N(기본 30) iteration까지 반복.

**프레이밍 주의**: `/auto-build`는 **사용자가 언제든** 트리거할 수 있는 자율 사이클 도구다. 야간은 가능한 use case 중 하나일 뿐, 본질이 아님. 점심시간/저녁/주말/잠자기 전 모두 동일하게 적용. 관련 피드백: `feedback_auto_build_anytime.md`.

**Why (Phase 2 머지로 해소된 한계):**
- 단발 1 사이클 → multi-iteration Ralph loop (file_cap 도달 시 PR 분할 자동)
- ambiguity 발생 시 사용자 입력 대기 → 24-agent persona vote 자동 결정
- HARD-GATE 전체 등급 task / 디자인 결정 task 스킵 → 모두 vote/Ralph 분할로 처리

**Why (잔존 한계, Phase 3 진입 전까지):**
- 모델 turn-by-turn 진행은 여전히 Claude Code 세션 active를 요구. **세션이 닫히면 사이클 중단**. 사용자가 다른 작업/외출/수면 등으로 세션을 떠나도 진행되려면 OS 절전이 비활성이고 Claude Code 세션이 열린 상태여야 함.
- Phase 3 (`CronCreate` 정기 스케줄 + retrospective agent vote 일치율 학습)는 Phase 2 brainstorm spec의 Out of Scope. 진입 전까지 진짜 "set and forget" 자율 불가.

**How to apply:**
- 사용자가 "지금 /auto-build 돌릴 수 있나?" 물으면 **현재 4가지 운영 경로 중 (a) 세션 유지가 가장 단순/검증된 유일 경로**임을 명시 (시간대 가정 없이):
  - (a) 노트북 절전 X + Claude Code 세션 열어둔 채로 사용자 다른 일 — **검증됨** (Phase 1 dogfooding 1회), Phase 2 머지 후 첫 실 task dogfooding 보류 (calibration 미수집)
  - (b) `/loop` dynamic 결합 — ScheduleWakeup self-pace, **미검증**
  - (c) `/schedule` cron — Phase 3 `CronCreate` 통합 필요, **미구현**
  - (d) tmux/nohup — OS 의존, 별도 setup
- Phase 2 머지 후 첫 실 task dogfooding은 **maker 본인 행위**로 설계 (대리 실행 시 실 사이클 시나리오 검증 가치 상실 + 토큰 비용 발생). dogfooding 1회로 수집할 calibration 입력:
  - token cap 200k 적정성 (vote 1회 ~5k × 30 iter = 150k 가정 정확도)
  - max_iterations 30 cap 적정성 (본격 SaaS task 분할 횟수 분포)
  - vote 결정 confidence 분포 (0.5 임계값 적정성)
  - persona pool 매핑 일치율 (70% 미달 시 Phase 2.1 mapping 재조정)
- 위 4 입력 수집 후 Phase 3 진입 결정. Phase 3 brainstorm 출발점: `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md` 의 Phase 3 섹션 (파일명은 brainstorm 당시 의도가 overnight였던 역사 기록)
