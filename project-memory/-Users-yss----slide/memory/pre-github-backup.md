---
name: pre-github-backup
description: 2026-10-22부터 GitHub slide-studio 레포만 기준 — 이전 로컬 작업·규칙은 무시
metadata:
  node_type: memory
  type: project
  originSessionId: b93db18f-8d8f-4238-ab03-9d8d2dc50701
  modified: 2026-10-22T11:37:55.369Z
---

2026-10-22 /Users/yss/개발/slide 를 https://github.com/SONGYEONGSIN/slide-studio.git (main) 클론으로 교체했다.
사용자 지시: "기존 자료는 모두 무시하고 깃허브 기준으로만". 이전 로컬 작업(clean-pitch 템플릿, refs/ 규칙, ref-inbox 스킬, "Codex는 GPT-image 2.5로 그림만" 역할 규칙 등)은 적용·이관하지 않는다.
옛 파일은 /Users/yss/개발/slide-backup-20261022/ 에 남아 있다 (사용자가 요청할 때만 참고·삭제).

**Why:** GitHub 레포가 유일한 정본 프로젝트(Slide Studio v0.1, 포트 5173).
**How to apply:** 규칙·스킬·구조는 레포의 AGENTS.md / CLAUDE.md / .claude·.codex 스킬만 따른다. 백업 내용을 먼저 제안하지 않는다.
