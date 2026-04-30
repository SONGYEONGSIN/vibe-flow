# code-feedback Extension

git diff 기반 변경 단위 품질 분석.

## 포함

| 종류 | 항목 | 설명 |
|------|------|------|
| Skill | `/feedback` | 최근 git diff 분석 → 코드 품질 점수 + 개선 제안 |

## 의존

- Core (feedback 에이전트는 core에 있음)
- 외부 의존: git

## 사용 시나리오

- PR 직전 자가 검토
- 작업 중간 점검 (큰 변경 후)
- review-pr / receive-review 와 함께 사용

## 설치

```bash
bash setup.sh --extensions code-feedback
```
