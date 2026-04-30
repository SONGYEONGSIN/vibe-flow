#!/bin/bash
# Recursion guard — prettier가 파일을 다시 쓰면 PostToolUse가 재트리거될 수 있음
if [ "${CLAUDE_HOOK_DEPTH:-0}" -ge 2 ]; then
  exit 0
fi
export CLAUDE_HOOK_DEPTH=$((${CLAUDE_HOOK_DEPTH:-0} + 1))

INPUT=$(cat)
source "$(dirname "$0")/_common.sh"
LOG_FILE="$PRETTIER_LOG"
truncate_log_file "$LOG_FILE"
echo "$(date): HOOK TRIGGERED" >> "$LOG_FILE"
echo "INPUT: $INPUT" >> "$LOG_FILE"

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
echo "FILE_PATH: $FILE_PATH" >> "$LOG_FILE"

# 지원하는 파일 확장자만 포맷
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.css|*.scss|*.json|*.html) ;;
  *) echo "SKIPPED: unsupported extension" >> "$LOG_FILE"; exit 0 ;;
esac

if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
  if ! npx prettier --write "$FILE_PATH" >> "$LOG_FILE" 2>&1; then
    echo "[prettier-format] FAILED: $FILE_PATH (see $LOG_FILE)" >&2
    echo "PRETTIER FAILED" >> "$LOG_FILE"
  else
    echo "PRETTIER DONE" >> "$LOG_FILE"
  fi
else
  echo "SKIPPED: file not found or empty path" >> "$LOG_FILE"
fi

exit 0
