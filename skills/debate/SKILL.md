---
name: debate
description: |
  Use when a topic needs multi-perspective expert analysis before making a decision.
  "토론해줘", "다각도 분석", "전문가 토론", "/debate", "찬반 검토", "여러 관점에서 봐줘",
  "장단점 비교", "의사결정 도와줘" 요청 시 사용.
  단일 관점으로는 판단이 어렵고, 다양한 전문가 시각에서 주제를 검토·토론해야 할 때 사용.
---

# Debate Skill — 전문가 토론 실행 프로토콜

동등한 전문가 에이전트들이 주제에 대해 토론하고, 수렴/합의를 도출한 뒤, 구조화된 종합 보고서를 생성합니다.

## 사용법

```
/debate <주제>
/debate --template <템플릿> <주제>
/debate --ref <debateId> <후속 주제>
```

## 설정

`~/.claude/skills/debate/protocol.json`에서 설정을 읽습니다:

| 설정 | 기본값 | 설명 |
|------|--------|------|
| maxRounds | 3 | 최대 라운드 수 (수렴 안 되면 여기서 종료) |
| hardLimitRounds | 5 | 절대 상한 라운드 |
| convergenceThreshold | 75 | 수렴 판단 점수 (0-100) |
| maxAgents | 5 | 최대 참여 에이전트 수 |
| debateStyle | "intense" | "intense" (날카로운 토론) 또는 "collaborative" (협력적) |

## 전체 실행 절차

### Step 1: 에이전트 발견 및 선택

1. `~/.claude/agents/*.md` 디렉토리의 모든 `.md` 파일을 읽습니다
2. 각 파일의 YAML frontmatter에서 `debate` 필드를 확인합니다:
   - `debate: false` → 토론 참여 제외
   - `debate.expertise: [키워드 배열]` → 주제 매칭에 사용
   - `debate.perspective: "관점 설명"` → 토론 시 역할 안내
3. 주제와 에이전트의 expertise 키워드 겹침으로 관련도를 점수화합니다
4. 상위 에이전트를 선택합니다 (최소 2명, 최대 maxAgents)
5. 관련도가 높은 에이전트가 2명 미만이면 사용자에게 알립니다

### Step 2: 라운드 실행 (병렬)

각 라운드에서 모든 선택된 에이전트를 **Task() 도구로 병렬 실행**합니다.

각 에이전트에게 전달할 프롬프트:

```
당신은 [{agent.perspective}] 전문가입니다.
자신의 전문 분야에서 확고한 입장을 가지고 토론에 참여하세요.

## 토론 주제
{topic}

## 라운드 {roundNumber} {초기 입장 or 반론}

{이전 라운드가 있으면: 이전 발언 내용}

## 규칙
- 코드베이스를 직접 읽어서 근거를 제시하세요
- intense: 약한 주장은 날카롭게 지적, 억지 양보 금지
- collaborative: 공통점 찾기, 종합적 해결책

## 응답 형식
1. 핵심 주장 (1-2문장)
2. 근거 (코드베이스 증거 또는 기술적 분석)
3. 다른 의견에 대한 반응 (라운드 1+: 동의/반박/수정)
4. 구체적 제안
```

**에이전트별 타임아웃**: 2분. 타임아웃 시 "(타임아웃으로 불참)" 처리.
**개별 실패 허용**: Promise.allSettled로 하나가 실패해도 나머지 진행.

### Step 3: 수렴 체크 (조정자)

각 라운드 후 조정자(Moderator)가 수렴도를 평가합니다:

```
전문가들의 토론을 분석하고:
1. 합의 포인트 나열
2. 분쟁 포인트 나열
3. 수렴 점수 0-100 평가
4. 권장: "continue" | "converged" | "force_stop"
```

- 수렴 점수 >= convergenceThreshold(75) → 종합 단계로
- maxRounds 도달 → 강제 종합
- 조정자 파싱 실패 → 1회 재시도 후 기본값 사용

### Step 4: 컨텍스트 압축 (다라운드 시)

3라운드 이상 진행 시 토큰 절약을 위해:
- **최근 2라운드**: 전문 전달
- **이전 라운드**: 조정자의 consensusPoints + activeDisputes 요약만 전달

### Step 5: 종합 생성

모든 라운드가 끝나면 종합 보고서를 생성합니다:

```json
{
  "summary": "전체 요약",
  "consensusPoints": ["합의1", "합의2"],
  "remainingDisputes": ["분쟁1"],
  "recommendedAction": "권장 행동",
  "minorityOpinions": ["소수 의견"],
  "implementationSteps": [
    {"file": "src/example.ts", "action": "modify", "description": "변경 설명"}
  ]
}
```

### Step 6: 결과 저장

`.debates/` 디렉토리에 마크다운 파일로 저장합니다:
- 파일명: `{debateId}_{topic_slug}.md`
- 내용: 주제, 참여자, 각 라운드 발언, 조정자 분석, 종합

### Step 7: 후속 액션

사용자에게 선택지 제공:
1. **구현 진행** — 종합의 implementationSteps를 기반으로 설계→구현→검증 파이프라인 실행
2. **추가 토론** — 이전 토론 결론을 컨텍스트로 새 토론 시작
3. **취소** — 토론 결과 폐기

## 토론 템플릿

미리 정의된 토론 유형을 사용할 수 있습니다:

| 템플릿 | 기본 참여자 | 설명 |
|--------|------------|------|
| architecture | api-architect, supabase-db-specialist, performance-optimizer | 아키텍처 설계 리뷰 |
| security | security-specialist, api-architect, supabase-db-specialist | 보안 감사 |
| feature | product-strategist, frontend-design-specialist, project-planner | 기능 기획 |
| performance | performance-optimizer, supabase-db-specialist, frontend-design-specialist | 성능 분석 |

사용: `/debate --template architecture "새 인증 시스템 설계"`

## 이전 토론 참조

`/debate --ref {debateId} "후속 논의 주제"`

이전 토론의 종합 결과(합의사항, 미해결 분쟁)를 새 토론의 컨텍스트에 포함합니다.

## 비용 추적

각 라운드 후 누적 비용을 표시하고, 종합에 총 비용을 포함합니다.

---

## Troubleshooting

| 문제 | 원인 | 해결 |
|------|------|------|
| 에이전트가 모두 동의 (에코 체임버) | 역할 차별화 부족 | Devil's Advocate 강제 배치 |
| 토론이 수렴하지 않음 | 근본적 가치관 차이 | 쟁점 분해 + 기준 재정립 |
| 첫 발언자에 편향 (앵커링) | 순차 발언 구조 | Round 1 독립 분석 후 동시 공개 |
| 비용 과다 | 모든 역할에 opus 사용 | 모더레이터만 opus, 토론자 sonnet |
| 결론이 실행 불가능 | 추상적 합의만 도출 | 최종 라운드에 Action Item 필수 |
| 라운드 초과 (5+) | 교착 상태 미탐지 | 교착 자동 탐지 + 강제 수렴 |

## Anti-patterns

| 패턴 | 문제 | 대안 |
|------|------|------|
| Groupthink | 갈등 회피로 비판 없음 | 반론 역할 강제 배치 |
| 권위 편향 | "시니어" 의견에 무조건 동의 | 익명 투표 라운드 추가 |
| 분석 마비 | 반복 토론만, 결론 없음 | 강제 수렴 라운드 + 다수결 |
| 허수아비 논증 | 상대 주장 왜곡 후 반박 | 반박 전 상대 주장 요약 의무 |
| 범위 확장 | 토론 주제 벗어남 | 모더레이터 범위 관리 |

## References

| 문서 | 경로 | 내용 |
|------|------|------|
| 토론 전략 | `references/debate-strategies.md` | 프레임워크, 역할 설계, 논거 구성, 템플릿 |
| 합의 패턴 | `references/consensus-patterns.md` | 합의 모델, 교착 해소, ADR, 품질 검증 |
