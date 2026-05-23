---
plan_id: 20260523-121259-vibe-flow-phase3-1-pr-c4-notify
status: in_progress
created: 2026-05-23T03:12:59Z
hard_gate: brief
source: sub-plan-of:20260523-093000-vibe-flow-phase3-1-cloud-native-master
---

# Sub-plan: Phase 3.1 PR-C4-notify — 결과 통보

## Goal

cloud cycle 완주 후 사용자 통보. 기본 = PR open (gh notification). 옵션 webhook. R10 cost threshold 알림.

## Out of Scope

- dashboard `/morning` 페이지 (별 cycle PR-D)
- multi-channel orchestration (단일 webhook URL만)
- email custom template

## 영향 파일 (~5)

- `core/skills/auto-build/scripts/notify-pr.sh` (신규)
- `core/skills/auto-build/scripts/run-cloud.sh` (수정)
- `core/skills/auto-build/scripts/run-log.sh` (수정)
- `scripts/tests/notify-pr-smoke.sh` (신규)
- `core/skills/auto-build/SKILL.md` (수정)

## 단계 T1~T9

T1 notify-smoke N1 (DRYRUN basic, RED) → T2 notify-pr.sh skeleton (GREEN T1) → T3 N2 cost threshold warning (RED) → T4 notify-pr.sh cost check (GREEN T3) → T5 N3 webhook optional (RED) → T6 notify-pr.sh webhook POST helper (GREEN T5) → T7 run-cloud.sh P5 후 notify 호출 → T8 SKILL.md "결과 통보 (PR-C4)" 섹션 → T9 종합 회귀
