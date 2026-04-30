# learning-loop Extension

장기 데이터 분석 — 메트릭 추이 + 회고 + 개선안 도출.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/metrics [today\|week\|all]` | 빌드 성공률, 에러 빈도, 핫스팟 대시보드 |
| Skill | `/retrospective` | 메트릭+세션로그+events 분석 → P0/P1/P2 개선안 |

## 의존

- Core (events.jsonl, retrospective 에이전트, store.db)
- 외부 의존 없음

## 사용 시나리오

- 주간/격주 정기 회고
- 반복 에러 패턴 식별
- 스킬 자가 진화 트리거 (퇴보 감지 → /evolve 권장)
- 장기 trend (1개월+ 누적 후 가치)

## 설치

```bash
bash setup.sh --extensions learning-loop
```

> **권장**: meta-quality와 함께 활성화 — retrospective가 eval benchmark 분석 가능.
