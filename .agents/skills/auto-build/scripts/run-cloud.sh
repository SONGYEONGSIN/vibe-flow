#!/bin/bash
# /auto-build run-cloud — cloud remote agent 진입점 (Phase 3.1 PR-C2)
#
# 1 firing = 1 task = 1 cycle = 1 PR 정책. cloud session 단일 lane.
#
# 진입:
#   1. queue.sh next로 첫 queued entry pop (running 마킹)
#   2. queue 비어있으면 stderr "queue empty" + exit 0
#   3. DRYRUN=1 → mock /auto-build dispatch + mock PR URL stdout + status_update done
#   4. DRYRUN=0 → 실 /auto-build cycle (gh CLI 필요) + 실 PR 생성 (PR-C3 dogfooding 검증)
#
# env:
#   AUTO_BUILD_QUEUE_DRYRUN=1     — DRYRUN 모드 (smoke 안전 격리)
#   QUEUE_STORE / QUEUE_LOCK_DIR  — queue.sh 상속
#
# 정책:
#   - cloud session 가정: AUTO_BUILD_QUEUE_CRON_FIRING=1 자동 set (prompt 템플릿 명시)
#   - vote confidence < 0.7 시 abort (orchestrator P0 cron 보수 정책)
#   - PR-C3 dogfooding 후 R8(vote/safety hook cloud 동작) 결과 반영

set -u

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
QUEUE_SH="$PROJECT_ROOT/core/skills/auto-build/scripts/queue.sh"

# queue.sh와 동일 store/lockdir 명시 export
export QUEUE_STORE="${QUEUE_STORE:-$PROJECT_ROOT/.claude/memory/auto-build-queue.jsonl}"
export QUEUE_LOCK_DIR="${QUEUE_LOCK_DIR:-$PROJECT_ROOT/.claude/.queue.lock}"

DRYRUN="${AUTO_BUILD_QUEUE_DRYRUN:-0}"

# ── queue 첫 entry pop ─────────────────────────────────────
ID=$(bash "$QUEUE_SH" next)

if [ -z "$ID" ]; then
  echo "run-cloud: queue empty — no task to process" >&2
  exit 0
fi

echo "run-cloud: processing entry $ID"

# ── DRYRUN 분기 ────────────────────────────────────────────
if [ "$DRYRUN" = "1" ]; then
  MOCK_PR_URL="https://github.com/SONGYEONGSIN/vibe-flow/pull/MOCK-$ID"
  echo "$MOCK_PR_URL"
  bash "$QUEUE_SH" status-update "$ID" "done" >/dev/null
  echo "run-cloud: cycle done (DRYRUN) — entry $ID" >&2
  # PR-C4: notify-pr.sh 호출 (DRYRUN inherit — 실 webhook 안 함)
  NOTIFY_SH="$PROJECT_ROOT/core/skills/auto-build/scripts/notify-pr.sh"
  if [ -x "$NOTIFY_SH" ]; then
    NOTIFY_PR_DRYRUN=1 bash "$NOTIFY_SH" "$MOCK_PR_URL" 0 >/dev/null || true
  fi
  exit 0
fi

# ── 실 cycle (DRYRUN=0) ────────────────────────────────────

# F-P02 (audit round P): gh 조기 게이트 제거. run-cloud.sh 책임은 entry 선택 + hand-off
# 까지이며, PR 생성 수단(gh vs mcp__github) 판단은 P5(agent) 관심사다. gh 부재만으로
# gh 와 무관한 P0~P4(브랜치/brainstorm/plan/TDD/verify)까지 무산출 abort 되던 회귀 차단.
# gh/mcp 둘 다 없을 때의 abort 는 agent 가 P5 에서 판단한다(orchestrator.md P5).

# F-D7 (audit round 4, 2026-06-06): PR-C2 stub 제거.
# PR-C3 R8 dogfooding (2026-05-23 PR #71) + R9~R11 functional PASS 로 실 cycle 활성.
# run-cloud.sh 책임은 entry 선택 + running 마킹(queue.sh next에서 완료) 까지.
# 실 cycle (orchestrator P0~P5 + PR 생성 + status-update) 은 cloud agent 가
# 본 script 종료 후 자율 수행한다.
cat >&2 <<EOM
run-cloud: entry $ID handed off to cloud agent (status=running).
  Agent must now execute:
    1. core/skills/auto-build/orchestrator.md P0~P5 (brainstorm → plan → TDD → verify → commit)
    2. PR 생성 — gh 있으면 'gh pr create', 없으면 'mcp__github__create_pull_request' (GitHub MCP); 둘 다 없을 때만 abort
    3. bash $QUEUE_SH status-update $ID done    (성공 시)
       bash $QUEUE_SH status-update $ID aborted (실패 시)
EOM
exit 0
