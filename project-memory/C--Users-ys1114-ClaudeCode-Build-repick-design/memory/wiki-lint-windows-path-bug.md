---
name: wiki-lint-windows-path-bug
description: "repick-design의 wiki-lint Windows 경로 오탐 버그 — PR #12(2026-07-24)에서 수정 완료. 이제 Windows에서도 정상 동작"
metadata: 
  node_type: memory
  type: project
  originSessionId: b8c3bb7d-b570-4cc1-a298-cf50cd5a2791
  modified: 2026-07-24T03:04:32.875Z
---

`scripts/wiki-lint.mjs`는 예전에 Windows에서 `unindexed` 45건 오탐을 냈다(경로 판별에 forward-slash 하드코딩 → `readVault`의 백슬래시 키와 안 맞음). **PR #12(2026-07-24, commit d071107)에서 수정 완료** — `lintVault` 진입부에서 키를 forward-slash로 정규화하고 red-green 회귀 테스트를 추가했다. 이제 `node scripts/wiki-lint.mjs`가 Windows에서도 broken/orphans/unindexed를 정확히 판정한다(정상 상태 = 0/0/0, exit 0).

**Why:** 예전 세션 노트가 "unindexed는 Windows 오탐이니 무시"라고 했을 수 있는데 그건 이제 틀렸다 — 오탐이 사라졌으므로 unindexed도 실제 위반 신호다.

**How to apply:** vault 변경 검증 시 `node scripts/wiki-lint.mjs`의 **broken·orphans·unindexed 셋 다 0**을 기대해도 된다. 테스트는 `npm test`로 실행(과거 작은따옴표 버그로 0개 나오던 것도 PR #12에서 쌍따옴표로 수정됨 → 45개 실행). 관련: [[repick-vault-architecture]]
