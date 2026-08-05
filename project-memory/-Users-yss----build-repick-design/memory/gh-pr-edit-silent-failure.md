---
name: gh-pr-edit-silent-failure
description: 이 저장소에서 gh pr edit이 Projects-classic GraphQL 에러로 조용히 실패 — REST PATCH로 우회해야 한다
metadata: 
  node_type: memory
  type: project
  originSessionId: 6d405365-68f4-4f3b-8097-ea5407c0697b
  modified: 2026-07-30T12:12:05.956Z
---

`gh pr edit <num> --title … --body-file …`이 이 저장소(SONGYEONGSIN/repick-design)에서 실패한다:

```
GraphQL: Projects (classic) is being deprecated … (repository.pullRequest.projectCards)
```

**Why:** gh가 edit mutation과 함께 `repository.pullRequest.projectCards`를 조회하는데, Projects classic sunset으로 그 필드가 에러를 내면서 **mutation 전체가 중단**된다. 에러 문구가 Projects 얘기만 하므로 "경고인데 편집은 됐겠지"로 오독하기 쉽지만 실제로는 title·body·updatedAt 전부 그대로다 — 조용한 no-op.

**How to apply:** `gh pr edit` 대신 REST PATCH를 쓴다. 본문에 백틱·따옴표·개행이 많으므로 JSON을 만들어 stdin으로 넘긴다:

```bash
node -e 'const fs=require("fs");process.stdout.write(JSON.stringify({title:"…",body:fs.readFileSync(process.argv[1],"utf8")}))' body.md \
  | gh api --method PATCH repos/SONGYEONGSIN/repick-design/pulls/<num> --input -
```

그리고 편집 후 `gh pr view <num> --json title,updatedAt,body` 로 **반영을 반드시 확인**한다. [[specimen-gallery-redesign]]의 `/dash-falsify open` 루틴이 매 주간 이 경로를 타므로 재발한다.

또한 이 저장소는 **PRIVATE**이라 PR 본문의 `github.com/…/blob/evolve/dash/…` 링크를 비인증 curl로 검증하면 존재하는 경로도 404가 된다 — 링크 실존 검증은 `gh api "repos/…/contents/<path>?ref=evolve/dash"` 로 해야 한다.
