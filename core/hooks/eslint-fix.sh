#!/bin/bash
# ESLint auto-fix hook - PostToolUse (Edit/Write)
INPUT=$(cat)
source "$(dirname "$0")/_common.sh"
LOG_FILE="$ESLINT_LOG"
truncate_log_file "$LOG_FILE"

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# .ts/.tsx/.js/.jsx 파일만
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ESLint: $FILE_PATH" >> "$LOG_FILE"

# 가장 가까운 eslint.config.* 위치에서 실행
# Windows 크로스 플랫폼: 부모=자기 체크로 루트 감지
DIR=$(dirname "$FILE_PATH")
while true; do
  if ls "$DIR"/eslint.config.* 2>/dev/null | grep -q .; then
    break
  fi
  PARENT=$(dirname "$DIR")
  [ "$PARENT" = "$DIR" ] && break
  DIR="$PARENT"
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

if [ $EXIT_CODE -ne 0 ]; then
  echo "[eslint-fix] FAILED: $REL_PATH (exit=$EXIT_CODE)" >&2
  echo "$OUTPUT" >&2
  # PostToolUse 훅은 항상 exit 0 — 차단하지 않고 결과만 기록
fi

exit 0
