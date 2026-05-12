---
name: /auto-build dogfooding cycles 1-5 결과 + 6 finding (F1~F4 PRs #50/#51, F5 PR #54, F6 진행 중)
description: 2026-05-09 cycle 1-3 (4 finding). 2026-05-12 cycle 4-5 retry로 F5/F6 발견. F5=spec stale (PR #54 fix). F6=spec 라인 76 task가 SKILL.md 스킵 조건(multi-repo)에 해당 — spec 작성 시점 미인식
type: project
originSessionId: ded670e3-5091-423e-a9e5-8ae90b707796
---
**완주 시점 (2026-05-09)**: sandbox `/Users/yss/개발/test/auto-build-test-1/`에서 `/auto-build` 사이클 본체 P0~P-end 첫 완주.

## Cycle 결과

### Cycle 1 (run_id 20260509T005231Z-01f4) — abort
- P0 ✓ → P1 abort `task_description_incomplete`
- 사유: 4문항 중 "왜 지금" 누락 (task가 단발 명령형이었음)
- branch `feat/sleep-...-Node-js-프로젝트-npm-init-` 보존

### Cycle 2 (run_id 20260509T005524Z-f9d0) — success
- P0 → P1 → P2(skipped, inline) → P3 RED → P3 GREEN → P4 verify → P5 commit → P-end
- 1 commit (`b45b836` feat(add): add(a,b) module + vitest 1 case)
- 1 vitest 케이스 통과
- 5 files / 1338 lines (대부분 package-lock.json)
- 1 iter, file_cap 75% 미도달
- branch `feat/sleep-20260509T005524Z-add-js-vitest-dogfooding`

## Calibration 4 입력 결과

| 입력 | 결과 | 의미 |
|------|------|------|
| token cap 200k 적정성 | 측정 어려움 (이 세션 cwd mismatch로 mix), small task엔 명백히 미만 | medium task 필요 |
| max_iter 30 cap | 1 iter — 30 cap은 small task 과잉 | multi-iter task 필요 |
| vote confidence 분포 | **데이터 0** — task 명시적이라 vote 발화 0 | ambiguity 포함 task 필요 |
| persona 일치율 | **데이터 0** | 동일 |

→ **본 cycle은 단발 small task '사이클 동작' 검증만**. vote/persona calibration은 후속 dogfooding에서 design/auth/perf 결정 포함 task로 회수.

## 3 추가 finding

### F1: orchestrator P1 4문항 강제 vs SKILL.md "권장" 불일치
- SKILL.md "호출 형태": "task description 가이드 — 4문항 답변 형식 **권장**"
- orchestrator.md P1.2: "4문항이 누락되었거나 모호하면 P1 진입 직후 **abort**"
- 권장 ↔ 강제 표현 불일치. 실 사용자(maker)가 자연스러운 명령형 task 입력 시 abort 빈발 가능
- **해결 후보**:
  - (a) SKILL.md를 "필수"로 강화 + 4문항 형식 예시 강조
  - (b) orchestrator를 lenient — 4문항 자동 추론 시도 (LLM 본질에 더 부합)
  - (a) 추천 — 자율 사이클은 명시성이 안전성

### F2: working tree clean이 runtime 파일에 민감
- `/auto-build`가 사이클 중 `.claude/memory/auto-build-runs.jsonl`을 매 phase append. cycle 종료 후 untracked로 남음
- 다음 cycle P0가 dirty_working_tree로 abort
- **해결 후보**: setup.sh가 `.gitignore`에 다음 패턴 자동 추가
  ```
  .claude/memory/auto-build-runs.jsonl
  .claude/events.jsonl
  .claude/session-logs/
  .claude/metrics/
  .claude/messages/inbox/
  .claude/messages/archive/
  .claude/messages/broadcast/
  .claude/.last-memory-sync
  ```
  (vibe-flow source의 `.gitignore` 패턴 일관 적용)

### F3: branch slug 한글 잔존
- orchestrator P0.2.3: `SLUG=$(echo "${task}" | tr -c '[:alnum:]' '-' | ...)`
- macOS `tr` LANG에 따라 한글이 alnum으로 인식 → 한글이 SLUG에 잔존
- 결과 branch: `feat/sleep-...-Node-js-프로젝트-npm-init-` (한글 포함)
- git은 허용하지만 가독성 저하 + URL 인코딩 필요
- **해결 후보**: `LC_ALL=C tr -c '[:alnum:]' '-'` 강제 ASCII alnum

## Cycle 3 (run_id 20260509T012449Z-bb34) — success with vote

같은 세션에서 medium task로 cycle 3 진행 — vote/persona calibration 회수.

**Task**: "add.js를 4 연산(sum/subtract/multiply/divide) 모듈로 확장. export 방식 결정 — A 단일 object vs B named exports."

**Vote 결과 (P3b design 카테고리)**:
| persona | DECISION | CONFIDENCE | REASON |
|---------|----------|------------|--------|
| designer | B | 0.90 | ESM 표준, tree-shaking, 명시적 API |
| ux-researcher | B | 0.95 | tree-shaking·IDE 자동완성·관례 |
| frontend-design-specialist | B | 0.92 | tree-shaking·IDE·타입 추론 |
| **moderator** | **B** | **0.92** | 3/3 unanimous, DISSENT: none |

**Cycle 결과**: P3 RED → GREEN(5/5 tests pass) → P5 commit `9842e89` → P-end success

## 4 Calibration 입력 — **모두 수집 완료**

| 입력 | 결과 | 출처 |
|------|------|------|
| token cap 200k | small task 30~80k, medium with vote ~138k — **vote 1회 추가 시 +60~100k** | cycle 2/3 비교 |
| max_iter 30 | 두 cycle 모두 1 iter — **small/medium 단일 task엔 30 cap 과잉** | cycle 2/3 |
| vote confidence 분포 | 0.90~0.95, avg 0.92 — **임계값 0.5 충분히 초과** (1 sample) | cycle 3 |
| persona 일치율 | **100% (3/3 B)** — 임계값 70% 통과 (1 sample) | cycle 3 |

→ **첫 dogfooding 목표 달성**. 4 입력 모두 수집 (1 sample이지만 Phase 3 진입 결정에 충분).

## 4 Finding 모두 resolved

| Finding | 위치 | Fix PR |
|---------|------|--------|
| F1 — orchestrator P1 4문항 강제 vs SKILL.md "권장" 불일치 | SKILL.md 호출 형태 | **#50** |
| F2 — working tree clean 민감 (jsonl 잔존) | setup.sh | **#50** (.gitignore 자동 패턴) |
| F3 — branch slug 한글 잔존 | orchestrator.md SLUG | **#50** (LC_ALL=C 강제) |
| F4 — ux-researcher vote 답변 외 부산물 79k tokens | persona-vote.sh, orchestrator.md P3b | **#51** (vote-only mode prompt + verbose 응답 처리) |

## How to apply (Phase 3 진입 시)

1. token cap 200k는 vote 1회 ~+100k → 30 vote × 100k = 3M 추정. **현 cap 적정** (Ralph 30 iter 가정).
2. max_iter 30은 small/medium엔 과잉이지만 large refactor + 다중 vote 시 적정 — 보존.
3. vote confidence 임계값 0.5 / 일치율 70%는 1 sample 기반이라 **추가 dogfooding 1-2회 후 calibration 갱신 권장**.
4. F4 verbose 처리는 ux-researcher 한정 발생 가능성 — 다른 카테고리(auth/perf 등) vote 시 재발 빈도 측정 필요.

## Phase 3 진입 준비

- Phase 3 = `CronCreate` 정기 스케줄 + retrospective vote 일치율 학습
- 본 4 입력으로 Phase 3 brainstorm 가능 (`.claude/memory/brainstorms/20260504-103257-vibe-flow-v2-overnight-autonomous-build.md` Phase 3 섹션 출발점)
- 단 vote 1 sample 한정 — Phase 3 brainstorm은 cron 스케줄 frequency 결정 시 추가 sample 권장

## Cycle 4 (run_id 20260512T103705Z-4495) — F5 발견 후 abort

**Task**: spec 라인 76 그대로 — "vibe-flow .claude/events.jsonl에 commit_pushed 신규 이벤트 타입 추가..."

**결과**: P0 ✓ → P1 abort `task_description_incomplete` (missing: who, why_now, success_partial)

**F5 — spec ↔ F1 fix 부정합** (resolved PR #54):
- spec PR #46 머지: 2026-05-09 (F1 fix PR #50 머지 직전)
- F1 fix는 정상 동작했으나 입력 spec(라인 76, 82)이 stale — 4문항 미적용
- retry dogfooding 시 P1 즉시 abort, calibration 회수 0건
- **Fix**: 라인 76(1차)/82(2차) 입력 문자열을 무엇을/누가/왜 지금/성공 4문항 포맷으로 재구성 (PR #54)

**교훈**: skill 강제 규칙 추가 시 그 규칙을 참조하는 spec/docs 동시 update 필요. PR 분리 시 stale 부정합 위험.

**Branch 보존**: `feat/sleep-20260512T103705Z-vibe-flow-claude-events-jsonl-` (auto-build-test-1 repo)

## Cycle 5 (run_id 20260512T104326Z-3b07) — F6 발견 후 P2 abort

**Task**: spec 라인 76 (PR #54 4문항 포맷 update 후) 그대로

**결과**: P0 ✓ → P1 ✓ (brainstorm spec 정상 작성, 4 alternative) → P2 abort `hard_gate_full_blocked` (실 원인 `multi_repo_task`)

**F6 — spec 라인 76 task ↔ SKILL.md 스킵 조건 부정합**:
- task description의 산출물은 vibe-flow source repo의 `core/skills/telemetry/SKILL.md` + hook/skill emit 로직
- 자율 사이클 cwd는 test-1 (deploy 환경) — 산출물 위치와 cwd 불일치 (multi-repo)
- SKILL.md "스킵 (수동 사이클 권장)" 명시: "multi-repo 동시 변경 (Ralph wrapper가 단일 repo 가정)"
- spec PR #46 작성 시점에 SKILL.md 스킵 조건 미참조 → F5와 같은 spec staleness 카테고리지만 다른 부정합 축

**P1 brainstorm 4 alternative 모두 부적합**:
- A. 절대경로로 source 수정 + test-1 commit → cwd boundary 위반
- B. test-1 prototype only → task 의도 미달성
- C. multi-repo 동시 변경 → SKILL.md 스킵 조건 위반
- D. abort (추천)

**보존 자료**:
- branch: `feat/sleep-20260512T104326Z-vibe-flow-claude-events-jsonl-`
- spec: `.claude/memory/brainstorms/20260512-194357-vibe-flow-claude-events-jsonl-.md`

**Fix 방향 (진행 중)**: spec 라인 76/82 단일-repo 형식 재구성 — 1차 cycle은 vibe-flow source repo cwd, 2차 cycle은 dashboard cwd. 각 cycle 단일 repo 가정 충족.

**교훈**: spec 작성 시 SKILL.md "사용 시점/스킵 조건" 참조 의무 — F5(F1 강제 규칙 참조 누락)와 같은 카테고리. spec authoring 체크리스트화 가치.
