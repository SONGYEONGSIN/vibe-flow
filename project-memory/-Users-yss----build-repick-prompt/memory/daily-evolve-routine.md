---
name: daily-evolve-routine
description: 매일 03:00 KST 클라우드 루틴이 prompt-evolve 1라운드를 자동 실행해 PR 생성 — 백로그는 vault/backlog.md
metadata: 
  node_type: memory
  type: project
  originSessionId: 8e423dd7-140d-4ae8-9f12-bb5e8fb09af7
---

repick-prompt는 2026-07-15부터 자동 자기진화 체제로 전환됨.

- GitHub 원격: https://github.com/SONGYEONGSIN/repick-prompt (private, 2026-07-14 최초 푸시)
- 클라우드 루틴: `prompt-evolve 일일 자동 라운드` (id `trig_01C7e66nxxHq8ELBMj5syCty`, cron `0 18 * * *` UTC = 매일 03:00 KST, 모델 claude-sonnet-5)
  - 관리: https://claude.ai/code/routines/trig_01C7e66nxxHq8ELBMj5syCty
- 동작: `vault/backlog.md` 대기열의 첫 미완료 항목을 타깃으로 `/prompt-evolve --auto` 1라운드 → `evolve/r<n>-<slug>` 브랜치 + PR 생성. main 직커밋 금지, 백로그 소진 시 no-op.
- 사람 게이트는 PR 리뷰로 대체됨 — DNA(prompt-principles.md) 변경분은 PR에서 검토 후 머지 (드리프트 방지).
- LEARN에 지식 정제 게이트 있음 (f0a4c2e): 새 규칙을 기존 DNA와 대조해 신규/강화/충돌/애매 4판정. 충돌·애매면 DNA 동결 + PR `## 지식 정제 질문`으로 사람에게 질문 — 답변의 판단 기준 자체를 다음 원칙으로 축적.
- 백로그 시드 10개 (2026-07-14 기준) — 소진 전에 새 타깃을 backlog.md 맨 아래에 추가해야 함.
