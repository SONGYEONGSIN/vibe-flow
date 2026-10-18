---
name: phase3-1-r4-remote-vs-local-architecture
description: "PR-C1 R4 dogfooding(2026-05-23) 발견 — schedule 스킬은 cloud remote agent, local 파일/cron 가정과 incompatible. PR-C1 firings.jsonl 설계 무효"
metadata: 
  node_type: memory
  type: project
  originSessionId: 63a7469a-8f4e-4fc3-9ea5-0ba9e8046875
---

PR-C1 (PR #67, merged) R4 dogfooding cycle 8에서 schedule 스킬 호출 시 발견된 architectural 불일치. **Phase 3.1 cron 통합 설계 가정이 cloud remote agent와 충돌**.

**Why**: Phase 3.1 brainstorm(2026-05-12)은 schedule을 "local cron trigger"로 가정. 실 dogfooding 결과 schedule = "Anthropic cloud remote agent"로 모델 완전 다름.

**How to apply**: 
- PR-C1.1 재설계 시 다음 4 제약 반영:
  1. **cron 최소 간격 1시간** — `*/30 * * * *` 거부. schedule-register.sh cron validation에 명시
  2. **Remote agent cloud 실행** — local 파일 직접 접근 0. `bash /Users/yss/...` 호출 형태 무효. git clone 기반 prompt 필요
  3. **routine = prompt, not bash** — `events[].data.message.content`에 자연어. shell command 직접 입력 불가
  4. **firings.jsonl architectural 무효** — remote agent는 ephemeral git checkout. user local memory 도달 X. cap은 schedule level(cron freq)로 강제, run-queue level firings 카운트는 local manual 호출 한정
- run-queue.sh의 firings cap은 **local manual mode 한정**으로 의미 재정의 (cloud cron은 cron freq가 자동 cap)
- 짝 cycle (`depends_on`) 표현은 PR-merge polling 필요 → 별 remote agent로 polling 사이클 분리
- PR-C1은 cron validation + DRYRUN echo helper로서는 유효 (재사용 가능). 단 실 trigger 경로는 PR-C1.1에서 재설계

**관련 PR/spec**:
- PR #67 (PR-C1, merged) — schedule-register.sh 1차 시도
- `.claude/memory/brainstorms/20260512-202958-vibe-flow-phase3-cron-scheduler.md` — 상위 brainstorm (R4 가정 부정확)
- `.claude/memory/brainstorms/20260523-084409-vibe-flow-phase3-1-pr-c-schedule.md` — PR-C1 brainstorm (3 sub-PR 분할)

**Linked memories**:
- [[auto-build-anytime-도구]] — schedule 통합 가치 명시 (architectural 변경에도 anytime 원칙 유지)
- [[auto-build-운영-한계-phase-2-머지-후]] — "Phase 3 cron 전까지 session alive 필수" 해소가 PR-C1의 핵심 motivation

**다음 진입점**: PR-C1.1 brainstorm — schedule = remote agent 모델 재설계
