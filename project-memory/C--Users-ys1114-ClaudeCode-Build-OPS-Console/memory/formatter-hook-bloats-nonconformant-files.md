---
name: formatter-hook-bloats-nonconformant-files
description: "PostToolUse prettier hook reformats whole files that were committed prettier-non-conformant, bloating diffs"
metadata: 
  node_type: memory
  type: project
  originSessionId: d9101ff0-3022-4251-828f-56d57bfb1f20
---

이 repo의 PostToolUse 포매터 훅(prettier --write)은 Edit/Write 시 **파일 전체**를 재포맷한다. 그런데 일부 파일은 의도적으로 prettier 비준수 스타일로 커밋되어 있어(예: `src/features/auth/operators.ts`의 17명 인사 배열 single-line 정렬, `src/app/dashboard/_data/sidebar-helpers.ts`의 일부 single-line `if` 조건), 작은 헬퍼 하나만 추가해도 무관한 수백 줄이 재정렬되어 diff가 비대해진다 — surgical change 원칙 위반.

**Why:** 훅은 Edit/Write 도구 호출에만 트리거되고, prettier는 파일 전체를 대상으로 한다. 원본이 비준수면 전체가 바뀐다.

**How to apply:** 헬퍼/상수만 추가할 때는 (1) `git checkout main -- <file>`로 원본 복원 후 (2) **Bash + python으로 마커 앞에 텍스트 삽입**(Edit/Write 미사용 → 훅 미트리거)하여 기존 포맷 보존. 커밋 전 `git diff --cached --stat`로 추가 줄 수가 실제 변경분과 일치하는지 검증. [[ops-console-dev-workflow]]
