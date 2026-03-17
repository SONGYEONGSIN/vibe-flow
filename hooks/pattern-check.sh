#!/bin/bash
# pattern-check.sh — PostToolUse prompt 훅
#
# Write/Edit 도구 사용 후, .claude/memory/patterns.md에 학습된 패턴을
# 수정된 코드가 따르는지 검증한다.
# 위반 시 systemMessage로 피드백 (차단하지 않음).

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
FILE_PATH="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"

# Write/Edit 도구만 검증
if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
  exit 0
fi

# 수정된 파일 경로가 없으면 종료
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

PATTERNS_FILE=".claude/memory/patterns.md"

# patterns.md가 없으면 검증 스킵
if [ ! -f "$PATTERNS_FILE" ]; then
  exit 0
fi

# 파일 확장자에 따라 관련 패턴 체크
EXT="${FILE_PATH##*.}"
WARNINGS=""

# patterns.md에서 "패턴:" 또는 "pattern:" 라인 추출하여 체크
while IFS= read -r line; do
  # 빈 줄이나 주석 스킵
  [ -z "$line" ] && continue
  [[ "$line" =~ ^# ]] && continue

  # "체크: <패턴>" 형식에서 패턴 추출
  if [[ "$line" =~ ^(체크|check|warn):\ *(.*) ]]; then
    CHECK_PATTERN="${BASH_REMATCH[2]}"

    # 파일에 해당 패턴이 있으면 경고
    if grep -q "$CHECK_PATTERN" "$FILE_PATH" 2>/dev/null; then
      WARNINGS="${WARNINGS}\n  - 패턴 위반: ${CHECK_PATTERN}"
    fi
  fi

  # "필수: <패턴>" — 파일에 반드시 있어야 하는 패턴
  if [[ "$line" =~ ^(필수|require):\ *(.*) ]]; then
    REQ_PATTERN="${BASH_REMATCH[2]}"

    # TypeScript 파일에만 적용되는 패턴
    if [[ "$EXT" == "ts" || "$EXT" == "tsx" ]]; then
      if ! grep -q "$REQ_PATTERN" "$FILE_PATH" 2>/dev/null; then
        WARNINGS="${WARNINGS}\n  - 필수 패턴 누락: ${REQ_PATTERN}"
      fi
    fi
  fi
done < "$PATTERNS_FILE"

# 경고가 있으면 출력 (차단하지 않음)
if [ -n "$WARNINGS" ]; then
  echo ""
  echo "[pattern-check] 학습된 패턴 확인:"
  echo -e "$WARNINGS"
  echo "  참조: $PATTERNS_FILE"
  echo ""
fi

# 항상 성공 (차단하지 않음)
exit 0
