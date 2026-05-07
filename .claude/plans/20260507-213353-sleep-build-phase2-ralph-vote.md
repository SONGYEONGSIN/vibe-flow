---
plan_id: 20260507-213353-sleep-build-phase2-ralph-vote
status: in_progress
created: 2026-05-07T12:33:53Z
hard_gate: brief
source: brainstorm-file:.claude/memory/brainstorms/20260507-212317-sleep-build-phase2-ralph-loop-persona-vote.md
related_phase1_plan: .claude/plans/20260504-194208-vibe-flow-sleep-build-phase1.md
---

# Plan: sleep-build Phase 2 — Ralph loop + persona voting

## Goal

`/sleep-build`를 단발 1 사이클에서 **multi-iteration Ralph loop + persona vote 자율 결정**으로 확장한다. ambiguity (디자인/auth/perf 결정)가 발생해도 사용자 입력 요청 없이, 24개 agent 풀에서 카테고리별로 3~5명을 자동 dispatch → moderator 중재 → 결정 stdout 으로 사이클을 계속 진행한다. Ralph wrapper는 file_cap 도달 직전 PR push + 새 branch 진입을 N (기본 30) iteration까지 반복하여 본격 SaaS task (예: 인증 페이지 5개 stub)를 PR 분할로 무인 완주한다.

## Approach (선택: 대안 A — Ralph + vote 동시 머지)

- **vote 메커니즘**: shell script (`persona-vote.sh`) 가 ambiguity 질문 + 카테고리를 인자로 받아 `persona-mapping.json` lookup → `Agent` tool 호출 명령을 stdout 출력 (orchestrator가 실제 Agent dispatch). 결과 vote 5개 수집 후 moderator agent 호출 → 결정 1줄 + 사유 stdout. 사이클 jsonl 에 `vote_triggered` 이벤트 추가.
- **Ralph wrapper**: orchestrator.md 에 외부 loop 시퀀스 추가. 1 iter = P0~P-end 1회. iter 종료 시 (a) max_iterations 도달 → exit (b) file_cap 75% 도달 → 강제 P5 + 새 branch 진입 (c) 모든 P3 단계 완료 → 정상 종료. iter간 상태는 jsonl `iteration` 키로 추적.
- **safety hook 수정**: token cap 130k → 200k (vote 1회당 ~5k × 30 = 150k 여유), 신규 `SLEEP_BUILD_MAX_ITERATIONS` (기본 30).
- **SKILL.md 완화**: "디자인 결정 포함" / "HARD-GATE 전체 등급" 스킵 조건 → "vote 자동 처리" / "Ralph 분할 처리" 로 갱신.
- **evals.json**: 5 → 9 케이스 (vote 4 신규).
- **검증**: `bash -n` 모든 sh, `jq empty` json, evals 9 케이스 grep/exit-code 검증, 사용자 dogfooding은 머지 후 별도.

## Out of Scope

- Phase 3 — `CronCreate` 정기 야간 스케줄, retrospective agent 자가 진화 (vote 일치율 학습)
- 짝 dashboard 매핑 — `sleep_build_iteration_complete`, `sleep_build_vote_triggered` 이벤트 dashboard 시각화 (별도 PR)
- 실제 Agent tool dispatch end-to-end 검증 — evals 는 호출 패턴만 grep, 실 dispatch 는 dogfooding 사이클로 calibration
- vote 결정 품질 자동 평가 루프 — Phase 3 retrospective 책임
- 24 agent 본체 수정 — 모두 PR #38 그대로 사용, persona-vote.sh가 dispatch만 담당

## 영향 파일

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `core/skills/sleep-build/data/persona-mapping.json` | 신규 | 카테고리(design/auth/perf/architecture/ui/test/docs) → persona id 풀 매핑 |
| `core/skills/sleep-build/scripts/persona-vote.sh` | 신규 | ambiguity → 카테고리 → persona pool dispatch 명령 + moderator 중재 결과 stdout |
| `core/skills/sleep-build/orchestrator.md` | 수정 | P3 ambiguity 분기 (P3a/P3b) + Ralph wrapper 시퀀스 + 결정 트리 갱신 |
| `core/hooks/sleep-build-safety.sh` | 수정 | token cap 기본값 200000 + `SLEEP_BUILD_MAX_ITERATIONS` 차단 추가 |
| `core/skills/sleep-build/SKILL.md` | 수정 | 스킵 조건 완화 + token cap 200k 표기 + vote/Ralph 절차 1단락 추가 |
| `core/skills/sleep-build/evals/evals.json` | 수정 | 5 → 9 케이스 (vote 4 + 기존 5 유지) |

총 6 파일 (신규 2 + 수정 4) — **HARD-GATE 간략 등급**.

## 단계

### T1 — persona-mapping.json 신규 작성
- **상태**: pending
- **파일**: `core/skills/sleep-build/data/persona-mapping.json`
- **변경**: 카테고리 7개 (design/auth/perf/architecture/ui/test/docs) → 각 3~5 persona id 배열. id 는 `core/agents/<id>.md` 파일명 기준. 예: `"design": ["designer","ux-researcher","frontend-design-specialist"]`. moderator는 `_moderator: "moderator"` 별도 키.
- **DoD**: `jq empty` 통과 + 7 카테고리 모두 ≥3 persona + 모든 persona id가 `core/agents/` 실재 파일과 1:1 일치
- **의존**: 없음

### T2 — persona-vote.sh 신규 (skeleton + 인자 파싱)
- **상태**: pending
- **파일**: `core/skills/sleep-build/scripts/persona-vote.sh`
- **변경**: shebang `#!/bin/bash`, `set -uo pipefail`, usage `persona-vote.sh <category> <question>` 두 인자 검증. 카테고리 미지정/매핑 부재 시 stderr `unknown_category` + exit 3. NFC 정규화 (run-log.sh 동일 패턴 재사용).
- **DoD**: `bash -n` 통과, `chmod +x` 적용, 인자 0개로 호출 시 usage 출력 + exit 1, 미존재 카테고리 호출 시 exit 3
- **의존**: T1

### T3 — persona-vote.sh dispatch 명령 합성
- **상태**: pending
- **파일**: `core/skills/sleep-build/scripts/persona-vote.sh`
- **변경**: `jq` 로 mapping.json 읽어 카테고리 persona 배열 추출. 각 persona 별로 stdout `AGENT_DISPATCH:<persona>:<question>` 라인 출력. 마지막 라인 `MODERATOR_DISPATCH:moderator:<question>:<vote_results_placeholder>`.
- **DoD**: 카테고리 `design` 호출 시 stdout 4 라인 (3 AGENT + 1 MODERATOR), 각 라인 `^(AGENT|MODERATOR)_DISPATCH:` 매칭, exit 0
- **의존**: T2

### T4 — persona-vote.sh jsonl 이벤트 기록
- **상태**: pending
- **파일**: `core/skills/sleep-build/scripts/persona-vote.sh`
- **변경**: `SLEEP_BUILD_RUN_ID` env 가 set 일 때만 `run-log.sh` 호출 — `start <run_id> phase=vote category=<cat> personas=<n> question="<q-truncated-80>"`. set 안되어 있으면 silent skip.
- **DoD**: `SLEEP_BUILD_RUN_ID=test-v1` env로 호출 시 jsonl에 `event=start phase=vote category=design personas=3` 라인 1개 append, env 없을 때는 jsonl 변동 없음
- **의존**: T3

### T5 — orchestrator.md P3 ambiguity 분기 추가
- **상태**: pending
- **파일**: `core/skills/sleep-build/orchestrator.md`
- **변경**: P3 섹션 본문에 "P3a (진행 가능) / P3b (ambiguity 발생)" 분기 표 + 절차. P3b: (1) 카테고리 식별 (2) `bash persona-vote.sh <cat> "<q>"` (3) stdout `AGENT_DISPATCH:` 라인을 실제 `Agent` tool 호출로 변환 (4) 결과 + MODERATOR 처리 후 결정 채택 (5) 결정 implementation comment 주입 + RED 재진입. abort 조건: confidence 전원 0.5 미만 → exit_reason `vote_low_confidence`.
- **DoD**: P3 섹션에 `#### P3a` `#### P3b` 두 헤더, "persona-vote.sh" ≥1, "vote_low_confidence" ≥1, 결정 트리에 vote 분기 화살표 추가
- **의존**: T4

### T6 — orchestrator.md Ralph wrapper 시퀀스 추가
- **상태**: pending
- **파일**: `core/skills/sleep-build/orchestrator.md`
- **변경**: 새 섹션 `## Ralph Loop Wrapper` (단계 시퀀스 위, 입력 계약 아래). `ITER` (1부터), `MAX_ITER=${SLEEP_BUILD_MAX_ITERATIONS:-30}`. 1 iter = P0~P-end 완주. 종료 조건 3가지 (max_iter / file_cap 75% / 모든 plan done). jsonl `iteration=N` 키 모든 phase event에 자동 첨부. 결정 트리 다이어그램 갱신 (외부 loop 화살표). **branch base = 직전 iter tip** 명시 (R3 완화).
- **DoD**: orchestrator.md에 `## Ralph Loop Wrapper` 헤더, "MAX_ITER" 또는 "SLEEP_BUILD_MAX_ITERATIONS" ≥2, "iter+1" 또는 "다음 iter" ≥1, 결정 트리에 `iter < MAX` 분기 추가
- **의존**: T5

### T7 — sleep-build-safety.sh token cap 기본값 상향
- **상태**: pending
- **파일**: `core/hooks/sleep-build-safety.sh`
- **변경**: `TOKEN_CAP="${SLEEP_BUILD_TOKEN_CAP:-130000}"` → `:-200000`. 주석에 `# Phase 2: 200k (vote 1회당 ~5k × 30 = 150k 여유)` 추가.
- **DoD**: `grep '200000' core/hooks/sleep-build-safety.sh` ≥1, `bash -n` 통과, env 미설정 + 누적 199999 token 시 통과 / 200001 시 차단
- **의존**: 없음 (T1~T6과 병렬 가능)

### T8 — sleep-build-safety.sh max_iterations 차단 로직
- **상태**: pending
- **파일**: `core/hooks/sleep-build-safety.sh`
- **변경**: token cap 블록 다음에 새 블록. `MAX_ITER="${SLEEP_BUILD_MAX_ITERATIONS:-30}"`. `SLEEP_BUILD_RUN_ID` jsonl에서 가장 큰 `iteration` 값 jq 추출 → cap 초과 시 stderr `BLOCKED — max iterations 초과` + exit 2 + `exit_reason=max_iterations_exceeded`.
- **DoD**: `bash -n` 통과, `SLEEP_BUILD_MODE=1 SLEEP_BUILD_RUN_ID=test SLEEP_BUILD_MAX_ITERATIONS=2` + jsonl iteration=3 시뮬레이션 시 exit 2, iteration=1 시 exit 0
- **의존**: T7

### T9 — SKILL.md 스킵 조건 완화 + 절차 갱신
- **상태**: pending
- **파일**: `core/skills/sleep-build/SKILL.md`
- **변경**: (a) "스킵" 항목 갱신: "디자인 결정 포함" 제거 (vote 처리), "HARD-GATE 전체 등급" 제거 (Ralph 분할). 잔여 스킵: 모호한 의도 / stacked PR / multi-repo. (b) "안전 계약" 3번 130000 → 200000. (c) 새 5번 — `SLEEP_BUILD_MAX_ITERATIONS` 30 cap. (d) "절차 요약" 4-step → 5-step (Ralph iter loop 추가). (e) "관련 파일" 표에 persona-vote.sh + persona-mapping.json 2 행.
- **DoD**: `grep '200000' SKILL.md` ≥1, `grep 'MAX_ITERATIONS'` ≥1, `grep 'persona-vote'` ≥1, "디자인 결정 포함" 부재
- **의존**: T6, T8

### T10 — evals.json — vote 케이스 4개 추가
- **상태**: pending
- **파일**: `core/skills/sleep-build/evals/evals.json`
- **변경**: 신규 4 케이스: (a) `persona-mapping-jq-valid` — `jq empty` + 카테고리 ≥7 (b) `persona-vote-dispatch-grep` — `bash persona-vote.sh design "테스트"` stdout 4 라인 매칭 (c) `orchestrator-ralph-wrapper-present` — orchestrator.md grep `## Ralph Loop Wrapper` + `MAX_ITERATIONS` ≥2 (d) `safety-max-iterations-block` — env iter=31 시 exit 2 + stderr `max iterations`. version `1.0.0` → `2.0.0`.
- **DoD**: `jq '.cases | length' evals.json` = 9, `jq empty` 통과, `jq '.version'` = `"2.0.0"`, 신규 4 케이스 모두 `id description input expected` 4 키 보유
- **의존**: T1, T2, T3, T6, T8

### T11 — evals 전체 9 케이스 회귀 검증
- **상태**: pending
- **파일**: 없음 (검증만)
- **변경**: evals 9 케이스 각 input 명령 실행 → expected 매칭 확인. 기존 5 회귀 0 + 신규 4 통과. 실패 시 해당 T번호 재진입.
- **DoD**: 9/9 통과, `bash -n` 모든 .sh 통과, `jq empty` 모든 .json 통과
- **의존**: T1, T2, T3, T4, T5, T6, T7, T8, T9, T10

### T12 — 통합 smoke + cross-link
- **상태**: pending
- **파일**: `core/skills/sleep-build/SKILL.md`, `core/skills/sleep-build/orchestrator.md`
- **변경**: SKILL.md / orchestrator.md 끝에 `## 관련 plan` 섹션 — Phase 1 plan + 본 Phase 2 plan 경로 cross-link. 결정 트리에 vote 분기 + Ralph 외부 loop 화살표 모두 시각 확인.
- **DoD**: 두 파일 모두 `phase2-ralph` 또는 본 plan_id 문자열 ≥1, 결정 트리 줄 수 ≥10 (기존 ~13 + Ralph wrapper 화살표 ≥2)
- **의존**: T11

## 리스크

- **R1 vote 결정 품질 미검증**: persona pool 매핑이 첫 dogfooding 전에는 calibration 안됨. **완화** — Phase 2 머지 후 작은 task 1개로 vote 1회 발화 dogfooding, 일치율 70% 미달 시 mapping 재조정 (Phase 2.1 fast-follow PR).
- **R2 Agent tool dispatch 비용 폭증**: vote 1회 5 persona × ~1k token. 30 iter × 1 vote = 150k. **완화** — `SLEEP_BUILD_TOKEN_CAP` env override 가능, jsonl `vote_triggered` 사후 분석.
- **R3 Ralph iter 간 branch 전환 충돌**: file_cap 75% 도달 시 P5 강제 push + 새 branch. 직전 iter PR 미머지 + 새 branch = stacked PR 사고 위험 (memory `feedback_stacked_pr_merge.md`). **완화** — Ralph wrapper가 새 branch base를 main 아닌 직전 iter branch tip으로 (orchestrator T6), morning review에서 maker가 squash 순서 결정.
- **R4 persona-vote.sh shellcheck 회귀**: Agent 호출 명령 stdout 합성에서 quoting 실수. **완화** — T2~T4 모두 `bash -n` + 0 인자/미존재 cat/정상 cat 3 시나리오 단계별 DoD.
- **R5 moderator 중재 결과 모호**: confidence 전원 0.5 미만 → `vote_low_confidence` abort. **완화** — orchestrator T5 abort exit_reason 명시 + 첫 dogfooding 후 confidence 분포 jsonl 분석 → 임계값 0.5 적정성 검토 (Phase 2.1 후속).
- **R6 max_iterations cap 부족**: 30 cap이 본격 SaaS task엔 부족 가능. **완화** — `SLEEP_BUILD_MAX_ITERATIONS` env override, 차단 시 jsonl `max_iterations_exceeded` 명시 → 다음 사이클 calibration.

## 진행 추적

| 시각 | 단계 | 상태 변경 | 비고 |
|------|------|----------|------|
| 2026-05-07T12:33:53Z | - | plan 생성 | 사용자 합의 (간략 등급, T1~T12) |
