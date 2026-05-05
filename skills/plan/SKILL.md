---
name: plan
description: 멀티스텝 작업의 계획을 파일로 작성/추적한다. brainstorm spec 또는 사용자 입력을 받아 planner 에이전트로 분석하고 .claude/plans/에 저장 후 단계별 진행 상태를 추적한다. 사용법 /plan "<주제>" | /plan from-brainstorm <파일> | /plan status [<plan-id>] | /plan complete <step-id>
effort: medium
---

작업을 머릿속이 아닌 **파일로** 가져와서 사용자 합의 후 단계별로 추적한다. /brainstorm이 "무엇을 / 왜"라면, /plan은 "어떻게 / 어떤 순서로". planner 에이전트가 분석을 수행하고 이 스킬은 artifact 라이프사이클을 관리한다.

## 사용 시점

**필수**:
- HARD-GATE 6+ 파일 변경 (`rules/git.md` 참조)
- 작업이 단일 세션을 넘길 가능성 (여러 날 / 여러 PR)
- 의존성이 있는 단계가 2개 이상

**스킵 가능**:
- HARD-GATE 1~5 파일 (인라인 설계로 충분)
- 단일 패턴 반복 작업 (예: 같은 변경을 여러 파일에 일괄 적용)

## 호출 형태

```bash
/plan "<주제>"                       # 신규 plan 생성 (사용자 입력 → planner 분석 → 파일 저장)
/plan from-brainstorm <spec-file>    # brainstorm 결과를 입력으로 plan 생성
/plan status                         # 진행 중 plan 목록 + 단계별 상태
/plan status <plan-id>               # 특정 plan 상세
/plan complete <plan-id>:<step-id>   # 단계 완료 처리
/plan revise <plan-id>               # plan 수정 (이탈 사유 기록)
```

## 절차

### 1. 입력 수집

세 가지 입력 경로:

**(A) brainstorm spec 파일** — `/plan from-brainstorm <file>`
- `## 의도 / ## 제약 / ## 추천 + 근거 / ## 다음 단계` 헤더 파싱
- Goal = 의도, Out of Scope = 제약, Approach = 추천, 단계 분해 시드 = 다음 단계

**(B) 사용자 자연어 입력** — `/plan "<주제>"`
- 의도 4문항이 모호하면 brainstorm 먼저 권장
- 명확하면 직접 진행

**(C) 기존 plan 수정** — `/plan revise <id>`
- 진행 중 발견된 변화 반영 (이탈 사유 + 수정 내용 기록)

### 2. planner 에이전트 호출 (분석)

```
Agent 호출:
  subagent_type: "general-purpose" (planner.md 프롬프트 사용)
  prompt:
    너는 planner 에이전트다. .claude/agents/planner.md의 작업 절차를 따라
    다음 입력을 분석하라:

    [Goal | Constraints | Approach]

    출력:
    - 영향 파일 목록
    - bite-sized 태스크 분해 (각 2~5분 단위)
    - 의존성 / 순서
    - 리스크 / 엣지 케이스
    - HARD-GATE 등급 자동 판정
```

### 3. 사용자 합의 게이트

planner 결과를 사용자에게 **요약 + 전체 plan** 형태로 보여준 뒤 명시적 합의 요청:

```
## 제안된 Plan

**HARD-GATE 등급**: 간략 (영향 파일 12개)
**예상 소요**: 8 단계 × 평균 4분 = 32분
**의존성**: T3 → T4, T6 → T7

[전체 단계 목록]

이대로 저장할까요? (yes / 수정 요청 / brainstorm 다시)
```

사용자가 yes 답할 때까지 plan을 파일에 저장하지 않는다 (이탈 방지).

### 4. 파일 저장

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PLAN_SLUG=$(echo "$TOPIC" | tr -c '[:alnum:]' '-' | sed 's/--*/-/g; s/^-//; s/-$//' | head -c 40)
PLAN_ID="${TIMESTAMP}-${PLAN_SLUG}"
mkdir -p .claude/plans
PLAN_FILE=".claude/plans/${PLAN_ID}.md"
```

events.jsonl 기록:
```bash
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"plan_created\",\"plan_id\":\"$PLAN_ID\",\"steps\":${N},\"hard_gate\":\"$LEVEL\"}" >> .claude/events.jsonl
```

### 5. Plan 파일 구조 (표준 형식)

```markdown
---
plan_id: <YYYYMMDD-HHMMSS>-<slug>
status: in_progress    # in_progress | completed | abandoned
created: <ISO 8601>
hard_gate: <inline | brief | full>
source: <brainstorm-file-path | user-direct | revision-of:plan_id>
---

# Plan: <topic>

## Goal
<brainstorm 의도 또는 사용자 입력>

## Approach
<brainstorm 추천 또는 planner 권고 — 1 단락>

## Out of Scope
- <제약 / 의도적으로 안 다루는 영역>

## 영향 파일

| 파일 | 변경 유형 | 비고 |
|------|----------|------|
| ... | ... | ... |

## 단계

### T1: <step name>
- **상태**: pending | in_progress | done | blocked
- **파일**: `src/features/x/actions.ts`
- **변경**: <구체적 수정 내용>
- **DoD**: <완료 확인 방법 — 측정 가능>
- **의존**: 없음 | T<n>
- **완료일**: <YYYY-MM-DD or empty>
- **노트**: <도중 발견한 이슈, 결정 변경 등>

### T2: ...

## 리스크
- <리스크 + 완화책>

## 진행 추적

| 시각 | 단계 | 상태 변경 | 비고 |
|------|------|----------|------|
| 2026-04-25T10:00:00Z | T1 | pending → in_progress | |
| 2026-04-25T10:30:00Z | T1 | in_progress → done | DoD 충족 |
```

### 6. 상태 업데이트 — `/plan complete <plan-id>:<step-id>`

```bash
# 단계 상태 변경 + 진행 추적 표에 행 추가
# events.jsonl에 plan_step_complete 기록
echo "{\"ts\":\"...\",\"type\":\"plan_step_complete\",\"plan_id\":\"...\",\"step\":\"T1\"}" >> .claude/events.jsonl

# 모든 단계 완료 시 frontmatter status: completed로 변경
```

### 7. 이탈 처리 — `/plan revise <plan-id>`

진행 중 새 정보 발견 시 plan을 강제 변경하지 말고:

1. 기존 plan을 status: `abandoned` 또는 superseded로 변경
2. 새 plan 생성 시 frontmatter `source: revision-of:<old_plan_id>`
3. 노트에 이탈 사유 명시 (다음 회고에서 분석 가능)

> **금지**: 사용자 합의 없이 plan을 silently 수정. 작업 도중 plan과 다르게 진행하더라도 plan 파일은 진실의 원천으로 유지하고, 차이를 진행 추적 표에 기록.

## 다음 스킬과의 연계

| 시점 | 스킬 |
|------|------|
| Plan 생성 후 첫 단계 시작 | 직접 구현 / `/pair "<step description>"` |
| 단계 의존성 복잡도 높음 | `Claude Squad` 오케스트레이터 — 독립 단계를 worktree에서 병렬 |
| 단계 중 디자인 변경 발생 | `designer` 에이전트 (Phase 0 자동 진행) |
| 단계 중 보안 우려 발견 | `security` 에이전트 호출 |
| 모든 단계 완료 후 | `/verify` → `/release` 또는 머지 |

## /brainstorm ↔ /plan 호환성

`/brainstorm`이 출력한 spec 파일은 `/plan from-brainstorm`의 표준 입력. 매핑 계약:

| brainstorm 헤더 | plan에서의 용도 |
|----------------|---------------|
| `## 의도` | `## Goal` (4문항을 1~2단락으로 압축) |
| `## 제약` | `## Out of Scope` + 영향 파일 추정의 입력 |
| `## 추천 + 근거` | `## Approach` |
| `## 다음 단계` | T1, T2, ... 단계 분해의 시드 |

> brainstorm spec의 헤더가 변경되면 이 매핑도 업데이트 필요. 두 스킬은 헤더 계약으로 결합.

## 메시지 버스 알림 (선택적)

기본 정책: **알림 안 함**. 다음 좁은 케이스에만 message-bus 발송:

| 조건 | 수신자 | type / priority |
|------|--------|----------------|
| HARD-GATE 전체(20+) 등급 plan 신규 생성 | `planner` | request / high |
| plan revise (이탈) 발생 | `retrospective` | regression / medium |
| 단계 의존성에 designer/security 작업 포함 | 해당 에이전트 | request / medium |
| stale plan 30일+ 감지 (retrospective가 발견 시) | 사용자 | warn / high |

```bash
bash .claude/hooks/message-bus.sh send plan <to> request <priority> "..." "..."
```

## 규칙

- 사용자 합의 없이 plan 파일을 저장하지 않는다
- 한 단계는 2~5분, 영향 파일 3개 이하 (`planner.md` 규칙 준수)
- DoD가 모호한 단계는 불완전 — 측정 가능한 검증 방법 필수
- HARD-GATE 인라인(1~5 파일)이면 plan 생성 자체를 권장 안 함 (인지 비용 > 이득)
- 이탈은 silent 수정 금지 — `/plan revise`로 명시적 처리
- plan 파일은 git 추적 대상 (`.claude/plans/` 디렉토리, 영구 보관)
- 30일 이상 in_progress 상태인 plan은 retrospective가 자동 stale 표시 → 정리 또는 재계획
