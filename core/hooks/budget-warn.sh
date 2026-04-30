#!/bin/bash
# budget-warn.sh — Notification hook
# 일일 한도 80%+ 사용 시 비차단 경고 (additionalContext)
# 디바운스: 15분 (.budget-last-warn 타임스탬프)
#
# 비차단 — 항상 exit 0. 모든 jq/bc 실패 무시.

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
BUDGET_FILE="$PROJECT_DIR/.claude/budget.json"
EVENTS="$PROJECT_DIR/.claude/events.jsonl"
LAST_WARN="$PROJECT_DIR/.claude/.budget-last-warn"

# 디바운스 (15분)
if [ -f "$LAST_WARN" ]; then
  LAST=$(cat "$LAST_WARN" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  AGE=$((NOW - LAST))
  [ "$AGE" -lt 900 ] && exit 0
fi

[ -f "$BUDGET_FILE" ] || exit 0
[ -f "$EVENTS" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v bc >/dev/null 2>&1 || exit 0

THRESHOLD=$(jq -r '.warn_threshold // 0.8' "$BUDGET_FILE" 2>/dev/null || echo 0.8)
TODAY=$(date -u +%Y-%m-%d)

WARNINGS=()
for type in $(jq -r '.limits | keys[]' "$BUDGET_FILE" 2>/dev/null); do
  daily_limit=$(jq -r --arg t "$type" '.limits[$t].daily // 0' "$BUDGET_FILE" 2>/dev/null)
  [ -z "$daily_limit" ] || [ "$daily_limit" = "0" ] && continue

  count=$(jq -r --arg t "$type" --arg today "$TODAY" \
    'select(.type==$t and (.ts | startswith($today))) | .type' \
    "$EVENTS" 2>/dev/null | wc -l | tr -d ' ')

  ratio=$(echo "scale=2; $count / $daily_limit" | bc 2>/dev/null)
  [ -z "$ratio" ] && continue

  if [ "$(echo "$ratio >= $THRESHOLD" | bc -l 2>/dev/null)" = "1" ]; then
    pct=$(echo "$ratio * 100" | bc 2>/dev/null | awk '{printf "%d", $0}')
    case "$type" in
      pair_session) label="/pair" ;;
      discuss) label="/discuss" ;;
      skill_evolve) label="/evolve" ;;
      design_sync) label="/design-sync" ;;
      retrospective) label="/retrospective" ;;
      *) label="$type" ;;
    esac
    WARNINGS+=("${label}: ${count}/${daily_limit} (${pct}%)")
  fi
done

if [ ${#WARNINGS[@]} -gt 0 ]; then
  msg='💰 일일 budget 80%+ 사용 중:\n'
  for w in "${WARNINGS[@]}"; do
    msg="${msg}  • ${w}\n"
  done
  msg="${msg}\n자세한 사용량: /budget"

  jq -nc --arg msg "$msg" '{additionalContext: $msg}'
  date +%s > "$LAST_WARN"
fi

exit 0
