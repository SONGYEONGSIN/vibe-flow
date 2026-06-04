#!/bin/bash
# core/skills/auto-build/scripts/cycles-report.sh
# Auto-build cycle observability report — git log + queue + local firings 통합
# F-D3 R3-4: cloud firings 데이터 가시화 (cloud routine 실 fire 카운트는
# Anthropic routines dashboard / `/schedule list` 가 authoritative)

set -u
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
QUEUE_STORE="${QUEUE_STORE:-$PROJECT_ROOT/.claude/memory/auto-build-queue.jsonl}"
FIRINGS_STORE="${FIRINGS_STORE:-$PROJECT_ROOT/.claude/memory/auto-build-firings.jsonl}"

cd "$PROJECT_ROOT" 2>/dev/null || { echo "PROJECT_ROOT not accessible: $PROJECT_ROOT" >&2; exit 2; }

echo "=== Auto-build cycles report ==="
echo

# 1. Cloud cycle marker PRs (R<N> dogfooding marker pattern)
echo "## Cloud cycle marker commits (git log)"
MARKERS=$(git log --all --oneline --grep 'R[0-9]\+ dogfooding marker' 2>/dev/null)
if [ -n "$MARKERS" ]; then
  echo "$MARKERS" | head -20
  COUNT=$(echo "$MARKERS" | wc -l | tr -d ' ')
  echo "→ total marker commits: $COUNT"
else
  echo "(no marker commits found)"
fi
echo

# 2. Local manual firings (firings.jsonl — local /auto-build run-queue.sh only)
echo "## Local manual firings ($FIRINGS_STORE)"
if [ -s "$FIRINGS_STORE" ]; then
  LOCAL_COUNT=$(wc -l < "$FIRINGS_STORE" | tr -d ' ')
  echo "total: $LOCAL_COUNT entries"
  tail -3 "$FIRINGS_STORE"
else
  echo "(empty or not present)"
fi
echo

# 3. Queue status snapshot — current state per task id
echo "## Queue status (latest state per task)"
if [ -s "$QUEUE_STORE" ]; then
  # 각 id별 마지막 entry의 status (또는 op=status_update의 new_status)
  # 각 id별 latest state (initial entry 또는 마지막 status_update의 new_status)
  LATEST=$(jq -rs '
    [.[] | select(.id != null) | {
      id: .id,
      status: (.new_status // .status),
      created_ts: (.created_ts // .ts),
      task: (.task // null)
    }] |
    group_by(.id) | map(.[-1])
  ' "$QUEUE_STORE" 2>/dev/null)

  echo "$LATEST" | jq -r '
    group_by(.status) |
    map({status: .[0].status, count: length}) |
    .[] | "\(.status): \(.count)"
  '
  echo
  STUCK=$(echo "$LATEST" | jq -r '
    map(select(.status == "queued")) |
    sort_by(.created_ts) |
    .[] | "  - \(.id) (created \(.created_ts))"
  ')
  if [ -n "$STUCK" ]; then
    echo "queued entries (potential stuck — routine may not have fired):"
    echo "$STUCK"
  fi
else
  echo "(empty or not present)"
fi
echo

echo "## Cloud routine firings (authoritative)"
echo "→ Anthropic routines dashboard: https://claude.ai/code/routines"
echo "→ Or via Claude Code: /schedule list"
echo "  (R3-4: local 파일은 marker PR commit + queue 상태로만 추적, fire timestamp 는 schedule API 만 정확)"
