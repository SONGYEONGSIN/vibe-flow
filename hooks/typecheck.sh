#!/bin/bash
# TypeScript type check hook - PostToolUse (Edit/Write)
INPUT=$(cat)
LOG_FILE="/tmp/typecheck-hook.log"
# 로그 1MB 초과 시 truncate
[ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE" 2>/dev/null)" -gt 1048576 ] && tail -100 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# .ts/.tsx 파일만
case "$FILE_PATH" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking: $FILE_PATH" >> "$LOG_FILE"

# 가장 가까운 tsconfig.json 탐색
DIR=$(dirname "$FILE_PATH")
while [ "$DIR" != "/" ]; do
  if [ -f "$DIR/tsconfig.json" ]; then
    break
  fi
  DIR=$(dirname "$DIR")
done

if [ ! -f "$DIR/tsconfig.json" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] No tsconfig.json found" >> "$LOG_FILE"
  exit 0
fi

OUTPUT=$(cd "$DIR" && npx tsc --noEmit 2>&1)
EXIT_CODE=$?

echo "[$(date '+%Y-%m-%d %H:%M:%S')] tsc exit=$EXIT_CODE" >> "$LOG_FILE"
[ -n "$OUTPUT" ] && echo "$OUTPUT" >> "$LOG_FILE"

if [ $EXIT_CODE -ne 0 ]; then
  echo "[typecheck] TypeScript errors found:" >&2
  echo "$OUTPUT" >&2
  exit 2
fi

exit 0
