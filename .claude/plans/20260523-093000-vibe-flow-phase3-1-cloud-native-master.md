---
plan_id: 20260523-093000-vibe-flow-phase3-1-cloud-native-master
status: in_progress
created: 2026-05-23T00:30:00Z
hard_gate: full
source: brainstorm:.claude/memory/brainstorms/20260523-092812-vibe-flow-phase3-1-cloud-native-redesign.md
sub_plans:
  - PR-C1.1 (detailed T1~T9)
  - PR-C2-cloud (outline, sub-plan on entry)
  - PR-C3-safety (outline, sub-plan on entry)
  - PR-C4-notify (outline, sub-plan on entry)
---

# Master Plan: vibe-flow Phase 3.1 Path A — Cloud-Native Auto-Build Redesign

## Master Goal

PR #67(PR-C1, merged) R4 발견 — schedule = Anthropic cloud `RemoteTrigger` remote agent. Local cron 가정 무효. Phase 3.1 자율 cycle(brainstorm→plan→TDD→verify→commit→PR)을 cloud remote agent 위에서 git checkout으로 실행되도록 **A1.1 + A2.1 + A3.1(fallback A3.3) + A4.1+A4.3 + A5.1 통합** 재설계.

## Master Approach

4 PR로 분할 — 각 PR = 본 plan의 phase. PR-C1.1만 T1~T9 상세 (HARD-GATE brief), PR-C2/C3/C4는 outline (각 PR 진입 시 sub-plan 작성).

**진행 순서**: PR-C1.1 → PR-C2-cloud → PR-C3-safety (R8 dogfooding) → PR-C4-notify.

## Master Out of Scope

- macOS launchd (Path B 기각)
- /loop in-session 자율 (Path C 기각)
- dashboard /morning 페이지 (별 cycle PR-D)
- Phase 3.0 queue.sh CRUD 구조 변경 (80% 재사용)
- PR-C1 revert (cron expr validation retain)
- Discord/Slack webhook은 PR-C4 옵션

## Master 영향 파일 추정

- 신규 ~10: run-cloud.sh, queue-commit.sh, notify-pr.sh, cloud-prompt-template.md, run-cloud-smoke.sh, queue-commit test 등
- 수정 ~15: schedule-register.sh rewrite, orchestrator.md, SKILL.md, queue.sh, run-queue.sh, .gitignore, auto-build-safety.sh, persona-mapping.json, 등
- **합계 ~25** → full grade

## Phase 진행 추적

| Phase | PR | 상태 | 머지 시점 | 다음 진입 조건 |
|-------|-----|------|----------|---------------|
| 1 | PR-C1.1 schedule-register 재설계 | in_progress | TBD | T9 DoD PASS |
| 2 | PR-C2-cloud `/auto-build run-cloud` | blocked | TBD | Phase 1 머지 |
| 3 | PR-C3-safety vote/safety + queue git | blocked | TBD | Phase 2 머지 + R8 dogfooding 준비 |
| 4 | PR-C4-notify | blocked | TBD | Phase 3 머지 |

---

## Phase 1 — PR-C1.1: schedule-register.sh RemoteTrigger 재설계

### 목표

기존 `schedule-register.sh` (claude CLI 호출 wrapper)를 **RemoteTrigger API 호출 wrapper**로 rewrite. cron expr 1h min validation + run_once_at 모드 + 표준 remote agent prompt 템플릿. PR-C1의 5필드 syntax validation retain하되 1h min interval check 추가.

### Out of Scope (Phase 1)

- run-cloud.sh 실 구현 (PR-C2)
- RemoteTrigger create 실 호출 (DRYRUN=0 + 사용자 manual)
- queue.jsonl git-committed 전환 (PR-C3)
- firings.jsonl 의미 축소 (PR-C2/C3)

### 영향 파일 (~6)

| 파일 | 변경 유형 |
|------|----------|
| `core/skills/auto-build/scripts/schedule-register.sh` | rewrite (claude CLI → RemoteTrigger payload JSON + 1h min + run_once_at) |
| `core/skills/auto-build/data/cloud-prompt-template.md` | 신규 (표준 prompt 템플릿, placeholder 포함) |
| `scripts/tests/schedule-smoke.sh` | 수정 (S5~S7 추가, 기존 S1~S4 유지) |
| `core/skills/auto-build/SKILL.md` | 수정 (Schedule 등록 섹션 재작성) |
| `core/skills/auto-build/orchestrator.md` | 수정 (cloud firing 진입 정책 1단락) |

### DoD (Phase 1 머지 조건)

- `SCHEDULE_REGISTER_DRYRUN=1 bash schedule-register.sh "0 */6 * * *"` → RemoteTrigger payload JSON stdout
- `bash schedule-register.sh "*/30 * * * *"` → exit 1 + stderr `interval too short — 1 hour minimum`
- `RUN_ONCE_AT=2026-05-24T03:00:00Z bash schedule-register.sh --once` → run_once payload
- `bash scripts/tests/schedule-smoke.sh` 8+ 케이스 PASS
- `bash scripts/tests/queue-tests.sh` 10 회귀 0
- prompt 템플릿 `/auto-build run-cloud` 1+ hit + `{{REPO_URL}}` 1+ hit + `git clone` 1+ hit

### 단계 (T1~T9, TDD: RED→GREEN)

#### T1: schedule-smoke S5 — 1h min validation (RED)
- **상태**: pending
- **파일**: `scripts/tests/schedule-smoke.sh` (수정)
- **변경**: S5.1 (`*/30 * * * *` reject), S5.2 (`0 */1 * * *` PASS), S5.3 (`*/5 * * * *` reject)
- **DoD**: S5 FAIL — 현 register.sh sub-hour 통과 (RED 신호)
- **의존**: 없음

#### T2: register.sh — validate_min_interval() (GREEN T1)
- **상태**: pending
- **파일**: `core/skills/auto-build/scripts/schedule-register.sh` (수정)
- **변경**: minute + hour 필드 조합으로 interval 1h 미만 검출 helper
- **DoD**: S5 PASS + S1~S4 회귀 0
- **의존**: T1

#### T3: cloud-prompt-template.md 신규
- **상태**: pending
- **파일**: `core/skills/auto-build/data/cloud-prompt-template.md` (신규)
- **변경**: `{{REPO_URL}}` / `{{BRANCH}}` placeholder + `git clone + /auto-build run-cloud` 시퀀스 + cloud session 정책 1단락
- **DoD**: 파일 존재 + grep `/auto-build run-cloud` + `{{REPO_URL}}` + `git clone` 각 1+ hit
- **의존**: 없음 (T1과 병행 가능)

#### T4: schedule-smoke S6 — prompt 템플릿 load + 치환 (RED)
- **상태**: pending
- **파일**: `scripts/tests/schedule-smoke.sh` (수정)
- **변경**: S6.1 (`body.prompt`에 `/auto-build run-cloud` 토큰), S6.2 (REPO_URL env 반영)
- **DoD**: S6 FAIL — register.sh prompt 필드 없음 (RED)
- **의존**: T3

#### T5: register.sh — RemoteTrigger payload JSON 생성 (GREEN T4)
- **상태**: pending
- **파일**: `core/skills/auto-build/scripts/schedule-register.sh` (rewrite)
- **변경**: cloud-prompt-template.md 읽기 + placeholder 치환 + `jq -nc`로 payload JSON 빌드. DRYRUN=1 → stdout, DRYRUN=0 → "Manual: paste this JSON" 안내. env: REPO_URL (`git remote get-url origin` fallback), BRANCH (`main` fallback)
- **DoD**: S6.1/S6.2 PASS + `jq -e '.body.prompt' < payload` 통과
- **의존**: T2, T3, T4

#### T6: schedule-smoke S7 — run_once_at 모드 (RED+GREEN)
- **상태**: pending
- **파일**: `schedule-smoke.sh` + `schedule-register.sh` (수정)
- **변경**: S7.1 (`--once` + `RUN_ONCE_AT` → `body.schedule.run_once_at` 필드, cron 부재), S7.2 (`--once` 없이 RUN_ONCE_AT 만 reject). register.sh: `--once` flag parse + RFC 3339 validation
- **DoD**: S7 PASS + S1~S6 회귀 0
- **의존**: T5

#### T7: orchestrator.md cloud firing 진입 정책
- **상태**: pending
- **파일**: `core/skills/auto-build/orchestrator.md` (수정)
- **변경**: P0 "cron-triggered firing 보수 정책" 직후 "cloud firing 진입 (PR-C1.1)" 단락 — cloud session은 `AUTO_BUILD_QUEUE_CRON_FIRING=1` + cloud context 가정. `/auto-build run-cloud` 진입점은 PR-C2 placeholder
- **DoD**: grep `run-cloud` + `cloud firing` 각 1+ hit
- **의존**: T5

#### T8: SKILL.md "Schedule 등록" 섹션 rewrite + env 표
- **상태**: pending
- **파일**: `core/skills/auto-build/SKILL.md` (수정)
- **변경**: 헤더 → "Schedule 등록 (PR-C1.1 cloud-native)". claude CLI 예시 제거 → RemoteTrigger DRYRUN payload 예시. 1h min 정책. run_once_at 예시. env 표 `REPO_URL`, `BRANCH`, `RUN_ONCE_AT` 3행 신규. 관련 파일 `cloud-prompt-template.md`
- **DoD**: grep `RemoteTrigger|cloud-prompt-template|run_once_at` 8+ hit + grep `claude /schedule` 0 hit
- **의존**: T5, T6

#### T9: 회귀 종합 + 사용자 manual DRYRUN
- **상태**: pending
- **파일**: 없음 (검증)
- **변경**:
  - `bash scripts/tests/schedule-smoke.sh` 8+ 케이스 PASS
  - `bash scripts/tests/queue-tests.sh` 10 회귀 0
  - `bash -n` 3 파일 OK
  - 사용자 manual: `SCHEDULE_REGISTER_DRYRUN=1 bash schedule-register.sh "0 */6 * * *"` → JSON stdout + jq로 prompt 필드 검토
- **DoD**: 모든 명령 PASS + 사용자 OK
- **의존**: T2, T5, T6, T7, T8

## 리스크 (Phase 1 + Master 공통)

- **R4**: cloud reality 수용 — Anthropic cloud는 self-contained 정의 확장
- **R8**: vote/safety hook cloud 미동작 → A3.3 fallback. PR-C3에서 dogfooding
- **R9**: queue.jsonl git conflict → PR-C3 single-writer + git pull --rebase
- **R10**: token cost 폭증 → budget skill + cron freq cap + PR-C4 50k+ threshold 알림
- **PR-C1 잔재**: firings.jsonl local-only로 의미 축소 → PR-C2에서 deprecate 주석

## 진행 추적

| 시각 | 단계 | 상태 변경 | 비고 |
|------|------|----------|------|
| 2026-05-23T00:30:00Z | (master plan) | created | brainstorm 20260523-092812 기반 |
| 2026-05-23T00:30:00Z | Phase 1 | started | PR-C1.1 진입 |
