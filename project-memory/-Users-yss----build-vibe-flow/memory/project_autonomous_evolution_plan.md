---
name: project-autonomous-evolution-plan
description: 완전 자율 자기진화 하네스 7-PR plan (2026-07-24) — 다음 진입점 = T1/PR-0 rule 분리
metadata: 
  node_type: memory
  type: project
  originSessionId: 7575770d-0608-4f74-a9a4-6cef9cc38f2f
  modified: 2026-07-23T21:39:29.433Z
---

사용자 목표: 현 vibe-flow 하네스를 **완전 무인 자기진화**(자동 학습·문제수정·자기진화·자가업데이트 + **필요 스킬 자가 생성**)로. 2026-07-24 brainstorm→plan 완료.

**확정 결정 (사용자 명시 선택)**:
- 자율 경계 = **완전 무인 auto-merge 전체** (자기오염 리스크 수용 → auto-rollback+circuit breaker 필수)
- 케이던스 = **야간 cloud routine** (기존 R12 `trig_01RcUNYjHFh4t2k5UrKo75MB` KST 11:00 확장)
- 생성 트랙(스킬 자가생성) = **최상위 tier, 마지막 graduate** (eval+M밤 후). 승급순서 corrective저→구조→self-update→generative.

**설계 (대안 A — Guarded full-auto)**: 3 pillar = 불변 안전코어(denylist+PreToolUse guard) / post-merge auto-revert / circuit breaker(health regression 시 freeze). 핵심 불변식 = **pinned evaluator**(밤N이 밤N+1 감사로직 수정 불가). grow+prune 대칭(생성/은퇴).

**산출물**:
- brainstorm: `repo .claude/memory/brainstorms/20260723-212449-autonomous-self-evolution-closedloop.md`
- plan: `repo .claude/plans/20260724-063748-autonomous-self-evolution-closedloop.md` (7 step T1~T7 = PR-0~PR-6, HARD-GATE 전체)

**다음 세션 진입점 = T1 (PR-0)**: `donts.md`/`conventions.md`의 일반 discipline(Surgical/완료기준/합리화/컨텍스트보호)을 frontmatter無 `core/rules/discipline.md`로 분리 → 하네스 self-modify 시 상시로드. sync-drift.sh가 자동 glob(등록 불필요). 서브태스크 t0.1~t0.7은 plan 파일 T1 참조.

**부수 성과 — F-K03 REFUTED** (ledger resolve 반영): "규칙이 명예규칙(never loaded)"은 오진. 실제 = `.claude/rules/` 자동스캔 + **frontmatter path-scoping**(paths:src/** → 코드편집 시 조건로드, frontmatter無 → 글로벌 상시로드). "8중 4 로드"는 버그 아닌 설계. 제안 fix(CLAUDE.md @import 8)는 context-engineering 위반이라 기각. 잔여 실이슈(일반 discipline이 src/** 스코프에 묶여 하네스 self-work서 dormant)가 곧 PR-0. 관련 [[project_audit_20260601]] (F-K03은 R11/K 발), [[project_phase3_1_complete]] (R12 routine).
