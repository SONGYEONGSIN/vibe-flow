---
name: evolve
effort: high
description: 스킬 자동 개선 — eval 결과와 실패 트레이스를 분석하여 SKILL.md 개선 후보를 생성하고 A/B 비교로 검증한다. /evolve <skill-name>
---

Hermes Agent self-evolution 패턴 적용. 스킬의 eval 결과를 분석하여 개선 후보를 생성하고, 5개 제약 게이트를 통과해야만 적용을 제안한다.

## 사용법

- `/evolve commit` — commit 스킬 자동 개선
- `/evolve verify` — verify 스킬 자동 개선
- `/evolve <skill-name>` — 지정 스킬 자동 개선

## 절차

### 1. 현재 상태 평가 (Baseline)

`$ARGUMENTS`에서 스킬 이름 파싱 후:

1. `.claude/skills/$ARGUMENTS/SKILL.md` 파일 존재 확인
   - 없으면 "스킬이 존재하지 않습니다: $ARGUMENTS" 안내 후 종료
2. `.claude/skills/$ARGUMENTS/evals/evals.json` 존재 확인
   - 없으면 "eval 미설정. `/eval` 먼저 구성하세요" 안내 후 종료
3. 기존 벤치마크 확인: `.claude/skills/$ARGUMENTS/evals/benchmark.json`
   - 있으면 로드 (이전 실행 결과로 활용)
   - 없으면 Agent 도구를 사용하여 `/eval $ARGUMENTS` 실행하여 baseline 생성
4. baseline pass rate와 실패 항목 기록

### 2. 실패 트레이스 분석

baseline에서 FAIL 항목만 추출:

각 실패 항목에 대해:
- **eval 프롬프트 분석** — 어떤 시나리오에서 실패하는지 파악
- **기대 결과 분석** — 어떤 기준(expectations)을 불충족하는지 파악
- **reasoning 분석** — 왜 실패했는지 근본 원인 추론

에러 분류 데이터 활용 (error_classifier 연동):
```bash
node .claude/scripts/store.js query error-classes 7
```
- 반복적인 에러 패턴이 있으면 스킬 개선에 반영

### 3. 개선 후보 생성

분석 결과를 바탕으로 SKILL.md 개선 후보를 생성한다.

개선 전략 (우선순위 순):
1. **명확화** — 모호한 지시를 구체적으로 변경
2. **예외 처리 추가** — 실패 시나리오에 대한 절차 추가
3. **규칙 강화** — 위반 패턴을 규칙 섹션에 추가
4. **예시 보강** — 실패 케이스의 올바른 처리 예시 추가

후보를 `.claude/skills/$ARGUMENTS/evals/candidate-SKILL.md`에 임시 저장한다.

**중요**: 전면 재작성 금지. 실패 패턴에 집중하여 최소한의 변경만 적용.

### 4. 제약 게이트 (5개 모두 통과해야 진행)

| # | 게이트 | 기준 | 검증 방법 |
|---|--------|------|-----------|
| 1 | 크기 제한 | ≤15KB | `wc -c candidate-SKILL.md` |
| 2 | 목적 보존 | 원래 name/description 유지 | YAML frontmatter 비교 |
| 3 | 구조 보존 | 주요 `## ` 섹션 헤더 유지 | 원본과 후보의 `## ` 라인 비교 |
| 4 | 구문 유효 | YAML frontmatter 파싱 가능 | `---` 구분자 존재 확인 |
| 5 | Eval 통과 | pass rate ≥ baseline | 후보로 eval 재실행 |

#### 게이트 5 실행 절차:

1. 원본 SKILL.md 백업: `cp SKILL.md SKILL.md.backup`
2. 후보 적용: `cp candidate-SKILL.md SKILL.md`
3. Agent 도구로 `/eval $ARGUMENTS` 재실행
4. 원본 복원: `cp SKILL.md.backup SKILL.md`
5. 후보 pass rate와 baseline pass rate 비교

하나라도 실패하면:
- 실패 게이트와 이유 보고
- 후보 파일 삭제
- "개선 실패: [게이트명] 미통과" 출력 후 종료

### 5. A/B 블라인드 비교

모든 게이트 통과 시 `comparator` 에이전트로 블라인드 비교:

```
Agent 도구 호출:
  subagent_type: "general-purpose"
  description: "Evolve A/B comparison"
  prompt: """
  너는 comparator 에이전트다. .claude/agents/comparator.md의 블라인드 프로토콜을 따른다.

  두 SKILL.md를 비교한다:

  context: "$ARGUMENTS 스킬의 eval 기반 자동 개선"
  output_a: <원본 SKILL.md 내용>
  output_b: <후보 SKILL.md 내용>
  criteria: ["completeness", "clarity", "actionability", "conciseness"]

  eval 결과도 함께 고려:
  - 원본 pass rate: {baseline_pass_rate}%
  - 후보 pass rate: {candidate_pass_rate}%

  블라인드 비교 후 승자를 판정하라.
  """
```

### 6. 결과 보고

#### 개선 성공 시 (후보 승리 + pass rate 향상)

```markdown
## Evolve 결과: $ARGUMENTS

**판정**: 개선됨 ✓
**Pass Rate**: {baseline}% → {candidate}%
**A/B 비교**: {comparator 결과 요약}

### 변경 사항
{diff 요약 — 주요 변경점 3개 이내}

### 적용 방법
후보 파일: `.claude/skills/$ARGUMENTS/evals/candidate-SKILL.md`

적용하려면:
  cp .claude/skills/$ARGUMENTS/evals/candidate-SKILL.md .claude/skills/$ARGUMENTS/SKILL.md
```

#### 개선 실패 시 (원본 우세 또는 pass rate 동등)

```markdown
## Evolve 결과: $ARGUMENTS

**판정**: 개선 불필요 또는 실패
**Pass Rate**: {baseline}% → {candidate}%
**이유**: {왜 개선되지 않았는지 분석}

### 분석
- 실패 패턴: {분석 요약}
- 권장 사항: {수동 개선이 필요한 영역}
```

### 7. 이력 기록

결과를 `.claude/skills/$ARGUMENTS/evals/evolve-history.json`에 append:

```json
{
  "timestamp": "2026-04-16T...",
  "baseline_pass_rate": 75.0,
  "candidate_pass_rate": 87.5,
  "gates_passed": 5,
  "comparator_verdict": "Beta (candidate) wins",
  "applied": false
}
```

events.jsonl에도 기록:
```bash
echo '{"ts":"...","type":"skill_evolve","skill":"$ARGUMENTS","baseline":75.0,"candidate":87.5,"improved":true}' >> .claude/events.jsonl
```

evolve-history.json은 최대 20개 엔트리 유지 (오래된 것 자동 삭제).

## 규칙

- 후보를 자동 적용하지 않음 — 항상 사용자에게 diff를 보여주고 수동 적용 선택
- 원본 SKILL.md는 절대 손상되지 않아야 함 (백업 + 복원 패턴)
- 한 번의 evolve에서 변경하는 내용은 실패 패턴에 집중 (전면 재작성 금지)
- eval이 없는 스킬에는 동작하지 않음 (측정 없이 개선 없음)
- evolve-history.json은 최대 20개 엔트리 유지 (오래된 것 자동 삭제)
- baseline pass rate가 100%이면 "개선 불필요" 보고 후 조기 종료
