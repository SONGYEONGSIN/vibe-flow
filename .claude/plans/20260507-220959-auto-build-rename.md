---
plan_id: 20260507-220959-auto-build-rename
status: in_progress
created: 2026-05-07T13:09:59Z
hard_gate: full
worktree: 비적용 (mechanical rename, 충돌 위험 낮음)
source: user-direct
---

# Plan: sleep-build → auto-build 전면 rename

## Goal

`/sleep-build` 스킬 및 모든 부속 자산(hook, env, event-type, runs jsonl, docs, system memory)을 `auto-build`로 rename. Phase 2 도입(Ralph loop + persona vote)으로 "수면 중 자동 빌드"라는 초기 의미가 본질 변경된 후, 이름을 의미와 정합화. **코드 동작은 100% 동일, 식별자만 변경**.

## Approach

mechanical grep-replace + 디렉토리 mv + 단계별 검증. **producer(vibe-flow) → consumer(dashboard)** 순서로 짝 PR 분리. 시스템 메모리는 vibe-flow PR과 같은 시점 처리(별 PR 아님, 사용자 로컬).

- Step A (vibe-flow PR): 디렉토리/파일 rename → 내용 grep replace → settings/hook 갱신 → docs rename → CHANGELOG → 검증
- Step B (dashboard PR, vibe-flow 머지 후): event-type / test / dialogue / docs / CHANGELOG 갱신 → 테스트 통과
- Step C: 시스템 메모리 (vibe-flow PR과 같이)

각 단계 DoD = `rg 'sleep[-_]build|SLEEP_BUILD'` 잔여 0 + `bash -n` + `jq` 파싱 + (해당 시) evals 13 케이스 회귀 0.

## Out of Scope

- **한국어 산문**의 "sleep-build" 표기 변경 — 코드 식별자와 분리 (별 PR)
- 코드 동작/스킬 로직 변경 — Ralph loop, persona vote 알고리즘 그대로
- 과거 `sleep-build-runs.jsonl` 마이그레이션 — 새 이름으로 신규 누적, 과거 데이터 ignore
- dashboard 과거 `sleep_build_*` 이벤트 처리 — event-counter가 unknown 무시하므로 안전

## 결정 (선결)

**D1 = A** (mechanical 일관성): dialogue 컨텍스트 키 `sleep_start/done/abort` → `auto_start/done/abort`
**D2 = 분리** (코드 식별자만): 한국어 산문 표기 변경은 별 PR

## 영향 파일

### vibe-flow (11)

| 파일 | 변경 유형 | 설명 |
|------|---------|------|
| `core/skills/sleep-build/` (dir) | rename | → `core/skills/auto-build/` |
| `core/skills/auto-build/SKILL.md` | 내용 | front-matter `name`, 본문 |
| `core/skills/auto-build/orchestrator.md` | 내용 | grep replace |
| `core/skills/auto-build/scripts/run-log.sh` | 내용 | jsonl 파일명 + env var |
| `core/skills/auto-build/scripts/persona-vote.sh` | 내용 | env var, 로그 prefix |
| `core/skills/auto-build/evals/evals.json` | 내용 | 13 케이스 입력/기대 |
| `core/skills/auto-build/data/persona-mapping.json` | 이동만 | 내용 변경 없음 |
| `core/hooks/sleep-build-safety.sh` | rename + 내용 | → `auto-build-safety.sh` |
| `settings/settings.template.json` | 내용 | hook 경로, env var |
| `setup.sh` | 검증/조건부 | sleep-build 명시 참조 시 치환 |
| `CHANGELOG.md` | 내용 | [Unreleased] 항목 |
| `docs/superpowers/plans/2026-05-04-sleep-build-phase1.md` | rename + 내용 | → `2026-05-04-auto-build-phase1.md` |
| `docs/superpowers/specs/2026-05-04-sleep-build-overnight-autonomous.md` | rename + 내용 | → `2026-05-04-auto-build-overnight-autonomous.md` |

### dashboard (6)

| 파일 | 변경 유형 | 설명 |
|------|---------|------|
| `src/app/characters/data/event-map.ts` | 내용 | `sleep_build_*` → `auto_build_*` |
| `src/app/characters/data/agent-event-map.ts` | 내용 | Stage 카운트 룰 키 |
| `src/app/characters/lib/__tests__/event-map.test.ts` | 내용 | fixture |
| `src/app/characters/lib/__tests__/event-counter.test.ts` | 내용 | fixture |
| `src/app/characters/data/dialogue-pool.json` | 내용 | `sleep_*` → `auto_*` |
| `CHANGELOG.md` | 내용 | [Unreleased] |
| `docs/superpowers/specs/2026-05-04-sleep-build-events-mapping.md` | rename + 내용 | → `2026-05-04-auto-build-events-mapping.md` |

### 시스템 메모리 (1+1)

| 파일 | 변경 유형 |
|------|---------|
| `~/.claude/projects/.../memory/project_sleep_build_runtime_limit.md` | rename + 내용 |
| `~/.claude/projects/.../memory/MEMORY.md` | 인덱스 라인 갱신 |

## 단계

### T1: 사전 측정 + 백업
- **상태**: pending
- **명령**: `rg -l 'sleep[-_]build|SLEEP_BUILD' > /tmp/vibe-files.txt` (vibe-flow), 동일 dashboard
- **DoD**: 영향 파일 수 plan과 일치 (vibe-flow 11, dashboard 6)
- **의존**: 없음

### T2: vibe-flow 디렉토리 + hook git mv
- **상태**: pending
- **파일**: `core/skills/sleep-build/` → `core/skills/auto-build/`, `core/hooks/sleep-build-safety.sh` → `core/hooks/auto-build-safety.sh`
- **명령**: `git mv` (히스토리 보존)
- **DoD**: `git status` R(renamed) 표시, 디렉토리 내부 파일 모두 따라 이동
- **의존**: T1

### T3: vibe-flow 코드/스크립트 grep replace
- **파일**: `core/skills/auto-build/**/*.{md,sh,json}`, `core/hooks/auto-build-safety.sh`
- **변환**: `sleep-build`→`auto-build` / `SLEEP_BUILD_`→`AUTO_BUILD_` / `sleep_build_`→`auto_build_` / `sleep-build-runs.jsonl`→`auto-build-runs.jsonl`
- **DoD**: `rg 'sleep[-_]build|SLEEP_BUILD' core/skills/auto-build core/hooks/auto-build-safety.sh` → 0 hit / `bash -n` 통과 / `jq .` 통과
- **의존**: T2

### T4: settings.template.json 갱신
- **파일**: `settings/settings.template.json`
- **변경**: hook 경로 `core/hooks/auto-build-safety.sh`, env var `AUTO_BUILD_*`
- **DoD**: `jq .` 통과 + `rg 'sleep[-_]build' settings/` 0 hit
- **의존**: T2

### T5: setup.sh 검증
- **파일**: `setup.sh`
- **검증**: `rg 'sleep[-_]build' setup.sh` 명시 참조 있으면 치환
- **DoD**: hit 0
- **의존**: T2

### T6: vibe-flow docs rename + 내용
- **파일**: `docs/superpowers/plans/.../sleep-build-phase1.md` + `docs/superpowers/specs/.../sleep-build-overnight-autonomous.md`
- **명령**: `git mv` + 내용 grep replace
- **DoD**: `rg 'sleep[-_]build|SLEEP_BUILD' docs/` 코드 식별자 hit 0 (산문 제외)
- **의존**: T1

### T7: 전역 잔여 검증 + CHANGELOG
- **파일**: `CHANGELOG.md`
- **명령**: `rg 'sleep[-_]build|SLEEP_BUILD' --type-add 'cfg:*.{json,sh,md,ts,yml}' -tcfg` (산문/CHANGELOG 제외)
- **CHANGELOG**: `[Unreleased]` 추가 — skill rename / hook / env / event-type 명시
- **DoD**: hit 0 (산문 제외)
- **의존**: T3, T4, T5, T6

### T8: evals 회귀 검증
- **파일**: `core/skills/auto-build/evals/evals.json`
- **명령**: `jq '.cases | length'` = 13, 각 케이스 input/expected에서 `sleep_build_*` 0 hit + `auto_build_*` 등장
- **DoD**: 13 케이스 회귀 0
- **의존**: T3

### T9: vibe-flow PR 생성
- **branch**: `refactor/auto-build-rename`
- **명령**: commit + push + `gh pr create`
- **DoD**: PR open, CI green
- **의존**: T1~T8

### T10: dashboard event-map + tests grep replace (vibe-flow 머지 후)
- **파일**: `event-map.ts`, `agent-event-map.ts`, `event-map.test.ts`, `event-counter.test.ts`
- **변환**: `sleep_build_` → `auto_build_`
- **DoD**: `rg 'sleep_build_'` 0 hit / `npx vitest run` 통과 / `next build` 통과
- **의존**: T9 머지 후

### T11: dashboard dialogue-pool 컨텍스트 키
- **파일**: `dialogue-pool.json`
- **변환**: `sleep_start/done/abort` → `auto_start/done/abort` (D1 = A)
- **DoD**: `jq .` 통과 / `rg 'sleep_(start|done|abort)'` 0 hit / dialogue 매칭 단위 테스트 통과
- **의존**: T9 머지 후

### T12: dashboard docs rename + CHANGELOG
- **파일**: `docs/superpowers/specs/.../sleep-build-events-mapping.md` rename + 내용 + CHANGELOG
- **DoD**: `rg 'sleep[-_]build|sleep_build_|sleep_(start|done|abort)' docs/` 0 hit
- **의존**: T9 머지 후

### T13: dashboard PR 생성
- **branch**: `refactor/auto-build-event-rename`
- **PR**: vibe-flow PR 짝 명시
- **DoD**: PR open, CI green
- **의존**: T10, T11, T12

### T14: 시스템 메모리 rename
- **파일**: `~/.claude/projects/.../memory/project_sleep_build_runtime_limit.md` → `project_auto_build_runtime_limit.md` + `MEMORY.md` 인덱스
- **DoD**: `rg 'sleep[-_]build' ~/.claude/projects/.../memory/` 0 hit
- **의존**: T9 (vibe-flow와 같은 시점, PR 외)

### T15: 최종 통합 검증
- **명령**: vibe-flow / dashboard / 시스템 메모리 grep `sleep[-_]build|SLEEP_BUILD|sleep_build_|sleep_(start|done|abort)` → 코드 식별자 hit 0
- **DoD**: 세 grep 모두 0 (한국어 산문 무시)
- **의존**: T13, T14

## 리스크

- **R1 settings.template.json 누락**: T4 hook 경로 + env var 둘 다 검증. 사용자 로컬 `~/.claude/settings.json`은 별개 — PR 본문에 setup.sh 재실행 안내.
- **R2 과거 jsonl 데이터 손실**: 새 이름 신규 누적, 과거 무시 (Out of Scope).
- **R3 짝 PR 순서 위반**: dashboard 먼저 머지 시 한시적 카운트 0. **vibe-flow → dashboard 강제**, PR 본문 dependency 명시.
- **R4 한국어 산문 잔여**: 의도된 잔여, T15 false positive 처리 + PR 본문 명시.
- **R5 evals 13 케이스 hidden 명칭**: T8 jq 검증 필수.
- **R6 dialogue 매칭 로직**: T11 단위 테스트 통과 강제.
- **R7 PR #37 충돌**: settings.template.json 동시 수정 — base를 최신 main으로.

## 진행 추적

| 시각 | 단계 | 상태 변경 | 비고 |
|------|------|----------|------|
| 2026-05-07T13:09:59Z | - | plan 생성 | 사용자 합의 (전체 등급, T1~T15) |
