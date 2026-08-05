---
name: project_main_branch_protection
description: vibe-flow main 브랜치 보호 설정 내용과 그 안에 담긴 판단 (2026-08-05 적용)
metadata: 
  node_type: memory
  type: project
  originSessionId: 2c033ce9-f794-41c6-b8c1-dc1d418c0ce3
  modified: 2026-08-05T22:22:18.566Z
---

vibe-flow `main` 은 2026-08-05 부터 브랜치 보호가 걸려 있다 (감사 R17/R 의 F-R02, PR #184).

```
strict   = true
contexts = check | smoke (ubuntu-latest) | smoke (windows-latest)
enforce_admins = false
required_pull_request_reviews = null
```

**의도적으로 뺀 것들** (되돌리기 전에 이유를 알고 있어야 한다):
- `enforce_admins=false` — 1인 레포에서 소유자 긴급 우회 경로를 남긴다.
- reviews 미요구 — 자기 PR 을 자기가 승인 못 해 데드락이 된다.
- `notify-red` 는 required 에서 제외 — 정상 시 skip 되는 job 을 required 로 걸면 모든 green PR 이 영구 대기한다.

**전제**: 두 워크플로의 `pull_request` paths 필터를 전부 제거했기 때문에 required checks 가 성립한다 (PR #182). paths 필터를 되살리면 그 경로 밖 PR 이 영구 "Waiting for status" 로 막힌다 — 보호 설정과 paths 필터는 함께 움직여야 한다.

해제: `gh api -X DELETE repos/:owner/:repo/branches/main/protection`

관련: [[project_audit_20260601]]
