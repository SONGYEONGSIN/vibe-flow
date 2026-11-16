---
name: gh-pr-edit-broken
description: 이 저장소에서 gh pr edit 이 항상 실패하는 이유와 통하는 우회로
metadata: 
  node_type: memory
  type: project
  originSessionId: 525af7e5-2cde-4b87-be74-796546b2ccc9
  modified: 2026-08-09T09:26:23.617Z
---

`gh pr edit <n> --body-file ...` 은 SONGYEONGSIN/pantograph 에서 **항상 exit 1** 이다:

```
GraphQL: Projects (classic) is being deprecated ... (repository.pullRequest.projectCards)
```

`gh` 가 PR 을 조회할 때 GraphQL 쿼리에 `projectCards` 를 넣는데 GitHub 이 그 필드를 걷어냈다.
저장소 설정 문제가 아니라 `gh` 쪽 문제라 **재시도해도 소용없다.**

통하는 우회로 — REST 로 직접 PATCH:

```bash
gh api -X PATCH repos/SONGYEONGSIN/pantograph/pulls/<n> -F body=@<file>
```

`-F key=@file` 이 파일 내용을 값으로 읽는다 (`-f` 는 안 읽는다).
확인은 `gh api repos/.../pulls/<n> -q .body`.

`gh pr create`·`gh pr merge` 는 멀쩡하다. 깨지는 건 `edit` 뿐이다.
