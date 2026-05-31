# vibe-flow Project Memory

> **2계층 메모리 분리 정책**:
> - **project-level (이 파일)** — repo 자체 메모. 다른 사용자/협업자도 봐야 할 정보. git tracked.
> - **user-level** (`~/.claude/projects/-Users-yss----build-vibe-flow/memory/MEMORY.md`) — 본인 작업 흐름, 개인 결정, session-specific. git untracked.
>
> 200줄 cap. 인덱스만 작성, 상세는 leaf 파일에 분리 (Karpathy §5 leaves 원칙).

## Active Phase

**Phase 3.1 부분 종료 (2026-05-25)** — cloud-native cron-triggered auto-build cycle 본 목표 달성. R8~R11 4 dogfooding functional PASS. F16/F17은 Phase 4로 이월.

**Phase 4 (진행 중)**:
- F16 (cloud hook wire 메커니즘) PR #79 fix → R12 검증 미해소 (cloud cycle 진입 실패, root cause 미확정)
- F14/F15 코드는 OK이지만 cloud-side wire 안 됨 → too-late wire 가설
- F17 (orchestrator markdown 강제력) 미진행

## Active Findings (audit 2026-06-01)

vibe-flow 내부 감사 D1/D2/D3 결과 — 21 finding 발굴. 상세는 `.claude/memory/audits/20260601-internal-audit.md` 참조 (작성 예정).

핵심 패러독스: **mechanical enforcement 시스템인데 본인이 enforcement를 안 받음** (44 skill 중 38 사용 0회, 22 agent 전체 0회).

P0 진행 중:
- F-A1 — 본 MEMORY.md 생성 (해소)
- F-A2 — performance-checker tee 제거
- F-B1 — security 도메인 라우팅 정리
- F-D1 — 3 script (cloud-init/persona-vote/run-log) smoke test 추가

## Brainstorm 인덱스 (최근)

cloud cycle 관련 (Phase 3.1/4):
- `brainstorms/20260523-092812-vibe-flow-phase3-1-cloud-native-redesign.md` — Phase 3.1 Path A 채택
- `brainstorms/20260525-094106-vibe-flow-phase3-1-r10-task-selection.md` — R10 task 선정
- `brainstorms/20260526-012144-f16-cloud-hook-wire-mechanism.md` — F16 4 대안 비교, 대안 B 선택

Phase 2 / Phase 3.0:
- `brainstorms/20260507-212317-auto-build-phase2-ralph-loop-persona-vote.md` — Phase 2 설계
- `brainstorms/20260512-202958-vibe-flow-phase3-cron-scheduler.md` — Phase 3 cron 결정

전체 17개 — `ls .claude/memory/brainstorms/`로 확인.

## 머지된 PR 인덱스 (Phase 3.1 + Phase 4)

- #69~#72 — Phase 3.1 cloud-native 본 구현
- #73 R9 marker / #74 F10~F12 클린업 / #75 R10 marker
- #76 — Karpathy 5번째 원칙 (Context Engineering) + donts 2 룰
- #77 — F14/F15 observability code (safety PASS 로그 + orchestrator vote 4종 stderr)
- #78 — R11 marker
- #79 — F16 cloud-init.sh

## 운영 정책 (이 repo 협업 시 알아야 할 것)

- **Conventional Commits 강제** (`core/rules/git.md`)
- **HARD-GATE 등급** (`core/rules/git.md`): 1~5 인라인 / 6~19 brief plan / 20+ 전체 설계
- **TDD RED-GREEN-REFACTOR Iron Law** (`core/rules/tdd.md`) — `*.test.*` 또는 `tests/*-smoke.sh` 부재 시 commit 금지
- **Surgical Change** (`core/rules/donts.md`) — 무관한 dead code/comment 임의 수정 금지
- **Context Engineering** (`core/rules/karpathy-principles.md` §5) — tee 금지, 긴 출력 file redirect, 대형 조회 subagent 위임

## 다음 진입점

1. **이번 audit fix PR 머지** (4 finding 묶음)
2. **R12 cloud cycle 재진입** — F16 PR #79 효과 확인 (cloud session log 직접 확인 필요)
3. **F17 (orchestrator markdown 강제력)** — F16 검증 후 진행
4. **F-D2 dogfooding gap 근본 원인 조사** — 44 skill + 22 agent 사용 0회 이유 분석

## 참고

- 상세 audit 결과 + finding 21건 분류는 user-level memory의 audit log 참조
- session-specific 결정 흐름은 user-level MEMORY.md 참조
- 이 파일은 협업자가 repo clone 후 바로 컨텍스트 잡을 수 있도록 작성
