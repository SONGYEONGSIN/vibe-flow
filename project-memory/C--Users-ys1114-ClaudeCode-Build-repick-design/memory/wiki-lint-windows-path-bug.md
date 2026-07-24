---
name: wiki-lint-windows-path-bug
description: repick-design의 scripts/wiki-lint.mjs는 Windows에서 unindexed 오탐 45건을 낸다 — vault 변경 검증 시 broken/orphans로만 판단
metadata: 
  node_type: memory
  type: project
  originSessionId: b8c3bb7d-b570-4cc1-a298-cf50cd5a2791
  modified: 2026-07-24T00:51:24.397Z
---

`scripts/wiki-lint.mjs`는 경로 판별에 forward-slash를 하드코딩(`p.startsWith('00-principles/')`, `p.includes('/')`)해서, Windows에서 `path.join`이 백슬래시(`\`)를 쓰면 검사가 전부 빗나간다. 결과: **모든 파일이 root 노트로 취급 → 10-references 45건이 통째로 `unindexed` 오탐**으로 뜬다(작성자 CI는 Linux/Mac이라 정상 통과).

**Why:** 이 Windows 머신에서 `node scripts/wiki-lint.mjs`를 돌리면 exit 1 + unindexed 45가 baseline이다. 이걸 회귀로 오인하면 시간 낭비.

**How to apply:** vault(마크다운 노트) 변경을 검증할 땐 `unindexed` 절대값이 아니라 **`broken`/`orphans`가 `[]`인지**, 그리고 내가 추가한 항목이 `unindexed`에 **새로** 늘지 않는지(delta)로 판단한다. 새 노트는 인바운드 링크(비-index) 1개 + `vault/index.md` 등재를 갖추면 Windows에서도 안전. 이 버그 자체는 surgical 원칙상 요청 없이 안 고침. 관련: [[repick-vault-architecture]]
