#!/bin/bash
# TypeScript type check hook - PostToolUse (Edit/Write)
INPUT=$(cat)
source "$(dirname "$0")/_common.sh"
LOG_FILE="$TYPECHECK_LOG"
truncate_log_file "$LOG_FILE"

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# .ts/.tsx 파일만
case "$FILE_PATH" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking: $FILE_PATH" >> "$LOG_FILE"

# 가장 가까운 tsconfig.json 탐색
# Windows 크로스 플랫폼: 부모=자기 체크로 루트 감지
DIR=$(dirname "$FILE_PATH")
while true; do
  if [ -f "$DIR/tsconfig.json" ]; then
    break
  fi
  PARENT=$(dirname "$DIR")
  [ "$PARENT" = "$DIR" ] && break
  DIR="$PARENT"
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
  # PostToolUse 훅은 항상 exit 0 — 차단하지 않고 결과만 기록
fi

exit 0
