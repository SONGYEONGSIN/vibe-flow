#!/bin/bash
# PostToolUse hook: 메트릭 수집
# Write|Edit 이벤트 후 기존 훅의 로그에서 결과를 수집하여 일별 JSON에 기록
# 실패해도 exit 0 — 기존 워크플로우를 절대 차단하지 않음

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# .ts/.tsx/.js/.jsx 파일만 수집
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

# 프로젝트 루트 탐색
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
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
  if [ "$(uname)" = "Darwin" ]; then
    mod=$(stat -f %m "$log_file" 2>/dev/null || echo 0)
  else
    mod=$(stat -c %Y "$log_file" 2>/dev/null || echo 0)
  fi
  local diff=$((now - mod))

  if [ "$diff" -gt 10 ]; then
    echo "skip"
    return
  fi

  # 마지막 줄에서 결과 판단
  local last_lines=$(tail -3 "$log_file" 2>/dev/null)
  if echo "$last_lines" | grep -qi "error\|fail\|exit code [1-9]"; then
    echo "fail"
  else
    echo "pass"
  fi
}

PRETTIER_RESULT=$(collect_result "/tmp/prettier-hook.log")
ESLINT_RESULT=$(collect_result "/tmp/eslint-hook.log")
TYPECHECK_RESULT=$(collect_result "/tmp/typecheck-hook.log")
TEST_RESULT=$(collect_result "/tmp/test-runner-hook.log")

# 모두 skip이면 기록 안 함
if [ "$PRETTIER_RESULT" = "skip" ] && [ "$ESLINT_RESULT" = "skip" ] && [ "$TYPECHECK_RESULT" = "skip" ] && [ "$TEST_RESULT" = "skip" ]; then
  exit 0
fi

# 상대 경로로 변환
REL_PATH="${FILE_PATH#${PROJECT_ROOT}/}"

# jq로 이벤트 추가
if command -v jq &>/dev/null; then
  TEMP_FILE=$(mktemp)
  trap "rm -f \"$TEMP_FILE\"" EXIT
  jq --arg ts "$TIMESTAMP" \
     --arg tool "$TOOL_NAME" \
     --arg file "$REL_PATH" \
     --arg pr "$PRETTIER_RESULT" \
     --arg es "$ESLINT_RESULT" \
     --arg tc "$TYPECHECK_RESULT" \
     --arg te "$TEST_RESULT" \
     '.events += [{
       timestamp: $ts,
       tool: $tool,
       file: $file,
       results: {
         prettier: $pr,
         eslint: $es,
         typecheck: $tc,
         test: $te
       }
     }]' "$METRICS_FILE" > "$TEMP_FILE" 2>/dev/null && mv "$TEMP_FILE" "$METRICS_FILE"
fi

exit 0
