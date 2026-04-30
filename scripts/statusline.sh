#!/bin/bash
# vibe-flow statusline — Claude Code statusLine 명령
#
# 출력: verify 결과 / 마지막 hook 결과 / 활성 plan 진행도를 한 줄로 합성
# 예시:
#   ✓v · 🔧✓ · 📋3/7 (auth)
#   ✗v(2 fail) · 🔧✗ tsc · 📋3/7
#
# Env:
#   VIBE_FLOW_STATUSLINE=off       — 비활성 (빈 출력)
#   VIBE_FLOW_STATUSLINE_VERBOSE=1 — 자세한 형태

# 비활성
[ "$VIBE_FLOW_STATUSLINE" = "off" ] && exit 0

# 강건성: 모든 실패는 무시 (statusLine 깨지면 안 됨)
# set -e 미사용

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
EVENTS="$PROJECT_DIR/.claude/events.jsonl"
PLANS_DIR="$PROJECT_DIR/.claude/plans"

VERBOSE="${VIBE_FLOW_STATUSLINE_VERBOSE:-0}"

parts=()

# 1. verify 결과 (최신 verify_complete event)
if [ -f "$EVENTS" ]; then
  LAST_VERIFY=$(tail -200 "$EVENTS" 2>/dev/null \
    | jq -s 'map(select(.type=="verify_complete")) | last' 2>/dev/null)
  VERIFY_OVERALL=$(echo "$LAST_VERIFY" | jq -r '.overall // ""' 2>/dev/null)

  if [ "$VERIFY_OVERALL" = "pass" ]; then
    if [ "$VERBOSE" = "1" ]; then
      parts+=("verify ✓ pass")
    else
      parts+=("✓v")
    fi
  elif [ "$VERIFY_OVERALL" = "fail" ]; then
    FAIL_COUNT=$(echo "$LAST_VERIFY" | jq -r '.results | map(select(.status=="fail")) | length' 2>/dev/null)
    [ -z "$FAIL_COUNT" ] || [ "$FAIL_COUNT" = "null" ] && FAIL_COUNT=0
    if [ "$VERBOSE" = "1" ]; then
      parts+=("verify ✗ ${FAIL_COUNT} fail")
    else
      parts+=("✗v(${FAIL_COUNT} fail)")
    fi
  fi
fi

# 2. 마지막 hook 결과
if [ -f "$EVENTS" ]; then
  LAST_TOOL=$(tail -50 "$EVENTS" 2>/dev/null \
    | jq -s 'map(select(.type=="tool_result" or .type=="tool_failure")) | last' 2>/dev/null)
  TOOL_TYPE=$(echo "$LAST_TOOL" | jq -r '.type // ""' 2>/dev/null)

  if [ "$TOOL_TYPE" = "tool_result" ]; then
    if [ "$VERBOSE" = "1" ]; then
      TOOL_NAME=$(echo "$LAST_TOOL" | jq -r '.tool // .results[0].hook // "?"' 2>/dev/null)
      parts+=("hook 🔧 ${TOOL_NAME} ✓")
    else
      parts+=("🔧✓")
    fi
  elif [ "$TOOL_TYPE" = "tool_failure" ]; then
    HOOK_NAME=$(echo "$LAST_TOOL" | jq -r '.tool // .error_class // "?"' 2>/dev/null)
    HOOK_NAME=$(echo "$HOOK_NAME" | head -c 12)
    if [ "$VERBOSE" = "1" ]; then
      parts+=("hook 🔧 ✗ ${HOOK_NAME}")
    else
      parts+=("🔧✗ ${HOOK_NAME}")
    fi
  fi
fi

# 3. 활성 plan 진행도
if [ -d "$PLANS_DIR" ]; then
  ACTIVE_PLAN=$(grep -l "^status: in_progress" "$PLANS_DIR"/*.md 2>/dev/null | head -1)
  if [ -n "$ACTIVE_PLAN" ]; then
    DONE=$(grep -c "^- \[x\]" "$ACTIVE_PLAN" 2>/dev/null)
    TOTAL=$(grep -cE "^- \[[ x]\]" "$ACTIVE_PLAN" 2>/dev/null)
    [ -z "$DONE" ] && DONE=0
    [ -z "$TOTAL" ] && TOTAL=0
    PLAN_NAME=$(basename "$ACTIVE_PLAN" .md | sed 's/^[0-9-]*//' | head -c 20)
    if [ "$TOTAL" -gt 0 ]; then
      if [ "$VERBOSE" = "1" ]; then
        parts+=("plan 📋 ${DONE}/${TOTAL} — ${PLAN_NAME}")
      else
        parts+=("📋${DONE}/${TOTAL} (${PLAN_NAME})")
      fi
    fi
  fi
fi

# 합성 + 출력
if [ ${#parts[@]} -gt 0 ]; then
  if [ "$VERBOSE" = "1" ]; then
    SEP=" | "
  else
    SEP=" · "
  fi
  IFS="$SEP"
  echo "${parts[*]}"
fi

exit 0
