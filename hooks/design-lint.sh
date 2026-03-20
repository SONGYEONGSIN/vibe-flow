#!/bin/bash
# design-lint.sh — PostToolUse prompt 훅
#
# Write/Edit 도구 사용 후, .tsx/.jsx/.css 파일에서
# 하드코딩된 색상값(hex, rgb, hsl)을 감지한다.
# 위반 시 systemMessage로 피드백 (차단하지 않음).

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Write/Edit 도구만 검증
if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
  exit 0
fi

# 파일 경로 및 존재 확인
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# .tsx/.jsx/.css/.scss 파일만 검사
case "$FILE_PATH" in
  *.tsx|*.jsx|*.css|*.scss) ;;
  *) exit 0 ;;
esac

# 디자인 토큰 정의 파일, tailwind 설정, globals.css는 스킵
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
  design-tokens.*|tailwind.config.*|globals.css) exit 0 ;;
esac
case "$FILE_PATH" in
  */design-tokens.*|*/tailwind.config.*) exit 0 ;;
esac

WARNINGS=""

# hex 색상 감지: #xxx, #xxxxxx, #xxxxxxxx (주석 제외)
HEX_MATCHES=$(grep -nE '#[0-9a-fA-F]{3,8}\b' "$FILE_PATH" 2>/dev/null | grep -v '^\s*//' | grep -v '^\s*\*' | head -5)
if [ -n "$HEX_MATCHES" ]; then
  WARNINGS="${WARNINGS}\n  [hex 색상]"
  while IFS= read -r match; do
    WARNINGS="${WARNINGS}\n    $match"
  done <<< "$HEX_MATCHES"
fi

# rgb()/rgba()/hsl()/hsla() 감지 (주석 제외)
FUNC_MATCHES=$(grep -nEi '(rgb|hsl)a?\(' "$FILE_PATH" 2>/dev/null | grep -v '^\s*//' | grep -v '^\s*\*' | head -5)
if [ -n "$FUNC_MATCHES" ]; then
  WARNINGS="${WARNINGS}\n  [rgb/hsl 함수]"
  while IFS= read -r match; do
    WARNINGS="${WARNINGS}\n    $match"
  done <<< "$FUNC_MATCHES"
fi

# 경고 출력
if [ -n "$WARNINGS" ]; then
  echo ""
  echo "[design-lint] 하드코딩 색상 감지:"
  echo -e "$WARNINGS"
  echo ""
  echo "  → Tailwind CSS 클래스 또는 디자인 토큰 상수를 사용하세요."
  echo "  → 참조: .claude/rules/design.md"
  echo ""
fi

# 항상 성공 (차단하지 않음)
exit 0
