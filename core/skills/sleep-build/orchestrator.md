# sleep-build Orchestrator

`/sleep-build`의 자율 사이클 본체. SKILL.md가 진입점이라면 이 파일은 단계별 결정 트리.

## 입력 계약

```
task: <자연어 task description (4문항 답변 형식 권장)>
run_id: <ISO 8601 timestamp + 4-char hex, 예: 20260504T103257Z-a1b2>
```

## 단계 시퀀스

### P0 — 전처리 (자율 모드 진입)

**목표**: 자율 사이클 환경 격리 — branch 분기 + safety hook 활성화 + run-log 시작.

**실행** (이 순서를 반드시 지킴):
1. working tree 정합성 확인 — `git status --porcelain` 결과가 비어 있어야 함. 비어 있지 않으면 즉시 abort (uncommitted 변경은 자율 사이클 진입 신호 X)
2. `run_id` 결정 — 형식 `<UTC ISO 8601 (no separators)>-<4자 hex>`, 예: `20260504T103257Z-a1b2`
3. branch 자동 생성:
   ```bash
   SLUG=$(echo "${task}" | tr -c '[:alnum:]' '-' | sed 's/--*/-/g; s/^-//; s/-$//' | head -c 30)
   BRANCH="feat/sleep-${run_id%-*}-${SLUG}"
   git checkout -b "${BRANCH}"
   ```
4. **자율 모드 환경 변수 export** — 이 시점부터 PreToolUse safety hook이 활성:
   ```bash
   export SLEEP_BUILD_MODE=1
   export SLEEP_BUILD_RUN_ID="${run_id}"
   ```
5. `bash core/skills/sleep-build/scripts/run-log.sh start ${run_id} phase=P0 branch=${BRANCH} task="${task}"`

**종료 조건**:
- ✓ pass: branch checkout 성공 + env 2개 export + run-log start 1줄 append
- ✗ fail: working tree dirty / branch 생성 실패 / run-log 실패 → abort (env 미설정 상태로 종료)

**종료 처리**:
- pass → P1 진입
- fail → 시퀀스 즉시 종료. branch 미생성이면 cleanup 불필요. branch 생성됐으면 보존.

---

### P1 — Brainstorm

**목표**: task → brainstorm spec 파일 1개 생성. 사용자 추가 입력 없이 통과.

**실행**:
1. `bash core/skills/sleep-build/scripts/run-log.sh start ${run_id} phase=P1 task="${task}"` 호출
2. `/brainstorm "${task}"` 슬래시 스킬 invoke
3. 스킬이 4문항 추가 질문 던지면 **즉시 abort** (R7 완화) — `exit_reason=brainstorm_clarification_required`
4. 결과 spec 파일 경로 캡처 — `.claude/memory/brainstorms/<timestamp>-<slug>.md`

**종료 조건**:
- ✓ pass: spec 파일 1개 생성 + `## 의도 / ## 제약 / ## 추천 + 근거 / ## 다음 단계` 4 헤더 모두 존재
- ✗ fail: spec 미생성 / 헤더 누락 / 추가 질문 발생 → abort

**종료 처리**:
- pass → `run-log.sh start ${run_id} phase=P1_done spec_file="${path}"`
- fail → `run-log.sh abort ${run_id} phase=P1 exit_reason="${reason}"` + 시퀀스 종료

---

### P2 — Plan

**목표**: brainstorm spec → 구현 plan 1개 생성 + 사용자 합의 게이트 자동 통과.

**실행**:
1. `run-log.sh start ${run_id} phase=P2`
2. `/plan from-brainstorm <spec-file-path>` invoke
3. plan 스킬은 사용자 합의 게이트가 있다 — 자율 모드에서는 brainstorm spec의 `## 추천 + 근거` 단락이 명시적이면 자동 yes 처리. 추천이 모호하거나 alternatives ≥ 2 미만이면 abort.
4. plan 파일 경로와 `plan_id` 캡처
5. plan의 `hard_gate` 필드 검증 — `full`(20+ 파일)이면 즉시 abort (file count cap 진입 방지)

**종료 조건**:
- ✓ pass: plan 파일 생성 + `hard_gate ∈ {inline, brief}` + 단계 ≥ 1
- ✗ fail: plan 미생성 / hard_gate=full / 단계 0개 → abort

**종료 처리**:
- pass → `run-log.sh start ${run_id} phase=P2_done plan_id="${id}" hard_gate="${level}" steps=${n}`
- fail → `run-log.sh abort ${run_id} phase=P2 exit_reason="${reason}"`

---

### P3 — TDD 구현

**목표**: plan의 T1..Tn을 순차 구현. 각 단계마다 TDD 사이클 강제.

**실행 (단계마다 반복)**:
1. `run-log.sh start ${run_id} phase=P3 step=Tn`
2. **RED**: 단계 DoD에 부합하는 테스트 작성 (vitest / shellcheck / smoke 등 단계 성격에 맞게)
3. 테스트 실행 → **실패 확인** (테스트 인프라 자체 오류와 구분)
4. **GREEN**: 최소 구현으로 테스트 통과
5. 테스트 재실행 → **통과 확인**
6. plan 파일에서 해당 단계 `상태: pending → done` 업데이트 + 진행 추적 표 한 행 추가
7. `run-log.sh start ${run_id} phase=P3 step=Tn_done`

**종료 조건 (단계별)**:
- ✓ pass: RED→GREEN 사이클 완료 + plan 단계 done 마킹
- ✗ fail (재시도 1회 허용):
  - 첫 실패: 단계만 재진입 (다른 접근), max 1회
  - 두번째 실패: 전체 P3 abort + branch 보존

**종료 조건 (P3 전체)**:
- ✓ pass: plan 모든 단계 done
- ✗ fail: 어느 단계든 두번째 실패 / file count cap 도달 / token cap 도달 → abort

**종료 처리**:
- pass → `run-log.sh start ${run_id} phase=P3_done steps_done=${n}`
- fail → `run-log.sh abort ${run_id} phase=P3 step=Tn exit_reason="${reason}"`

---

### P4 — Verify

**목표**: 프로젝트 전체 검증 통과 (lint/typecheck/test/E2E).

**실행 (최대 3회 재시도)**:
1. `run-log.sh start ${run_id} phase=P4 attempt=${n}`
2. `/verify` 슬래시 스킬 invoke
3. 실패 시 — 실패 카테고리 식별:
   - lint/format 자동 수정 가능 → 1회 fix 후 재시도
   - typecheck 명백한 오류 → 1회 fix 후 재시도
   - test 실패 → 1회 디버깅 후 재시도 (R1 완화: 모호 시 abort 우선)
   - E2E / browser console → abort (사용자 시각 검증 필수)
4. 3회 시도 후에도 실패면 abort

**종료 조건**:
- ✓ pass: `/verify` exit 0
- ✗ fail: 3회 실패 / abort 카테고리(E2E 등) → abort

**종료 처리**:
- pass → `run-log.sh start ${run_id} phase=P4_done attempts=${n}`
- fail → `run-log.sh abort ${run_id} phase=P4 exit_reason="${reason}"`

---

### P5 — Commit + Finish

**목표**: 변경 커밋 + PR 생성. main 직접 push 금지 (branch 격리 유지).

**실행**:
1. `run-log.sh start ${run_id} phase=P5`
2. `/commit` 슬래시 스킬 invoke — Conventional Commit 메시지 자동 생성. 단일 커밋 또는 의미 단위 커밋 (자율 사이클은 단일 커밋 권장)
3. `git push -u origin feat/sleep-${timestamp}-${slug}`
4. `/finish` 슬래시 스킬 invoke — `--path pr` 강제 (자율 사이클은 항상 PR 생성, 직접 머지 X)
5. PR URL 캡처

**종료 조건**:
- ✓ pass: PR open 상태 확인 + URL 보유
- ✗ fail: push 실패 / PR 생성 실패 → abort (branch는 보존)

**종료 처리**:
- pass → `run-log.sh done ${run_id} phase=P5 pr_url="${url}" branch="${branch}"`
- fail → `run-log.sh abort ${run_id} phase=P5 exit_reason="${reason}" branch="${branch}"`

---

### P-end — 후처리 (자율 모드 종료)

**목표**: 사이클 종료 시 자율 모드 환경 변수 정리 + run-log 최종 라인 append. 성공/실패 모두 반드시 통과.

**실행** (이 순서를 반드시 지킴):
1. 사이클 결과 분기:
   - 성공: `bash core/skills/sleep-build/scripts/run-log.sh done ${run_id} branch=${BRANCH} pr_url="${url}"`
   - 실패: `bash core/skills/sleep-build/scripts/run-log.sh abort ${run_id} phase=${last_phase} branch=${BRANCH} exit_reason="${reason}"`
2. **자율 모드 환경 변수 unset**:
   ```bash
   unset SLEEP_BUILD_MODE
   unset SLEEP_BUILD_RUN_ID
   ```
3. branch는 폐기 X — 성공이면 PR open 상태로 maker review 대기, 실패면 부분 진행 보존
4. main 자동 checkout X — 사이클 종료 후 사용자 의도 명확하지 않음

**종료 조건**:
- 항상 ✓ pass — P-end 자체는 abort 분기 없음 (환경 정리 의무)

---

## 실패 공통 정책

자율 사이클의 모든 abort는:
1. **branch 폐기 X** — maker morning review 자료로 보존
2. **부분 진행 commit 보존** — 이미 커밋된 변경은 유지
3. **jsonl `exit_reason` 명시** — 다음 사이클 calibration 자료
4. **사용자 추가 입력 대기 금지** — abort = 즉시 사이클 종료
5. **destructive 복구 시도 금지** — `git reset --hard`, `rm -rf` 등 safety hook이 차단

## 안전 hook 결합 계약

orchestrator는 P0/P-end에서 다음 환경 변수 라이프사이클을 강제한다:
- 사이클 시작 (P0): `export SLEEP_BUILD_MODE=1`, `export SLEEP_BUILD_RUN_ID=<run_id>`
- 사이클 종료 (P-end): `unset SLEEP_BUILD_MODE`, `unset SLEEP_BUILD_RUN_ID`

이 두 env가 set된 동안만 `core/hooks/sleep-build-safety.sh`(PreToolUse)가 destructive op / token cap / file cap 차단을 활성화한다. P0 미실행 또는 P-end 실패로 env가 누출되지 않도록 P-end는 abort 경로 포함 **항상** 실행한다 (위 시퀀스 참조).

orchestrator의 자연어 시퀀스는 hook 차단을 신뢰하고 추가 검사를 중복 수행하지 않는다 — destructive op는 hook이 막고, orchestrator는 abort 처리만 담당.

## 결정 트리 요약

```
P0 전처리     → ok? ─── no ──→ 시퀀스 종료 (env 미설정)
   │ yes (env export, branch checkout, run-log start)
P1 brainstorm → ok? ─── no ──→ P-end (abort: clarification)
   │ yes
P2 plan       → ok? ─── no ──→ P-end (abort: full grade / no recommendation)
   │ yes
P3 TDD        → ok? ─── no ──→ P-end (abort: step retry exhausted / cap)
   │ yes
P4 verify     → ok? ─── no ──→ P-end (abort: 3 attempts / E2E fail)
   │ yes
P5 commit/PR  → ok? ─── no ──→ P-end (abort: push / PR creation fail)
   │ yes
P-end 후처리  → 항상 실행 (env unset, run-log done|abort)
   │
DONE — branch + PR 보존, jsonl 라인 누적
```

모든 abort 경로는 branch 보존 + `run-log.sh abort` + P-end 통한 env unset + 즉시 종료. 사이클 도중 maker 추가 입력은 일절 요청하지 않는다.
