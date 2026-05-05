---
name: brainstorm
description: 구현 시작 전 사용자 의도/제약/대안을 구조화 탐색하여 결정 근거를 명시한다. 결과는 .claude/memory/brainstorms/ 에 저장되어 이후 /plan 또는 직접 구현의 입력이 된다. 사용법 /brainstorm "<주제>"
effort: medium
---

새 기능을 만들기 전에 의도와 대안을 명시하여 잘못된 방향으로 빠르게 가는 것을 막는다. **모든 창의적 작업의 입구**가 되어야 한다. designer의 Phase 0가 디자인 한정이라면, /brainstorm은 도메인 무관 일반 의도 탐색.

## 사용 시점

**필수**:
- 새 기능/페이지/컴포넌트 신규 도입
- 기존 동작의 의도적 변경 (단순 버그 수정 제외)
- 아키텍처 결정 (DB 스키마, API 형태, 라이브러리 선택)
- 작업 범위가 모호하다고 느껴지는 모든 순간

**스킵 가능**:
- 명백한 버그 수정 (재현 → 수정)
- 단순 리팩토링 (동작 보존, 구조만 정리)
- 타입 에러 수정
- 작은 변경 (3파일 미만 + 새 기능 없음)

## 절차

### 1. 컨텍스트 자동 로드

세션 시작 시 메모리를 먼저 읽어 **이미 알려진 것을 다시 묻지 않는다**:

```bash
# 프로젝트 특성
cat .claude/memory/project-profile.md 2>/dev/null

# 누적 패턴 / 이전 결정
cat .claude/memory/patterns.md 2>/dev/null

# 최근 brainstorm (중복 주제 방지)
ls -1t .claude/memory/brainstorms/*.md 2>/dev/null | head -5
```

### 2. 의도 4문항 (소크라테스 검증)

| 질문 | 자기검증 |
|------|---------|
| **무엇을 만들 것인가** (구체적 산출물) | "10개 다른 프로젝트에도 적용 가능?"이면 충분히 구체적이지 않음 |
| **누가 사용할 것인가** (사용자 + 시나리오) | "사용자 + 시점 + 대체 행동"이 모두 답변되었는가 |
| **왜 지금인가** (트리거, 우선순위) | "다음 분기로 미루면 무슨 일이 생기는가" 답할 수 있는가 |
| **성공이 무엇인가** (검증 가능한 기준) | "측정 가능한 metric"으로 표현 가능한가, "잘 동작하면 됨"인가 |

> **행동 규칙**: 4개 중 2개 이상이 모호하면 사용자에게 **핵심 1~2개만** 자연스럽게 질문 — 4개를 한꺼번에 쏟아내지 않는다 (designer Phase 0와 동일 원칙).

### 3. 제약 발견

| 카테고리 | 점검 항목 |
|---------|---------|
| **기술** | 스택 호환성, 성능, 접근성, 보안 (auth/RLS/secret) |
| **비즈니스** | 시간, 비용, 외부 의존성, 컴플라이언스 |
| **코드베이스** | 기존 패턴 준수, 부채 회피, 모듈 커플링 |

이미 안다면 명시, 모르면 사용자 확인 또는 `security`/`qa` 에이전트에게 도메인 위임.

### 4. 대안 도출 (최소 2개 + "아무것도 안 하기")

```markdown
## 대안 A: <접근 1>
- 핵심 아이디어: <한 줄>
- 비용: <시간/복잡도>
- 위험: <실패 시나리오>
- 가역성: <쉽게 되돌릴 수 있는가>
- 학습 효과: <이 길로 가면 무엇을 배우는가>

## 대안 B: <접근 2>
[동일 형식, 의도적으로 다른 trade-off 강조]

## 대안 Z (do nothing)
- 지금 안 하면 무슨 일이 생기는가
- 임시 우회책으로 해결되는가
```

> **2개 미만이면 brainstorm 실패**. "이것밖에 답이 없다"라고 느껴진다면 충분히 탐색 안 한 것 — 의도적으로 반대 방향 alternative를 1개 더 만든다.

### 5. 추천 + 근거 + 기각 이유

```markdown
## 추천: 대안 A

**선택 근거**: <이 컨텍스트에서 A가 적합한 1~3개 이유>

**기각된 대안 B**: <왜 선택 안 했는가, 어떤 상황이면 B로 전환할 가치 있는가>
```

### 6. Spec 파일 저장

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TOPIC_SLUG=$(echo "$ARGUMENTS" | tr -c '[:alnum:]' '-' | sed 's/--*/-/g; s/^-//; s/-$//' | head -c 40)
mkdir -p .claude/memory/brainstorms
SPEC_FILE=".claude/memory/brainstorms/${TIMESTAMP}-${TOPIC_SLUG}.md"
```

events.jsonl에도 기록:
```bash
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"brainstorm\",\"topic\":\"$ARGUMENTS\",\"alternatives\":${N},\"chosen\":\"A\"}" >> .claude/events.jsonl
```

## 출력 형식 (사용자에게)

```markdown
## Brainstorm: <주제>

### 의도
- 산출물: ...
- 사용자: ...
- 트리거: ...
- 성공 기준: ...

### 제약 요약
- [3~5 bullet points]

### 대안 비교

| 항목 | 대안 A | 대안 B | 대안 Z |
|------|--------|--------|--------|
| 비용 | ... | ... | ... |
| 위험 | ... | ... | ... |
| 가역성 | ... | ... | ... |
| 학습 효과 | ... | ... | ... |

### 추천: 대안 A
[근거 + B 기각 이유]

### 다음 단계
- 저장됨: `.claude/memory/brainstorms/<file>.md`
- 권장: [/plan | /designer | 직접 구현]  ← HARD-GATE 등급 기반 자동 추천
```

## 다음 스킬과의 연계

| 변경 규모 (예상 파일 수) | 추천 다음 스킬 |
|----------------------|---------------|
| 1~5개 (HARD-GATE 인라인) | 직접 구현 — brainstorm spec을 인라인 설계로 사용 |
| 6~19개 (HARD-GATE 간략) | `/plan` — spec을 입력으로 단계별 계획 수립 |
| 20+개 (HARD-GATE 전체) | `planner` 에이전트 + `/plan` 필수 |
| UI 변경 포함 | `designer` 에이전트 (Phase 0가 자동 진행) |

## /plan 입력 호환 스펙

brainstorm 출력 spec 파일은 `/plan` 스킬의 **표준 입력**이 되도록 다음 마크다운 헤더 구조를 강제한다 (`/plan` 미구현 상태에서도 미리 호환성 확보):

```
# Brainstorm: <topic>           ← 제목 (H1)
## 의도                           ← 4문항 답변 (H2)
## 제약                           ← 3 카테고리 (H2)
## 대안 비교                      ← 표 또는 섹션 (H2)
## 추천 + 근거                    ← 선택 + B 기각 이유 (H2)
## 다음 단계                      ← 추천 후속 스킬 (H2)
```

`/plan`이 brainstorm spec을 읽을 때 사용할 파싱 계약:

| 헤더 | 파싱 결과 | /plan에서의 용도 |
|------|----------|-----------------|
| `## 의도` | `intent: { what, who, when, success }` | Plan의 "Goal" 섹션 |
| `## 제약` | `constraints: [tech, business, codebase]` | Plan의 "Out of Scope" 도출 |
| `## 추천 + 근거` | `chosen_approach: <대안 ID>` | Plan의 "Approach" 섹션 시작점 |
| `## 다음 단계` | `next_skills: ["plan", "designer"]` | Plan 단계 분해의 시드 |

**주의**: 위 헤더 구조를 임의로 바꾸지 않는다. 한국어로 옮길 때도 H2 텍스트는 정확히 유지(`## 의도`, `## 제약`, `## 대안 비교`, `## 추천 + 근거`, `## 다음 단계`).

## 메시지 버스 알림 (선택적)

기본 정책: **알림 안 함**. brainstorm 결과는 사용자가 다음 스킬(/plan, /designer 등)에서 명시적으로 사용. 다음 좁은 케이스에만 message-bus 발송:

| 조건 | 수신자 | type / priority |
|------|--------|----------------|
| 결과가 보안 재설계 (auth/RLS/secret 변경) 시사 | `security` | proposal / high |
| 결과가 디자인 토큰 신규 추가 시사 | `designer` | proposal / medium |
| 대안 도출 실패 (alternatives < 2) 반복 | `retrospective` | regression / medium |

```bash
bash .claude/hooks/message-bus.sh send brainstorm <to> proposal <priority> "..." "..."
```

## 규칙

- 사용자가 "그냥 만들어줘"라고 해도 4문항 자기검증은 생략하지 않는다 (필요 시 1~2개만 질문)
- 메모리에 이미 답이 있는 항목은 다시 묻지 않는다
- 대안 2개 + do-nothing 미달 시 brainstorm 실패로 보고하고 추가 탐색 요청
- 결과는 항상 파일로 저장 (다음 세션 인계 + retrospective 분석)
- 구현 결정이 brainstorm 추천과 달라지면 그 이유를 동일 파일에 추가 기록 (의사결정 추적)
- 시간 제한: 이상적 5분, 최대 10분. 초과 시 의도가 너무 큼 → /plan으로 분할 권장
- 작은 변경(스킵 가능 조건)에 강제로 호출하지 않는다 — 인지 비용이 변경 비용을 넘으면 비효율
