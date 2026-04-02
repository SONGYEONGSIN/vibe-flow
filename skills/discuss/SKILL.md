---
name: discuss
description: 에이전트 간 구조화된 토론을 개시하여 기술적 의견 차이를 해결한다. 사용법: /discuss <topic> [--agents agent1,agent2,...] [--rounds N]
---

에이전트 간 토론을 개시하고, moderator가 중재하여 합의를 도출한다.

## 사용법

```bash
/discuss "Server Action 인증 패턴"                     # 자동 참가자 선정
/discuss "테스트 전략" --agents qa,developer,feedback   # 참가자 지정
/discuss "성능 vs 가독성" --rounds 2                    # 라운드 수 제한
```

## 절차

### 1. 주제 분석 및 참가자 선정

`$ARGUMENTS`에서 주제와 옵션 파싱.

`--agents`가 없으면 주제 키워드로 자동 선정:

| 키워드 | 기본 참가자 |
|--------|------------|
| 보안, 인증, 취약점 | security, developer |
| 테스트, 커버리지, E2E | qa, developer |
| 성능, 최적화 | feedback, developer |
| 설계, 아키텍처, 구조 | planner, developer, designer |
| 코드 품질, 리팩토링 | feedback, developer |
| UI, 디자인, 스타일 | designer, developer |

### 2. 토론 파일 생성

토론 ID 생성 후 두 파일 작성:

**메타데이터** — `.claude/messages/debates/debate-<id>.json`:
```json
{
  "id": "debate-<id>",
  "created_at": "<timestamp>",
  "trigger": { "type": "user", "source": "/discuss", "detail": "<topic>" },
  "topic": "<topic>",
  "participants": ["<agent1>", "<agent2>"],
  "moderator": "moderator",
  "status": "in_progress",
  "max_rounds": 3,
  "current_round": 0,
  "rounds": [],
  "verdict": null
}
```

**트랜스크립트** — `.claude/messages/debates/debate-<id>.md`:
```markdown
# Debate: <topic>

**참가자**: agent1, agent2
**모더레이터**: moderator
**상태**: in_progress
```

### 3. 참가자 초대

```bash
for agent in $PARTICIPANTS; do
  bash .claude/hooks/message-bus.sh send moderator "$agent" debate-invite high \
    "토론 초대: $TOPIC" \
    "토론에 참여해 주세요. 토론 파일: .claude/messages/debates/debate-<id>.md"
done
```

### 4. Opening Statements 수집 (Round 0)

**moderator** 에이전트 위임으로 각 참가자의 opening statement 수집.

각 참가자에게 요청:
- **입장** (position): 한 문장 요약
- **논거** (argument): 근거 있는 설명
- **근거** (evidence): 코드, 문서, 규칙 참조
- **확신도** (confidence): 0.0~1.0

Agent 도구로 각 참가자 역할을 순차 실행하되, 해당 에이전트의 `.md` 시스템 프롬프트를 컨텍스트로 제공한다.

### 5. Rebuttal 라운드 (Round 1~N)

각 라운드마다:
1. moderator가 이전 라운드의 모든 발언 요약
2. 각 참가자에게 반박 요청
3. 합의 판단 기준 확인:
   - 전원 동일 입장 → `consensus`
   - 한 쪽 confidence > 0.8, 반대 < 0.5 → `strong_majority`
   - 3라운드 초과 → `moderator_decision`
   - 전원 confidence < 0.5 → `needs_human_input`

### 6. Verdict (판정)

moderator가 최종 판정:
1. debate JSON의 `verdict` 필드 작성
2. debate MD에 판정 섹션 추가
3. 전 참가자에게 `debate-verdict` 메시지 전송
4. `.claude/memory/improvements.md`에 토론 결과 기록
5. 새 패턴 발견 시 `.claude/memory/patterns.md` 업데이트

### 7. 결과 출력

최종 결과를 아래 형식으로 출력:

```markdown
## 토론 결과 — [주제]

### 참가자
- [agent1] (입장: [position])
- [agent2] (입장: [position])

### 진행 요약
- Round 0: [Opening 요약]
- Round 1: [Rebuttal 요약]

### 판정
**결정**: [선택된 입장]
**유형**: [consensus / strong_majority / moderator_decision / needs_human_input]
**근거**: [2-3문장]

### 실행 항목
| 담당 | 작업 | 대상 |
|------|------|------|

### 메모리 업데이트
- [추가된 내용]
```

## 규칙

- 최소 2명, 최대 4명 참가
- 최대 3라운드 (`--rounds`로 줄일 수 있으나 늘릴 수 없음)
- 토론 중 코드 변경 금지 — 방향 결정만 수행
- 판정 후 action_items 실행은 해당 에이전트가 별도 수행
- 토론 기록은 `.claude/messages/debates/`에 영구 보관
- `needs_human_input` 판정 시 사용자에게 핵심 쟁점을 명확히 제시
