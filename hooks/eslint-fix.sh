#!/bin/bash
# ESLint auto-fix hook - PostToolUse (Edit/Write)
INPUT=$(cat)
LOG_FILE="/tmp/eslint-hook.log"
# 로그 1MB 초과 시 truncate
[ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE" 2>/dev/null)" -gt 1048576 ] && tail -100 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# .ts/.tsx/.js/.jsx 파일만
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ESLint: $FILE_PATH" >> "$LOG_FILE"

# 가장 가까운 eslint.config.* 위치에서 실행
DIR=$(dirname "$FILE_PATH")
while [ "$DIR" != "/" ]; do
  if ls "$DIR"/eslint.config.* 2>/dev/null | grep -q .; then
    break
  fi
  DIR=$(dirname "$DIR")
done

# eslint config를 찾지 못하면 스킵
if ! ls "$DIR"/eslint.config.* &>/dev/null; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] No eslint config found" >> "$LOG_FILE"
  exit 0
fi

REL_PATH="${FILE_PATH#${DIR}/}"
OUTPUT=$(cd "$DIR" && npx eslint --fix "$REL_PATH" 2>&1)
EXIT_CODE=$?

echo "$OUTPUT" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] eslint exit=$EXIT_CODE" >> "$LOG_FILE"

exit 0
