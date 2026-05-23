---
plan_id: 20260523-114759-vibe-flow-phase3-1-pr-c3-safety
status: in_progress
created: 2026-05-23T02:47:59Z
hard_gate: brief
source: sub-plan-of:20260523-093000-vibe-flow-phase3-1-cloud-native-master
---

# Sub-plan: Phase 3.1 PR-C3-safety — queue git 전환 + safety cloud probe

## Goal

R8 dogfooding 준비. queue.jsonl git-committed + queue-commit helper + safety hook cloud env probe 단락.

## Out of Scope

- 실 R8 dogfooding (머지 후 별 cycle)
- A3.3 fallback 코드 활성화 (R8 결과 후)
- depends_on polling (별 PR)
- multi-machine queue.jsonl sync

## 영향 파일 (~6)

- `.gitignore` (수정)
- `core/skills/auto-build/scripts/queue-commit.sh` (신규)
- `core/hooks/auto-build-safety.sh` (수정)
- `scripts/tests/queue-commit-smoke.sh` (신규)
- `core/skills/auto-build/SKILL.md` (수정)
- `.claude/memory/auto-build-queue.jsonl` (신규 — 빈 placeholder)

## 단계 T1~T9

T1 queue-commit-smoke Q1 (DRYRUN echo, RED) → T2 queue-commit.sh skeleton (GREEN T1) → T3 Q2 (dirty tree, RED) → T4 dirty tree fallback (GREEN T3) → T5 .gitignore 라인 제거 → T6 빈 queue.jsonl placeholder commit → T7 safety.sh cloud env probe 단락 → T8 SKILL.md Cloud Safety 섹션 → T9 종합 회귀 + R8 dogfooding 안내
