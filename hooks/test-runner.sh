#!/bin/bash
# Related test auto-runner hook - PostToolUse (Edit/Write)
INPUT=$(cat)
source "$(dirname "$0")/_common.sh"
LOG_FILE="$TEST_RUNNER_LOG"
truncate_log_file "$LOG_FILE"

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# .ts/.tsx/.js/.jsx 파일만
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

# e2e 디렉토리는 Playwright 테스트이므로 제외
case "$FILE_PATH" in
  */e2e/*) exit 0 ;;
esac

# 테스트 파일 자체인지 확인
case "$FILE_PATH" in
  *.test.*|*.spec.*) TEST_FILE="$FILE_PATH" ;;
  *)
    BASENAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
    DIRNAME=$(dirname "$FILE_PATH")
    TEST_FILE=""
    for EXT in test spec; do
      for SUFFIX in ts tsx js jsx; do
        for CANDIDATE in \
          "$DIRNAME/$BASENAME.$EXT.$SUFFIX" \
          "$DIRNAME/__tests__/$BASENAME.$SUFFIX" \
          "$DIRNAME/__tests__/$BASENAME.$EXT.$SUFFIX"; do
          if [ -f "$CANDIDATE" ]; then
            TEST_FILE="$CANDIDATE"
            break 3
          fi
        done
      done
    done
    ;;
esac

if [ -z "$TEST_FILE" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] No test file for: $FILE_PATH" >> "$LOG_FILE"
  exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running: $TEST_FILE" >> "$LOG_FILE"

# 테스트 러너 감지 (vitest 우선)
# Windows 크로스 플랫폼: "/" 비교 대신 부모=자기 체크로 루트 감지
DIR=$(dirname "$FILE_PATH")
while true; do
  if [ -f "$DIR/package.json" ]; then
    break
  fi
  PARENT=$(dirname "$DIR")
  [ "$PARENT" = "$DIR" ] && break  # 루트 도달 (Unix: /, Windows: C:\)
  DIR="$PARENT"
done

# package.json을 찾지 못하면 스킵
if [ ! -f "$DIR/package.json" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] No package.json found" >> "$LOG_FILE"
  exit 0
fi

REL_TEST="${TEST_FILE#${DIR}/}"
if [ -f "$DIR/node_modules/.bin/vitest" ]; then
  OUTPUT=$(cd "$DIR" && npx vitest run "$REL_TEST" 2>&1)
elif [ -f "$DIR/node_modules/.bin/jest" ]; then
  OUTPUT=$(cd "$DIR" && npx jest --testPathPattern "$REL_TEST" 2>&1)
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] No test runner found" >> "$LOG_FILE"
  exit 0
fi

EXIT_CODE=$?
echo "$OUTPUT" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] test exit=$EXIT_CODE" >> "$LOG_FILE"

if [ $EXIT_CODE -ne 0 ]; then
  echo "[test-runner] Tests failed:" >&2
  echo "$OUTPUT" >&2
  # PostToolUse 훅은 항상 exit 0 — 차단하지 않고 결과만 기록
fi

exit 0
