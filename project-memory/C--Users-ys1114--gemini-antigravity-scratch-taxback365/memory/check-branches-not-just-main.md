---
name: check-branches-not-just-main
description: 프로젝트 진행 상황 파악 시 main만 보지 말고 브랜치·worktree까지 확인
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5bb7497e-32f7-4929-8233-ea64ee773929
---

"어디까지 작업됐지?" 류의 상태 파악 요청에서, main과 plan frontmatter만 보고 "디자인 리브랜드 미착수"라 오진했다. 실제로는 완성된 작업이 `feat/redesign` 브랜치(+ `../taxback365-feat-redesign` worktree)에 있었고 main에 미머지였을 뿐이다. Phase 0~3를 처음부터 새로 만들기 직전에 브랜치 충돌로 발견해 멈췄다.

**Why:** 이 프로젝트는 대규모 작업을 worktree/feature 브랜치에 격리(`.claude/rules/git.md`의 Git Worktree 정책)하고 plan frontmatter의 status는 최신 커밋과 자주 어긋난다. main 단일 뷰는 실제 진행도를 반영하지 못한다.

**How to apply:** 상태 파악 시 `git branch -a`, `git worktree list`, 각 브랜치의 `git log main..<branch>`를 먼저 확인. plan status 프론트매터는 신뢰하지 말고 git 히스토리 + 실제 파일 내용(예: globals.css 토큰)으로 교차검증.
