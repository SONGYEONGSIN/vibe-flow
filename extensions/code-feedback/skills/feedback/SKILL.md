---
name: feedback
effort: high
description: 최근 변경사항에 대한 코드 품질 분석과 개선 제안을 출력한다
---

최근 변경사항의 코드 품질을 분석하고 개선 제안을 출력한다.

## 절차

1. `git diff HEAD~1` 또는 `git diff` 로 최근 변경사항 확인
2. 변경된 파일 목록 수집
3. **feedback** 에이전트를 호출하여 품질 분석 실행
4. 결과를 우선순위별로 정리하여 출력

## 분석 기준

### 코드 품질

- 함수 크기 (50줄 이하)
- 파일 크기 (400줄 권장)
- Nesting 깊이 (4단계 이하)
- Immutability 준수

### 패턴 준수

- Server Action 패턴
- 1파일 1컴포넌트
- barrel export

### 금지 사항

- `console.log`
- `any` 타입
- 하드코딩 시크릿

### 성능

- 불필요한 리렌더링
- 메모이제이션 여부

## 출력 형식

```markdown
## 코드 품질 피드백

### 점수: X/10

| 우선순위 | 카테고리 | 파일 | 문제 | 개선 제안 |
| -------- | -------- | ---- | ---- | --------- |

### 잘한 점

- ...

### 개선 필요

- ...
```

## events.jsonl 기록

분석 완료 후 기록:
```bash
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"feedback\",\"score\":$SCORE,\"items\":$ITEMS,\"files\":$FILES}" >> .claude/events.jsonl
```
