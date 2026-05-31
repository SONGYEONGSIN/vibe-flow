#!/bin/bash
set -u
# tool-invocation-tracker.sh — PostToolUse hook for Skill/Agent/Task tool calls
#
# audit F-D2 발견 (2026-06-01): skill-tracker.sh가 UserPromptSubmit hook이라
# /<skill> 슬래시 입력만 추적. Claude의 description 자동 trigger + Skill/Agent
# tool 명시 호출은 기록 안 됨 → events.jsonl에 83% instrumentation gap.
#
# 본 hook은 PostToolUse로 wire — Claude가 Skill/Agent/Task tool 호출 시
# input.skill / input.subagent_type 추출하여 events.jsonl에 기록.
#
# 실패해도 exit 0 — 워크플로우 차단 X.

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$PROJECT_ROOT" ] && exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ -z "$TOOL_NAME" ] && exit 0

# Skill / Agent / Task만 처리
case "$TOOL_NAME" in
  Skill|Agent|Task) ;;
  *) exit 0 ;;
esac

# tool별 target 필드 추출
case "$TOOL_NAME" in
  Skill)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
    EVENT_TYPE="skill_invoked_auto"
    FIELD_NAME="skill"
    ;;
  Agent|Task)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
    EVENT_TYPE="agent_invoked"
    FIELD_NAME="agent"
    ;;
esac

[ -z "$TARGET" ] && exit 0

EVENTS_FILE="${PROJECT_ROOT}/.claude/events.jsonl"
mkdir -p "$(dirname "$EVENTS_FILE")"

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%S')

if command -v jq &>/dev/null; then
  EVENT=$(jq -nc \
    --arg type "$EVENT_TYPE" \
    --arg target "$TARGET" \
    --arg field "$FIELD_NAME" \
    --arg tool "$TOOL_NAME" \
    --arg ts "$TIMESTAMP" \
    '{type: $type, ($field): $target, tool_name: $tool, ts: $ts}')
  echo "$EVENT" >> "$EVENTS_FILE" 2>/dev/null || true
else
  # jq 부재 fallback (escape 안전 — target은 영문/숫자/-/_만 가정)
  printf '{"type":"%s","%s":"%s","tool_name":"%s","ts":"%s"}\n' \
    "$EVENT_TYPE" "$FIELD_NAME" "$TARGET" "$TOOL_NAME" "$TIMESTAMP" >> "$EVENTS_FILE" 2>/dev/null || true
fi

exit 0
