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
# PR-C2에서는 gh CLI 존재 확인 + abort fallback만 구현
# 실 /auto-build dispatch + PR 생성은 PR-C3 R8 dogfooding 후 활성

if ! command -v gh >/dev/null 2>&1; then
  bash "$QUEUE_SH" status-update "$ID" "aborted" >/dev/null
  echo "run-cloud: gh CLI not found in cloud env — entry $ID aborted" >&2
  exit 2
fi

# 실 /auto-build run-cloud cycle은 PR-C3 R8 dogfooding 후 활성
# 현 PR-C2는 entry running 상태 보존 + exit 1 (task 소실 방지)
bash "$QUEUE_SH" status-update "$ID" "queued" >/dev/null
cat >&2 <<EOM
run-cloud: 실 cycle은 PR-C3 R8 dogfooding 후 활성.
  entry $ID 는 'queued' 상태로 복구됨 (소실 방지).
  검증: AUTO_BUILD_QUEUE_DRYRUN=1 로 재호출.
EOM
exit 1
