---
plan_id: 20260504-194208-vibe-flow-auto-build-phase1
status: completed
created: 2026-05-04T10:42:08Z
completed: 2026-05-04T11:00:00Z
hard_gate: brief
source: brainstorm-file:.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md
---

# Plan: vibe-flow v2 — `/auto-build` Phase 1 MVP

## Goal

vibe-flow에 `/auto-build "<task>"` 슬래시 스킬을 신규 도입하여 **단일 task one-shot 자율 사이클**(brainstorm → plan → 구현(TDD) → /verify → /commit → /finish)을 maker가 자는 동안 안전하게 완주하도록 한다. Phase 1의 검증 가능한 성공 기준은 단 하나 — "maker가 task 1개를 큐잉하고 자고 일어나서 working PR 1개(또는 명시적 abort 로그 + 부분 진행 보존 branch)를 morning review로 받는 경험"이 한 사이클 dogfooding으로 재현된다.

## Approach

brainstorm spec의 추천(대안 A) 그대로 — 외부 도구(GSD/gstack) 채택 대신 vibe-flow 본체에 자체 오케스트레이터 스킬을 추가한다. 기존 `/brainstorm`, `/plan`, `/verify`, `/commit`, `/finish` 스킬과 `/loop` dynamic + `ScheduleWakeup`, character agents(developer/qa/planner), `/budget --tokens`를 **재사용 100%** 하고, 신규 코드는 진입점(SKILL.md) + 오케스트레이션 본체(orchestrator.md, 자연어 시퀀스) + 안전 hook(auto-build-safety.sh) + 런타임 로그(jsonl 한 파일) + setup.sh 통합으로 한정한다.

오케스트레이터는 **기존 스킬을 자연어로 invoke하는 단계 스크립트** 형태로 구현한다 (별도 sh runner가 아니라 `core/skills/auto-build/orchestrator.md`의 단계별 지시를 모델이 순차 실행). 이유 — 기존 `/brainstorm`, `/plan` 등이 모두 마크다운 prompt 기반 슬래시 스킬이라 sh가 그것을 invoke할 수 없고, 자연어 시퀀스가 vibe-flow의 일관 패턴이다. 안전 가드만 deterministic 차단이 필요하므로 `core/hooks/auto-build-safety.sh` 단일 PreToolUse hook으로 격리한다(기존 `security-lint.sh`는 PostToolUse 패턴 검증 전용이라 책임이 다름 — 신규 hook).

## Out of Scope

- Phase 2 — `/auto-build queue add/list` 다중 task 큐 + `CronCreate` 정기 야간 실행
- Phase 3 — vibe-flow-dashboard `/morning` 페이지 + 12 캐릭터 야간 stage 진화 시각화
- Phase 4 — retrospective agent 자가 진화 루프 + skill-creator 자동 호출 후보 식별
- 본 plan 내 모든 task는 단일 사이클 one-shot에 집중. queue / cron / dashboard / retrospective 통합은 다음 plan에서 다룬다.
- 실제 야간 자율 빌드 end-to-end 검증은 maker 수동 dogfooding (1회). Phase 1의 자동 검증은 `core/skills/auto-build/orchestrator.md` 시퀀스 dry-run + safety hook unit-level smoke + vitest 시뮬레이션 1 케이스로 한정.

## 영향 파일

| 파일 | 변경 유형 | 비고 |
|------|----------|------|
| `core/skills/auto-build/SKILL.md` | 신규 | 슬래시 스킬 진입점 — 사용법, 선행 조건, 안전 계약, orchestrator로 위임 |
| `core/skills/auto-build/orchestrator.md` | 신규 | 자율 사이클 단계 본체 — branch 격리, /brainstorm → /plan → 구현 → /verify → /commit → /finish 자연어 시퀀스 + 실패 분기 |
| `core/hooks/auto-build-safety.sh` | 신규 | PreToolUse — 자율 모드에서만 활성화. destructive op 차단(`rm -rf`, `git reset --hard`, `git push --force`, `--no-verify`), token cap, 파일 수 cap(HARD-GATE 20+) |
| `core/skills/auto-build/scripts/run-log.sh` | 신규 | `.claude/memory/auto-build-runs.jsonl` append helper (start/abort/done 이벤트, branch명, token 누적, exit reason) |
| `settings/settings.template.json` | 수정 | `core/hooks/auto-build-safety.sh` PreToolUse 등록 + `AUTO_BUILD_MODE` env flag 토글 |
| `setup.sh` | 수정 | `[3/N] Skills` 단계가 이미 디렉토리 재귀 복사하므로 별도 추가 X — 다만 신규 hook 권한 검증 로그만 추가 (한 줄) |
| `core/skills/auto-build/evals/smoke.md` | 신규 | meta-quality 호환 eval — 시퀀스 dry-run 1 케이스 + safety hook 차단 1 케이스 |
| `CHANGELOG.md` | 수정 | 1.6.0-rc 항목 — `/auto-build` Phase 1 MVP 추가 |

총 8 파일 변경 (신규 5 + 수정 3) — **HARD-GATE 간략 등급** (`rules/git.md` 6~19개 구간). worktree 격리는 권장 X (20개 미만), 단일 PR로 진행 가능.

## 단계

### T1: 디렉토리 + SKILL.md 골격 생성
- **상태**: done
- **파일**: `core/skills/auto-build/SKILL.md`
- **변경**: frontmatter(`name: auto-build`, `description: ...사용법 /auto-build "<task>"`, `effort: large`) + "사용 시점 / 안전 계약 / 선행 조건 / 절차 요약 / orchestrator.md로 위임 1줄" 헤더 작성. 본 파일은 진입점만 — 단계 본체는 T2에서.
- **DoD**: 파일 존재, frontmatter 3 필드 모두 채워짐, 본문에 "1. 안전 계약 → 2. branch 격리 → 3. orchestrator.md 시퀀스 진입 → 4. 종료 후 run-log append" 4-step 요약이 포함.
- **의존**: 없음

### T2: orchestrator.md — 자율 사이클 단계 시퀀스
- **상태**: done
- **파일**: `core/skills/auto-build/orchestrator.md`
- **변경**: 5개 phase 자연어 시퀀스 — (P1) `/brainstorm "<task>"` 호출 → spec 파일 경로 캡처, (P2) `/plan from-brainstorm <file>` → plan_id 캡처, (P3) plan T1..Tn 순차 구현 (각 단계마다 vitest 작성 → 실패 확인 → 구현 → 통과 확인 TDD 루프), (P4) `/verify` 통과까지 반복 (최대 3회), (P5) `/commit` → `/finish`. 각 phase 진입/종료 시 `run-log.sh` append 호출. 실패 분기 — 실패 시 abort + branch 보존 + jsonl `exit_reason` 기록.
- **DoD**: 5개 phase 모두 명시. 각 phase가 호출하는 기존 스킬명 정확히 인용. 실패 분기가 phase별로 명시. "사람이 읽고 따라할 수 있는" 수준의 결정 트리.
- **의존**: T1

### T3: safety hook — destructive op 차단 패턴 정의
- **상태**: done
- **파일**: `core/hooks/auto-build-safety.sh`
- **변경**: PreToolUse hook. `AUTO_BUILD_MODE=1` env일 때만 활성. Bash tool 입력에서 차단 패턴 검사 — `rm -rf`, `git reset --hard`, `git push --force`, `--no-verify`, `chmod 777`, `:(){ :|:& };:`. 차단 시 stderr에 사유 출력 + exit 2 (Claude Code PreToolUse 차단 규약). 비-자율 모드(env 없음)면 즉시 exit 0.
- **DoD**: shellcheck 통과, env 미설정 시 exit 0 즉시 검증, 차단 패턴 6개 각각 stdin echo로 차단 확인 (수동 1회면 충분).
- **의존**: 없음

### T4: safety hook — token & file count cap
- **상태**: done
- **파일**: `core/hooks/auto-build-safety.sh`
- **변경**: T3 위에 두 가드 추가 — (a) token cap: `.claude/memory/auto-build-runs.jsonl` 최신 run의 누적 token이 `AUTO_BUILD_TOKEN_CAP` (기본 130000) 초과면 차단. (b) file count cap: 현재 branch의 git diff 파일 수가 `AUTO_BUILD_FILE_CAP` (기본 19, HARD-GATE 20+ 진입 직전) 초과면 차단. 차단 시 `exit_reason` 명시 stderr.
- **DoD**: 두 가드 각각 임의 jsonl/git diff 시뮬레이션으로 차단 동작 확인. cap 미설정 시 기본값 적용.
- **의존**: T3

### T5: run-log helper
- **상태**: done
- **파일**: `core/skills/auto-build/scripts/run-log.sh`
- **변경**: 인자 — `start|abort|done <run_id> <key=value>...`. `.claude/memory/auto-build-runs.jsonl`에 `{ts, run_id, event, branch, tokens_in, tokens_out, files_changed, exit_reason}` JSON 라인 append. NFD/NFC 한글 경로는 user memory에 따라 NFC 정규화.
- **DoD**: 3 이벤트 타입 모두 append 성공, jq로 파싱 가능한 JSON, 동시 호출 시 줄 깨짐 없음 (`>>` atomic append).
- **의존**: 없음

### T6: settings 템플릿 — hook 등록 + env 토글
- **상태**: done
- **파일**: `settings/settings.template.json`
- **변경**: `hooks.PreToolUse` 배열에 `core/hooks/auto-build-safety.sh` 항목 추가 (Bash tool 매칭). `env.AUTO_BUILD_MODE`는 기본 미설정. 주석으로 "자율 모드 진입 시 auto-build 스킬이 set"이라 명시 (settings는 주석 X — 별도 README 라인).
- **DoD**: jq로 settings.template.json 파싱 성공, PreToolUse 배열에 신규 항목 1개 추가됨, `setup.sh` 처리 후 신규 프로젝트의 `.claude/settings.local.json`에서 절대 경로로 치환 확인.
- **의존**: T3

### T7: orchestrator 안전 계약 ↔ hook 결합 verify
- **상태**: done
- **파일**: `core/skills/auto-build/orchestrator.md`
- **변경**: 시퀀스 P0(전처리) 추가 — `AUTO_BUILD_MODE=1` export, branch 자동 생성 (`feat/sleep-<timestamp>-<slug>`), `run-log.sh start` 호출. 시퀀스 종료 직전 unset + `run-log.sh done|abort` 명시. orchestrator.md ↔ safety hook env 계약 1단락 명문화.
- **DoD**: orchestrator.md에 P0/P-end 명시, env 라이프사이클이 단일 사이클 안에서 완결, 외부 (수동 작업) 사이클에는 영향 0.
- **의존**: T2, T4

### T8: vitest 시뮬레이션 — 가짜 사이클 1 케이스
- **상태**: done
- **파일**: `core/skills/auto-build/evals/smoke.md`
- **변경**: meta-quality 호환 eval — (a) orchestrator.md를 마크다운으로 읽어 P0~P5가 모두 존재하는지 grep 검증, (b) safety hook에 `rm -rf /` 입력 시 exit 2 반환, (c) cap 미설정 시 destructive 패턴만 차단되고 정상 Bash는 통과. 자연어 케이스 3개로 충분.
- **DoD**: smoke.md가 `/eval` 스킬에서 read 가능한 구조, 3 케이스 모두 P/F 판정 기준이 명시적, 실제 자율 빌드 end-to-end는 의도적으로 out-of-scope 명시.
- **의존**: T2, T4

### T9: setup.sh 통합 — hook 권한 + 디렉토리 검증
- **상태**: done
- **파일**: `setup.sh`
- **변경**: `[2/N] Hooks` 단계는 이미 `chmod +x core/hooks/*.sh`라 신규 hook 자동 포함. 추가 작업 — `[3/N] Skills` 후 `core/skills/auto-build/scripts/run-log.sh`도 `chmod +x` 적용 (skill 하위 scripts/ 디렉토리는 현재 chmod 안 함). state 파일 core_files 갱신 자동 — 별도 작업 X.
- **DoD**: `bash setup.sh` 새 프로젝트에 한 번 돌려 `.claude/skills/auto-build/scripts/run-log.sh`가 +x 권한 보유, `.claude/hooks/auto-build-safety.sh` +x 권한 보유, `bash .claude/validate.sh` 통과.
- **의존**: T1, T3, T5

### T10: CHANGELOG + brainstorm 사후 기록
- **상태**: done
- **파일**: `CHANGELOG.md`, `.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md`
- **변경**: CHANGELOG에 `## [Unreleased] / feat(auto-build): /auto-build Phase 1 MVP — 단일 task 자율 사이클 + safety hook` 항목 추가. brainstorm spec 하단 "다음 단계" 아래에 "Phase 1 plan: `.claude/plans/20260504-194208-vibe-flow-auto-build-phase1.md` (T1~T10)" 한 줄 백링크.
- **DoD**: CHANGELOG에 1.6.0-rc 항목 1줄, brainstorm spec에 plan 백링크 1줄. 두 파일 모두 git diff에 포함.
- **의존**: T1~T9 모두 (마지막 단계)

## 리스크

- **R1: orchestrator.md 자연어 시퀀스가 모델별로 결정 트리를 다르게 해석** — 완화: 각 phase에 "이 단계 종료 조건"을 측정 가능 형태(예: "/verify exit 0")로 명시. 모호한 분기는 abort 우선 정책.
- **R2: safety hook이 정상 작업까지 차단 (false positive)** — 완화: `AUTO_BUILD_MODE` env 토글로 자율 모드만 적용. 비자율 작업에는 영향 0. T8 smoke 3 케이스로 회귀 방지.
- **R3: token cap 130k 가정이 실제 1 사이클 비용 대비 부족 또는 과다** — 완화: Phase 1은 maker dogfooding 1회로 calibration. cap은 env 노출돼 있어 1줄 수정. 부족 시 P3 TDD 루프 도중 abort + 부분 진행 branch 보존(설계상 수용 가능).
- **R4: branch 자동 생성과 worktree 격리가 충돌** — 완화: Phase 1은 worktree 미사용 (단일 branch만). 20+ 파일 사이클은 file count cap이 차단하므로 현실적 충돌 없음. Phase 2에서 worktree 도입 시 재설계.
- **R5: stacked PR squash merge 사고 (user memory)** — 완화: Phase 1은 단일 PR만 생성. stacked 분기는 `/auto-build` 시퀀스에 도입 X. `/finish`가 호출하는 `gh pr create`도 단발성.
- **R6: run-log jsonl이 NFD/NFC 혼재로 파싱 실패** — 완화: T5에서 NFC 정규화 강제 (user memory의 macOS 한글 경로 규칙 준수).
- **R7: orchestrator가 `/brainstorm` 단계에서 4문항 자기검증을 사용자 응답 없이 통과 시도** — 완화: orchestrator P1에서 입력 task 자체를 4문항 답변 형식으로 미리 prepare하여 `/brainstorm`에 전달. brainstorm 스킬이 추가 질문 던지면 abort.

## 진행 추적

| 시각 | 단계 | 상태 변경 | 비고 |
|------|------|----------|------|
| 2026-05-04T10:42:08Z | - | plan 생성 | 사용자 합의 (간략 등급, T1~T10) |
| 2026-05-04T10:43Z | T1 | done | SKILL.md 골격 — frontmatter 3 필드 + 4-step 절차 |
| 2026-05-04T10:45Z | T2 | done | orchestrator.md P1~P5 + 실패 분기 (P0/P-end는 T7) |
| 2026-05-04T10:47Z | T3 | done | safety hook destructive 8 패턴 차단 (rm -rf, reset --hard, push --force, --no-verify, chmod 777, fork bomb, dd, mkfs) — 수동 stdin echo 검증 통과 |
| 2026-05-04T10:48Z | T4 | done | token cap (jsonl 합산) + file cap (porcelain) — 5 시나리오 검증 통과 |
| 2026-05-04T10:49Z | T5 | done | run-log helper start/abort/done — 3 이벤트 jq 파싱 통과 |
| 2026-05-04T10:50Z | T6 | done | settings.template.json PreToolUse[0] 3-hook (jq valid) |
| 2026-05-04T10:52Z | T7 | done | P0 전처리 + P-end 후처리 + env 라이프사이클 명문화 |
| 2026-05-04T10:55Z | T8 | done | evals.json 5 케이스 (orchestrator phases / hook 차단 / 비활성 통과 / innocent / run-log append) — note: 파일은 evals.json (smoke.md 아님) |
| 2026-05-04T10:57Z | T9 | done | setup.sh — 스킬 하위 scripts/*.sh chmod +x 추가, 신규 프로젝트 검증 통과 |
| 2026-05-04T11:00Z | T10 | done | CHANGELOG [Unreleased] 항목 + brainstorm 백링크 1줄 |
| 2026-05-04T11:00Z | - | plan_completed | 10/10 단계 완료, 검증 + 커밋 진행 |
