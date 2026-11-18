---
name: stacked PR squash 머지 시 --delete-branch 주의
description: 스택된 PR을 squash merge할 때 --delete-branch 옵션이 후속 PR을 자동 close시키므로 의존 chain 확인 후 사용
type: feedback
originSessionId: 7779691f-257c-4310-930b-eb2ae234e397
---
stacked PR (각 PR base가 이전 PR head)에서 squash merge에 `--delete-branch` 사용 시, 후속 PR은 base 브랜치 사라져서 자동 CLOSED 된다 (reopen GraphQL 거부됨, 콘텐츠는 head 브랜치에 살아있어 새 PR로 재생성 필요).

**Why:** vibe-flow-dashboard에서 #2→#3→#4→#5→#6 5-deep stack 머지 시도. #2를 `--delete-branch`로 머지하니 #3이 자동 close. 결국 #3, #5를 새 PR로 재생성해야 했음. 단순 retarget도 squash로 SHA 바뀌어 후속 브랜치 rebase 충돌 → 진정 sequential (한 cycle씩 완료) 만이 동작함.

**How to apply:**
- stack 머지 시 마지막 PR을 제외하고는 `--delete-branch` 빼고 머지 (`gh pr merge N --squash`)
- 각 cycle: (1) 이전 PR 머지로 main 업데이트 → (2) 다음 브랜치 `git rebase --onto main <원래base SHA> <branch>` → (3) force-push → (4) `gh api -X PATCH /repos/{O}/{R}/pulls/{n} -f base=main` 으로 retarget → (5) merge
- 원래 base SHA는 `gh pr view N --json baseRefOid`로 확보 (PR이 close 되기 전에 미리)
- vibe-flow-dashboard는 stacked PR 패턴 자주 사용 — 이 시나리오 반복 가능
