#!/bin/bash
# /auto-build notify — cloud cycle 완주 후 사용자 통보 (Phase 3.1 PR-C4)
#
# 사용:
#   bash core/skills/auto-build/scripts/notify-pr.sh <pr-url> [cost-tokens]
#
# 동작:
#   1. PR URL 검증 (https://github.com/.../pull/N)
#   2. cost-tokens가 NOTIFY_COST_THRESHOLD (기본 50000) 초과 시 stderr warning
#   3. NOTIFY_WEBHOOK_URL env set이면 webhook POST (Discord/Slack 등 호환)
#   4. DRYRUN=1 → echo only, 실 POST 안 함
#
# env:
#   NOTIFY_PR_DRYRUN=1                — 실 POST 안 함, stdout echo만 (smoke 안전)
#   NOTIFY_WEBHOOK_URL                — 옵션 webhook URL (기본 unset = PR open 통보만)
#   NOTIFY_COST_THRESHOLD (기본 50000) — firing당 token cost warning threshold (R10)
#
# 통보 채널:
#   - 기본: PR open 자체로 gh notification (email) 발화 — 추가 액션 X
#   - 옵션: NOTIFY_WEBHOOK_URL이 set이면 cycle 완주 메시지 POST

set -u

PR_URL="${1:-}"
COST_TOKENS="${2:-0}"

if [ -z "$PR_URL" ]; then
  echo "usage: $0 <pr-url> [cost-tokens]" >&2
  exit 1
fi

# PR URL shape 간단 검증
if ! [[ "$PR_URL" =~ ^https://github\.com/[^/]+/[^/]+/pull/[0-9A-Za-z_-]+$ ]]; then
  echo "notify: invalid PR URL: $PR_URL" >&2
  exit 1
fi

DRYRUN="${NOTIFY_PR_DRYRUN:-0}"
THRESHOLD="${NOTIFY_COST_THRESHOLD:-50000}"
WEBHOOK="${NOTIFY_WEBHOOK_URL:-}"

# ── R10 cost threshold warning ────────────────────────────
if [[ "$COST_TOKENS" =~ ^[0-9]+$ ]] && [ "$COST_TOKENS" -gt "$THRESHOLD" ]; then
  echo "notify: cost $COST_TOKENS tokens > threshold $THRESHOLD (R10 cost warning)" >&2
fi

# ── DRYRUN 분기 ────────────────────────────────────────────
if [ "$DRYRUN" = "1" ]; then
  echo "would notify: $PR_URL (cost=$COST_TOKENS)"
  if [ -n "$WEBHOOK" ]; then
    echo "  webhook: $WEBHOOK (DRYRUN — POST skipped)"
  fi
  exit 0
fi

# ── 실 통보 (DRYRUN=0) ─────────────────────────────────────
# 기본 채널: PR open 자체. gh notification이 사용자 email 발화.
# 별 액션 X — PR URL stdout만 출력 (run-cloud.sh가 cycle 결과로 사용)
echo "$PR_URL"

# 옵션 webhook POST
if [ -n "$WEBHOOK" ]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "notify: curl not found — webhook skipped" >&2
    exit 2
  fi
  MSG=$(jq -nc \
    --arg pr "$PR_URL" \
    --arg cost "$COST_TOKENS" \
    '{text: "vibe-flow auto-build cycle 완주: \($pr) (cost=\($cost) tokens)"}')
  curl -sS -X POST -H "Content-Type: application/json" -d "$MSG" "$WEBHOOK" >&2 || {
    echo "notify: webhook POST 실패 (URL=$WEBHOOK)" >&2
    exit 3
  }
  echo "notify: webhook POSTed → $WEBHOOK" >&2
fi
exit 0
