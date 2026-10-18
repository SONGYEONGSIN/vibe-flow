---
name: claude-statusline-setup
description: "Claude Code 상태표시줄 커스텀 구성 — 스크립트 위치, 6줄 레이아웃, 이식용 원샷 프롬프트 파일"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 8663c3e0-e3f8-4707-b8fe-d36e611c12c4
---

Claude Code 상태표시줄(2026-07-13 구성):

- **스크립트**: `~/.claude/statusline.sh` (settings.json `statusLine`, refreshInterval 10초). 이전 버전 백업: `statusline.sh.bak`
- **레이아웃 6줄**: ①모델·effort·💡·git변경·env·output style ②전체경로·브랜치·세션비용 ③Context ④Usage 5H ⑤Usage 7D (③~⑤는 256색 그라데이션 바) ⑥plan 진행률·verify 결과(vibe-flow 데이터 있을 때만)
- **데이터**: statusline JSON의 `context_window`/`rate_limits`/`cost` + settings.json의 `effortLevel`/`alwaysThinkingEnabled`. `resets_at`은 epoch/ISO 둘 다 파싱, bash 3.2 호환
- **이식용 원샷 프롬프트**: `~/.claude/statusline-setup-prompt.md` — 다른 머신 Claude Code에 붙여넣으면 그대로 적용. `pbcopy < ~/.claude/statusline-setup-prompt.md`로 복사
- **주의**: statusline.sh 수정 시 프롬프트 파일 안의 사본은 자동 갱신 안 됨 — 재생성 요청 필요
