#!/bin/bash
# PostToolUse hook: 메트릭 수집
# Write|Edit 이벤트 후 기존 훅의 로그에서 결과를 수집하여 일별 JSON에 기록
# 실패해도 exit 0 — 기존 워크플로우를 절대 차단하지 않음

INPUT=$(cat)
source "$(dirname "$0")/_common.sh"
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# .ts/.tsx/.js/.jsx 파일만 수집
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

# 프로젝트 루트 탐색
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

# 메트릭 디렉토리
METRICS_DIR="${PROJECT_ROOT}/.claude/metrics"
mkdir -p "$METRICS_DIR" 2>/dev/null

TODAY=$(date '+%Y-%m-%d')
METRICS_FILE="${METRICS_DIR}/daily-${TODAY}.json"
TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')

# 파일 초기화
if [ ! -f "$METRICS_FILE" ]; then
  echo '{"date":"'"$TODAY"'","events":[]}' > "$METRICS_FILE"
fi

# 기존 훅 로그에서 최신 결과 수집
collect_result() {
  local log_file="$1"

  if [ ! -f "$log_file" ]; then
    echo "skip"
    return
  fi

  # 로그 파일의 최근 수정 시간이 10초 이내면 이번 훅 실행 결과
  local now=$(date +%s)
  local mod
  mod=$(get_file_mtime "$log_file")
  local diff=$((now - mod))

  if [ "$diff" -gt 10 ]; then
    echo "skip"
    return
  fi

  # 마지막 줄에서 결과 판단
  local last_lines=$(tail -5 "$log_file" 2>/dev/null)

  # 성공 키워드가 있으면 pass (INPUT/HOOK TRIGGERED 등 메타 라인 무시)
  if echo "$last_lines" | grep -q "PRETTIER DONE\|SKIPPED:\|exit=0\|exit code 0"; then
    echo "pass"
    return
  fi

  # 실제 에러만 감지 (0 errors 제외)
  if echo "$last_lines" | grep -qi "exit code [1-9]\|exit=[1-9]\|BLOCKED"; then
    echo "fail"
    return
  fi

  # (0 errors, N warnings) 는 pass
  if echo "$last_lines" | grep -q "(0 errors"; then
    echo "pass"
    return
  fi

  # 그 외 error/fail 키워드
  if echo "$last_lines" | grep -qi "error\|failed"; then
    echo "fail"
  else
    echo "pass"
  fi
}

PRETTIER_RESULT=$(collect_result "$PRETTIER_LOG")
ESLINT_RESULT=$(collect_result "$ESLINT_LOG")
TYPECHECK_RESULT=$(collect_result "$TYPECHECK_LOG")
TEST_RESULT=$(collect_result "$TEST_RUNNER_LOG")

# 모두 skip이면 기록 안 함
if [ "$PRETTIER_RESULT" = "skip" ] && [ "$ESLINT_RESULT" = "skip" ] && [ "$TYPECHECK_RESULT" = "skip" ] && [ "$TEST_RESULT" = "skip" ]; then
  exit 0
fi

# 상대 경로로 변환
REL_PATH="${FILE_PATH#${PROJECT_ROOT}/}"

# jq로 이벤트 추가 (JSON 원본 + SQLite 이중 기록)
if command -v jq &>/dev/null; then
  EVENT_JSON=$(jq -n \
     --arg ts "$TIMESTAMP" \
     --arg tool "$TOOL_NAME" \
     --arg file "$REL_PATH" \
     --arg pr "$PRETTIER_RESULT" \
     --arg es "$ESLINT_RESULT" \
     --arg tc "$TYPECHECK_RESULT" \
     --arg te "$TEST_RESULT" \
     '{
       timestamp: $ts,
       tool: $tool,
       file: $file,
       results: {
         prettier: $pr,
         eslint: $es,
         typecheck: $tc,
         test: $te
       }
     }')

  # 1) JSON 파일 기록 (기존 경로, 하위 호환)
  TEMP_FILE=$(mktemp)
  trap "rm -f \"$TEMP_FILE\"" EXIT
  jq --argjson evt "$EVENT_JSON" '.events += [$evt]' "$METRICS_FILE" > "$TEMP_FILE" 2>/dev/null && mv "$TEMP_FILE" "$METRICS_FILE"

  # 2) SQLite 기록 (best-effort, 실패해도 JSON은 유지)
  STORE_JS="${PROJECT_ROOT}/.claude/scripts/store.js"
  if [ -f "$STORE_JS" ] && command -v node &>/dev/null; then
    echo "$EVENT_JSON" | node "$STORE_JS" append-event 2>/dev/null || true
  fi

  # 3) events.jsonl 실시간 스트림 기록 (observability, best-effort)
  EVENTS_FILE="${PROJECT_ROOT}/.claude/events.jsonl"
  if [ "$PRETTIER_RESULT" = "pass" ] && [ "$ESLINT_RESULT" = "pass" ] && [ "$TYPECHECK_RESULT" = "pass" ] && [ "$TEST_RESULT" = "pass" ]; then
    STREAM_STATUS="all_pass"
  elif echo "${PRETTIER_RESULT} ${ESLINT_RESULT} ${TYPECHECK_RESULT} ${TEST_RESULT}" | grep -q "fail"; then
    STREAM_STATUS="fail"
  else
    STREAM_STATUS="partial"
  fi
  echo "$EVENT_JSON" | jq -c --arg s "$STREAM_STATUS" '. + {type: "tool_result", status: $s, ts: .timestamp}' >> "$EVENTS_FILE" 2>/dev/null || true
fi

exit 0
