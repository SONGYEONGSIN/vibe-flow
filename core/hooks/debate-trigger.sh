#!/bin/bash
# debate-trigger.sh — PostToolUse hook
# 훅 실패 패턴을 감지하여 에이전트 간 토론을 자동 트리거한다.
# 실패해도 exit 0 — 기존 워크플로우를 차단하지 않음.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# .ts/.tsx 파일만
case "$FILE_PATH" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$PROJECT_ROOT" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
MSG_BUS="${SCRIPT_DIR}/message-bus.sh"
[ -f "$MSG_BUS" ] || exit 0
command -v jq &>/dev/null || exit 0

NOW=$(date +%s)
TRIGGER_FILE="${PROJECT_ROOT}/.claude/messages/.last-debate-trigger"

# 디바운스: 5분 이내 중복 트리거 방지
if [ -f "$TRIGGER_FILE" ]; then
  LAST_TRIGGER=$(cat "$TRIGGER_FILE" 2>/dev/null || echo "0")
  DIFF=$((NOW - LAST_TRIGGER))
  if [ "$DIFF" -lt 300 ]; then
    exit 0
  fi
fi

check_recent_failure() {
  local log="$1"
  [ -f "$log" ] || return 1
  local mod
  mod=$(get_file_mtime "$log")
  [ $((NOW - mod)) -lt 10 ] && tail -3 "$log" 2>/dev/null | grep -qi "error\|fail" && return 0
  return 1
}

DEBATE_NEEDED=false
DEBATE_TOPIC=""
DEBATE_AGENTS=""
DEBATE_DETAIL=""

# 트리거 1: 인증 관련 파일에서 TypeScript 에러
if check_recent_failure "$TYPECHECK_LOG"; then
  case "$FILE_PATH" in
    *auth*|*middleware*|*session*|*login*|*signup*|*actions*)
      DEBATE_NEEDED=true
      DEBATE_TOPIC="인증 관련 TypeScript 에러 해결 방향"
      DEBATE_AGENTS="security,developer"
      DEBATE_DETAIL="파일: $FILE_PATH — 인증 관련 파일에서 타입 에러 발생."
      ;;
  esac
fi

# 트리거 2: Server Action 테스트 실패
if [ "$DEBATE_NEEDED" = false ] && check_recent_failure "$TEST_RUNNER_LOG"; then
  case "$FILE_PATH" in
    *actions*|*server*|*api*)
      DEBATE_NEEDED=true
      DEBATE_TOPIC="Server Action 테스트 실패 원인 분석"
      DEBATE_AGENTS="qa,developer"
      DEBATE_DETAIL="파일: $FILE_PATH — Server Action 테스트 실패."
      ;;
  esac
fi

# 트리거 3: 같은 파일 3회 이상 실패
if [ "$DEBATE_NEEDED" = false ]; then
  TODAY=$(date '+%Y-%m-%d')
  METRICS_FILE="${PROJECT_ROOT}/.claude/metrics/daily-${TODAY}.json"
  if [ -f "$METRICS_FILE" ]; then
    REL_PATH="${FILE_PATH#${PROJECT_ROOT}/}"
    FAIL_COUNT=$(jq --arg f "$REL_PATH" \
      '[.events[] | select(.file == $f and (.results.typecheck == "fail" or .results.test == "fail"))] | length' \
      "$METRICS_FILE" 2>/dev/null || echo "0")

    if [ "$FAIL_COUNT" -ge 3 ] 2>/dev/null; then
      DEBATE_NEEDED=true
      DEBATE_TOPIC="반복 실패 파일 대응 — ${REL_PATH}"
      DEBATE_AGENTS="developer,feedback,qa"
      DEBATE_DETAIL="${REL_PATH}에서 오늘 ${FAIL_COUNT}회 실패. 리팩토링 vs 패치 방향 논의 필요."
    fi
  fi
fi

if [ "$DEBATE_NEEDED" = true ]; then
  mkdir -p "$(dirname "$TRIGGER_FILE")"
  echo "$NOW" > "$TRIGGER_FILE"

  CONTEXT=$(jq -n \
    --arg topic "$DEBATE_TOPIC" \
    --arg agents "$DEBATE_AGENTS" \
    --arg detail "$DEBATE_DETAIL" \
    --arg file "$FILE_PATH" \
    '{topic: $topic, suggested_agents: $agents, detail: $detail, trigger_file: $file}')

  bash "$MSG_BUS" send "debate-trigger" "moderator" "request" "high" \
    "토론 요청: $DEBATE_TOPIC" \
    "$DEBATE_DETAIL" \
    "$CONTEXT" >/dev/null 2>&1
fi

exit 0
