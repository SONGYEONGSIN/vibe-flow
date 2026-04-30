# deep-collaboration Extension

Builder/Validator 페어 + 구조화된 토론. 다중 에이전트 협업 깊은 사용.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/pair "<task>"` | developer → validator 자동 루프 (최대 3 iter), 교착 시 moderator |
| Skill | `/discuss "<topic>"` | 에이전트 간 구조화된 토론 (Opening → Rebuttal → Verdict) |

## 의존

- Core (developer, validator, moderator 에이전트 + message-bus 훅)
- 외부 의존 없음

## 사용 시나리오

- 복잡한 기능 자가 검증 (단일 에이전트 confirmation bias 회피)
- 에이전트 간 의견 충돌 시 구조화된 합의 도출
- 토론 verdict이 retrospective 분석 입력

## 설치

```bash
bash setup.sh --extensions deep-collaboration
```
