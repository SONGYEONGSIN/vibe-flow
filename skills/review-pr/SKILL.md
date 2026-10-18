---
name: review-pr
description: GitHub PR을 코드 리뷰한다. 코드 품질, 보안, 테스트 커버리지를 점검한다. 사용법: /review-pr [pr-number]
effort: high
---

GitHub PR #$ARGUMENTS 를 코드 리뷰한다.

## PR 정보

- 요약: !`gh pr view $0 --json title,body,additions,deletions,changedFiles --jq '"[\(.changedFiles) files, +\(.additions)/-\(.deletions)] \(.title)"' 2>/dev/null || echo "(PR 번호를 확인하세요)"`
- 변경 파일: !`gh pr diff $0 --name-only 2>/dev/null | head -20`

## 절차

1. 위 PR 정보와 `gh pr diff $ARGUMENTS` 전체 diff를 확인
3. **feedback** 에이전트로 코드 품질 분석 실행
4. **security** 에이전트로 보안 취약점 점검 실행
5. 결과를 종합하여 리뷰 리포트 출력

## 리뷰 기준

### 코드 품질

- 프로젝트 패턴(Server Action, zod, revalidatePath) 준수
- 함수/파일 크기 제한 준수
- `any` 타입, `console.log` 사용 여부

### 보안

- 인증/인가 확인
- 입력 검증 여부
- 시크릿 노출 여부

### 테스트

- 새 기능에 대한 테스트 존재 여부
- 기존 테스트 깨짐 여부

## 출력 형식

```markdown
## PR #N 리뷰 결과

### 요약

[1-2문장 요약]

### 코드 품질: X/10

[상세 피드백]

### 보안: PASS/WARN

[상세 피드백]

### 테스트: PASS/WARN

[상세 피드백]

### 종합 의견

[승인/수정 요청/논의 필요]
```

## events.jsonl 기록

리뷰 완료 후 기록 (`/finish path=pr` 후 같은 세션 follow-through 추적):
```bash
echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"type\":\"review_pr\",\"pr\":$PR_NUMBER,\"score\":$SCORE,\"verdict\":\"$VERDICT\"}" >> .claude/events.jsonl
```

`verdict`: `approve` | `request_changes` | `discuss`
