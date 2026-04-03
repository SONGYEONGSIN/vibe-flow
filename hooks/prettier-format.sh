#!/bin/bash
INPUT=$(cat)
source "$(dirname "$0")/_common.sh"
LOG_FILE="$PRETTIER_LOG"
# 로그 1MB 초과 시 truncate (원자적 처리)
if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)" -gt 1048576 ]; then
  TMPLOG=$(mktemp "${LOG_FILE}.XXXXXX") && tail -100 "$LOG_FILE" > "$TMPLOG" && mv "$TMPLOG" "$LOG_FILE" || rm -f "$TMPLOG"
fi
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
  npx prettier --write "$FILE_PATH" >> "$LOG_FILE" 2>&1 || true
  echo "PRETTIER DONE" >> "$LOG_FILE"
else
  echo "SKIPPED: file not found or empty path" >> "$LOG_FILE"
fi

exit 0
