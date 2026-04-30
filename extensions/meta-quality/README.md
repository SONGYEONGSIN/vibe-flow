# meta-quality Extension

스킬 자체 품질 측정 + 자가 진화. 메이커/상급자 도구.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/eval <skill>` | 스킬 evals 실행 → pass rate 측정 |
| Skill | `/evolve <skill>` | eval 결과 분석 → SKILL.md 개선 후보 + 5 게이트 + A/B 비교 |
| Agent | `skill-reviewer` | SKILL.md 8단계 검토 → 100점 스코어카드 |
| Agent | `grader` | eval 채점 (PASS/FAIL + 0.0~1.0) |

## 의존

- Core (events.jsonl, comparator 에이전트)
- 외부 의존 없음

## 사용 시나리오

- 메이커가 만든 스킬의 품질 정량화
- self-improving 루프 핵심 (Hermes Agent 패턴)
- 회고에서 스킬 퇴보 감지 시 evolve 후보 자동 생성

## 설치

```bash
bash setup.sh --extensions meta-quality
```
