---
name: project-global-skills-dir-split
description: "2026-10-18 ~/.claude/skills 를 core/skills 통째 링크에서 실제 디렉토리+스킬별 링크로 분리, ~/.claude/rules 링크 제거"
metadata:
  node_type: memory
  type: project
  originSessionId: 32838b44-a706-426e-ba64-ee131d2b4f26
  modified: 2026-10-18T12:16:25.788Z
---

2026-10-18 `~/.claude/skills` 를 `vibe-flow/core/skills` 통째 심볼릭에서 **실제 디렉토리**로 바꿨다. vibe-flow tracked 스킬 45개는 `~/.claude/skills/<name> -> .../core/skills/<name>` 개별 링크, 외부 스킬(npx skills 설치 17개 링크·design-taste 등 실디렉토리·claude.ai `synced/`·`.trash/`)은 그 디렉토리로 이동. `~/.claude/rules` 링크는 삭제(F-R09 — 프로젝트 `.claude/rules` 와 이중 주입). `~/.claude/agents` 는 그대로.

**Why:** 통째 링크라 전역 스킬 설치가 전부 repo `core/skills/` 에 untracked 로 쌓였고, setup.sh 가 `synced` 를 `.claude/skills` 로 복사해 validate.sh 가 실패했다.

**How to apply:** core/skills 에 새 스킬을 추가하면 `~/.claude/skills/` 에 링크 1개를 직접 추가해야 전역 로드된다(setup.sh/MIGRATION.md 미반영 — 별도 PR 필요). rules 는 이제 setup.sh 가 설치한 프로젝트에서만 로드된다. 백업: 세션 scratchpad `backup/untracked-skills.tar`.
