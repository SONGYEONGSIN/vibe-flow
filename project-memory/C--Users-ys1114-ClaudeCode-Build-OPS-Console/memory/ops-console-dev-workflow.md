---
name: ops-console-dev-workflow
description: 사용자가 선호하는 변경 반영 워크플로우 — TDD + 브랜치/PR/squash 머지 + 라이브 검증
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d9101ff0-3022-4251-828f-56d57bfb1f20
---

OPS-Console 작업 시 사용자가 선호하는 흐름:
- 작은 버그/기능도 **TDD**(RED→GREEN)로 진행하고, 변경 후 typecheck/eslint/vitest 증거를 보고한다.
- main에서 직접 커밋하지 않고 **작업 브랜치 → PR → squash merge**(`gh pr merge <#> --squash --delete-branch`). PR 제목은 conventional 형식(한국어 본문).
- 머지는 production(Vercel) 배포로 직결되므로 **사용자 확인 후** 머지. 사용자는 보통 라이브 URL(ops-console-psi.vercel.app)에서 직접 검증한다 — 배포 미반영을 "버그"로 오인할 수 있으니 머지/배포 단계를 항상 명확히 안내.

**Why:** 사용자가 매번 "지금 머지할까요? 네" 패턴으로 명시 승인했고, 라이브에서 확인하는 습관이 있다.

**How to apply:** 변경 완료 → 검증 증거 제시 → PR 생성 후 머지 여부 질의. DB 스키마 변경 PR은 [[supabase-migration-apply-before-merge]] 순서 준수.
