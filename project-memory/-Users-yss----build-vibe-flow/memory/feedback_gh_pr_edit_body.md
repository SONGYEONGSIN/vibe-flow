---
name: gh pr edit body — projects-classic GraphQL 우회
description: gh pr edit --body가 projects-classic GraphQL 에러로 실패할 때 REST API로 우회
type: feedback
originSessionId: 7779691f-257c-4310-930b-eb2ae234e397
---
`gh pr edit N --body "..."`가 다음 에러로 실패할 수 있음:

```
GraphQL: Projects (classic) is being deprecated...
(repository.pullRequest.projectCards)
```

**Why:** gh CLI의 `pr edit`이 내부적으로 GraphQL 호출 시 deprecated된 projects-classic 필드를 같이 fetch하는데, 해당 repo에서 이게 막혀 422 발생.

**How to apply:** REST API로 직접 PATCH:

```bash
gh api -X PATCH /repos/{OWNER}/{REPO}/pulls/{N} -f body="$BODY" --jq '.html_url'
```

vibe-flow / vibe-flow-dashboard 둘 다 이 증상 발생. PR body 갱신은 항상 REST API 경로로 가는 게 안전.
