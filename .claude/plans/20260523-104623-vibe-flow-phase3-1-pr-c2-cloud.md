---
plan_id: 20260523-104623-vibe-flow-phase3-1-pr-c2-cloud
status: completed
created: 2026-05-23T01:46:23Z
hard_gate: brief
source: sub-plan-of:20260523-093000-vibe-flow-phase3-1-cloud-native-master
---

# Sub-plan: Phase 3.1 PR-C2-cloud — `run-cloud.sh` 신규

## Goal

cloud remote agent가 호출하는 진입점 `run-cloud.sh` 신규. queue 첫 task pop → `/auto-build` 사이클 dispatch → PR 생성 → queue status_update done/aborted. 1 firing = 1 task = 1 PR.

## Approach

PR-C1.1의 prompt 템플릿 placeholder를 실제 호출 시퀀스로 채우며, `run-cloud.sh`가 단일 cycle 진입점. DRYRUN=1 모드로 모든 smoke 안전 격리.

## Out of Scope

- queue.jsonl gitignore 해제 (PR-C3)
- vote/safety hook cloud R8 dogfooding (PR-C3)
- 결과 통보 채널 (PR-C4)

## 영향 파일 (~7)

| 파일 | 변경 유형 |
|------|----------|
| `core/skills/auto-build/scripts/run-cloud.sh` | 신규 |
| `scripts/tests/run-cloud-smoke.sh` | 신규 |
| `core/skills/auto-build/data/cloud-prompt-template.md` | 수정 (실 호출 시퀀스 채움) |
| `core/skills/auto-build/orchestrator.md` | 수정 ("Cloud 분기 P0~P5" 섹션) |
| `core/skills/auto-build/SKILL.md` | 수정 ("Cloud 실행 (PR-C2)" 섹션) |
| `core/skills/auto-build/scripts/run-queue.sh` | 미세 (firings.jsonl deprecate 주석) |

## DoD

- `AUTO_BUILD_QUEUE_DRYRUN=1 bash run-cloud.sh` → queue 빈 시 exit 0, 1 task DRYRUN 시 mock PR URL + status_update done
- run-cloud-smoke.sh 3+ 케이스 PASS (C1 empty / C2 1 task DRYRUN / C3 gh fallback)
- queue-tests / schedule-smoke 회귀 0

## 단계 T1~T11

T1 run-cloud-smoke C1 (empty queue, RED) →
T2 run-cloud.sh skeleton (GREEN T1) →
T3 C2 DRYRUN 1 task (RED) →
T4 run-cloud.sh DRYRUN path (GREEN T3) →
T5 C3 gh fallback (RED) →
T6 run-cloud.sh gh fallback (GREEN T5) →
T7 cloud-prompt-template 본문 갱신 →
T8 orchestrator.md Cloud 분기 섹션 →
T9 SKILL.md Cloud 실행 섹션 →
T10 run-queue.sh firings deprecate 주석 →
T11 종합 회귀 + manual demo
