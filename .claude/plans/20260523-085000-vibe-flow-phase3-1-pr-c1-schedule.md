---
plan_id: 20260523-085000-vibe-flow-phase3-1-pr-c1-schedule
status: completed
created: 2026-05-22T23:50:00Z
hard_gate: brief
source: brainstorm:.claude/memory/brainstorms/20260523-084409-vibe-flow-phase3-1-pr-c-schedule.md
---

# Plan: vibe-flow Phase 3.1 PR-C1 — schedule 통합

## Goal

Claude Code `schedule` 스킬로 `run-queue.sh`를 자동 trigger하는 cron 통합층 추가. session-less 자율 사이클 활성. memory `project_auto_build_runtime_limit` 명시 "Phase 3 cron 전까지 session alive 필수" 해소.

## Approach

대안 B(brainstorm) — 3 sub-PR 분할 중 **PR-C1**. schedule-register.sh helper 신규(테스트 가능 + dry-run 가능). MAX_FIRINGS_PER_DAY=2 default + firings.jsonl 영속화(append-only, 단일 writer 가정). 신규 env `AUTO_BUILD_QUEUE_CRON_FIRING`이 set일 때만 cron 컨텍스트 분기 — backward compat (Test 10 회귀 0).

## Out of Scope

- auto-recovery (running 잔존 entry 자동 회수) — PR-C2 (cycle 9)
- depends_on 활성 (선행 PR=merged 검증) — PR-C3 (cycle 10)
- dashboard `/morning` 페이지 — 별 cycle PR-D
- DRYRUN=0 실 trigger 동작 — schedule-register.sh DRYRUN 검증만 (실 등록은 사용자 manual)

## 영향 파일

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `core/skills/auto-build/scripts/run-queue.sh` | 수정 | MAX_FIRINGS_PER_DAY env + firings.jsonl 카운트/append + CRON_FIRING 분기 |
| `core/skills/auto-build/scripts/schedule-register.sh` | 신규 | cron expr 검증 + `claude /schedule` 호출 helper (DRYRUN 옵션) |
| `scripts/tests/schedule-smoke.sh` | 신규 | schedule-register + firings cap smoke (4 케이스) |
| `core/skills/auto-build/SKILL.md` | 수정 | "Schedule 등록 (PR-C1)" 섹션 + env 표에 2 행 추가 |
| `core/skills/auto-build/orchestrator.md` | 수정 | cron-triggered cycle 시 destructive op cap 강화 1단락 |

## 단계 (TDD: RED → GREEN)

### T1: schedule-smoke.sh 골격 + Test S1 cron expr validation (RED)
- **상태**: pending
- **파일**: `scripts/tests/schedule-smoke.sh` (신규)
- **변경**: queue-tests.sh 패턴 복제. Test S1: invalid cron → exit 1, valid + DRYRUN=1 → exit 0 + "would register: ..." stdout
- **DoD**: 실행 시 S1.1/S1.2 모두 FAIL (register.sh 부재) — RED 신호
- **의존**: 없음

### T2: schedule-register.sh helper 구현 (GREEN T1)
- **상태**: pending
- **파일**: `core/skills/auto-build/scripts/schedule-register.sh` (신규)
- **변경**: cron 5필드 regex validation + DRYRUN=1 echo 모드 + claude CLI 존재 검사 (DRYRUN=0)
- **DoD**: schedule-smoke.sh S1.1/S1.2 PASS
- **의존**: T1

### T3: Test S2 firings cap (RED)
- **상태**: pending
- **파일**: `scripts/tests/schedule-smoke.sh` (수정)
- **변경**: MAX_FIRINGS_PER_DAY=2 + DRYRUN=1로 2회 firing → 3번째 "max firings reached" stderr + entry queued 잔존
- **DoD**: S2.1/S2.2 FAIL (run-queue.sh 미수정) — RED 신호
- **의존**: T2

### T4: run-queue.sh MAX_FIRINGS 카운트/cap 구현 (GREEN T3)
- **상태**: pending
- **파일**: `core/skills/auto-build/scripts/run-queue.sh` (수정)
- **변경**: FIRINGS_STORE env + MAX_FIRINGS_PER_DAY parse + TODAY_COUNT grep + cap exit + firing 시작 시 jq -nc 1 라인 append
- **DoD**: S2.1/S2.2 PASS + queue-tests.sh 10 회귀 0 + bash -n OK
- **의존**: T3

### T5: Test S3 + run-queue CRON_FIRING 분기
- **상태**: pending
- **파일**: `scripts/tests/schedule-smoke.sh` (수정) + `core/skills/auto-build/scripts/run-queue.sh` (수정)
- **변경**: CRON_FIRING=1 + DRYRUN=0 → "cron-triggered firing 감지" stderr + exit 1 + entry running 보존 + firings 1건 append
- **DoD**: S3 PASS + Test 10 회귀 0
- **의존**: T4

### T6: SKILL.md schedule 섹션 + env 표
- **상태**: pending
- **파일**: `core/skills/auto-build/SKILL.md` (수정)
- **변경**: "Queue 관리" 후 "Schedule 등록 (PR-C1)" H3 추가 + env 표 2행 + 검증 라인 갱신 + 관련 파일 3행
- **DoD**: grep "schedule-register|MAX_FIRINGS|CRON_FIRING" 5+ hit
- **의존**: T4

### T7: orchestrator.md cron destructive cap 단락
- **상태**: pending
- **파일**: `core/skills/auto-build/orchestrator.md` (수정)
- **변경**: 안전 hook 계약 직후 1단락 — CRON_FIRING=1 시 vote confidence < 0.7 abort 정책 추가
- **DoD**: grep "AUTO_BUILD_QUEUE_CRON_FIRING" ≥ 1 hit
- **의존**: T4

### T8: Test S4 + 회귀 종합
- **상태**: pending
- **파일**: `scripts/tests/schedule-smoke.sh` (수정)
- **변경**: S4 — `claude` CLI 미설치 시뮬레이션 (PATH=/usr/bin) → exit 2 + "claude CLI not found"
- **DoD**: schedule-smoke 4 케이스 PASS + queue-tests 10 회귀 0 + bash -n 3 파일 OK
- **의존**: T2, T4

### T9: 사용자 manual dry-run (DoD-C1.1)
- **상태**: pending
- **파일**: 없음 (사용자 검증)
- **변경**: `SCHEDULE_REGISTER_DRYRUN=1 bash core/skills/auto-build/scripts/schedule-register.sh "*/30 * * * *"` → stdout "would register: ..." 확인
- **DoD**: 머지 조건. 실 등록(R4 dogfooding)은 머지 후 cycle 8 회수
- **의존**: T8

## 리스크

- **R4 (schedule 스킬 미지원)**: T9 단계1 dry-run은 schedule 의존 0 → 머지 영향 없음. 실 등록 실패 시 macOS launchd(A1.1) 재평가
- **R6 (cron 부재 abort 누적)**: Phase 2 retrospective 5건 연속 abort 알림 활용. 신규 hook X
- **firings.jsonl race**: run-queue.sh 단일 writer 가정. 별 lock 도입 X (cron 동시 2 firing은 jsonl 양 라인 보존됨)
- **backward compat 회귀**: Test 10 (DRYRUN=0 entry 보존) 핵심 — CRON_FIRING 미설정 → 기존 exit 1 분기 우선

## 진행 추적

| 시각 | 단계 | 상태 변경 | 비고 |
|------|------|----------|------|
| 2026-05-22T23:50:00Z | (plan) | created | brainstorm 20260523-084409 기반 |
