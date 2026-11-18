---
name: delete-exact-names
description: 파일 삭제 시 넓은 glob 금지 — 정확한 파일명 + 삭제 전 목록 확인
metadata:
  node_type: memory
  type: feedback
  originSessionId: b93db18f-8d8f-4238-ab03-9d8d2dc50701
  modified: 2026-10-22T21:40:57.140Z
---

파일을 지울 때 `*ph*` 같은 넓은 패턴을 쓰지 않는다. 지울 파일 이름을 정확히 적고, 지우기 전에 목록을 먼저 출력해 확인한다.

**Why:** 2026-10-23 자리표시 정리 중 `*ph*`가 `phone`/`photo`에 걸려 커밋 전 Codex 검수 기록(qa.json) 5개를 지웠다. 사용자가 이 원칙에 동의함("알겠어").
**How to apply:** rm 전 `ls`로 대상 확인 → 정확한 경로로만 삭제. 특히 커밋 안 된 파일 근처에서는 더 조심.
