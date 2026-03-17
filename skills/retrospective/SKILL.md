---
name: retrospective
description: 메트릭과 세션 로그를 분석하여 프로젝트 개선안을 도출한다
---

프로젝트 이력을 종합 분석하여 에이전트/스킬/규칙 개선안을 도출한다.

## 절차

1. **retrospective** 에이전트를 호출하여 전체 분석 실행
2. 에이전트가 다음 데이터를 수집·분석:
   - `.claude/metrics/daily-*.json` — 훅 실행 메트릭
   - `.claude/session-logs/*.md` — 세션 기록
   - `git log` — 커밋 이력
   - `.claude/memory/improvements.md` — 이전 회고 결과
3. 정량 지표 + 패턴 식별 + 구체적 개선안 도출
4. eval 벤치마크(`.claude/skills/*/evals/benchmark.json`) 분석 (있는 경우)
5. 스킬 변경 제안 시 **skill-reviewer** 에이전트로 품질 게이트 검증 (70점 미만 → 재조정)
6. `.claude/memory/`에 학습 결과 기록

## 사용 시점

- 기능 개발 완료 후
- 주간/격주 정기 회고
- 반복적인 에러가 감지될 때
- `/metrics`에서 이상 지표가 보일 때

## 출력 예시

```markdown
## 회고 보고서 — 2026-03-16

### 정량 지표

| 지표 | 값 | 이전 대비 |
|------|------|----------|
| 빌드 성공률 | 82% | +5% |

### 개선안

| 우선순위 | 카테고리 | 대상 | 제안 |
|---------|---------|------|------|
| P0 | 규칙 | rules/conventions.md | auth 패턴 섹션 추가 |
| P1 | 에이전트 | agents/developer.md | RLS 체크 항목 보강 |

### 메모리 업데이트
- patterns.md: 2개 패턴 추가
- improvements.md: 이번 회고 기록
```
