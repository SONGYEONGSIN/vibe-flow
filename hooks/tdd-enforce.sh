#!/bin/bash
# tdd-enforce.sh — PreToolUse (Write|Edit) — TDD 규칙 강제화
#
# 동작:
#   - 소스 파일(.ts/.tsx/.js/.jsx) 수정 시도 시 대응 테스트 파일 존재 확인
#   - 없으면 경고 (기본) 또는 차단 (CLAUDE_TDD_ENFORCE=strict)
#
# 제외:
#   - 테스트 파일 자체 (*.test.*, *.spec.*, __tests__/*)
#   - 설정/타입 선언 (*.config.*, *.d.ts)
#
# 모드 전환:
#   export CLAUDE_TDD_ENFORCE=strict  # 차단 모드 (exit 2)
#   export CLAUDE_TDD_ENFORCE=off     # 비활성화
#
# 커뮤니티 출처: obra/superpowers — 초기에는 경고만, 신뢰 쌓인 뒤 차단으로 승격

set -u

INPUT=$(cat)

MODE="${CLAUDE_TDD_ENFORCE:-warn}"
[ "$MODE" = "off" ] && exit 0

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# 대상 확장자 외 스킵
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

# 제외 대상
case "$FILE_PATH" in
  *.test.*|*.spec.*) exit 0 ;;
  *.config.*|*.d.ts) exit 0 ;;
  */__tests__/*) exit 0 ;;
  */node_modules/*) exit 0 ;;
esac

# 신규 파일인지 확인 (Write는 신규 가능, Edit은 기존 파일만)
# 신규 파일은 "아직 구현 코드 없음" → 테스트 먼저 쓰는 게 정상이라 경고
# 기존 파일은 "이미 있는 구현에 테스트 없음" → 더 강한 경고

# 테스트 파일 탐색 (test-runner.sh와 동일 패턴)
BASENAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
DIRNAME=$(dirname "$FILE_PATH")
TEST_FOUND=""
for EXT in test spec; do
  for SUFFIX in ts tsx js jsx; do
    for CANDIDATE in \
      "$DIRNAME/$BASENAME.$EXT.$SUFFIX" \
      "$DIRNAME/__tests__/$BASENAME.$SUFFIX" \
      "$DIRNAME/__tests__/$BASENAME.$EXT.$SUFFIX"; do
      if [ -f "$CANDIDATE" ]; then
        TEST_FOUND="$CANDIDATE"
        break 3
      fi
    done
  done
done

# 테스트 있으면 통과
[ -n "$TEST_FOUND" ] && exit 0

# 메시지 구성
MSG="[tdd-enforce] 테스트 파일 없음: ${FILE_PATH}
  예상 경로:
    - ${DIRNAME}/${BASENAME}.test.(ts|tsx|js|jsx)
    - ${DIRNAME}/__tests__/${BASENAME}.(ts|tsx|js|jsx)
  TDD 원칙: RED(실패 테스트) → GREEN(최소 구현) → IMPROVE(리팩터링)
  비활성화: export CLAUDE_TDD_ENFORCE=off"

# 차단 모드
if [ "$MODE" = "strict" ]; then
  echo "$MSG" >&2
  echo "[tdd-enforce] BLOCKED — 테스트 먼저 작성하세요 (CLAUDE_TDD_ENFORCE=strict)" >&2
  exit 2
fi

# 경고 모드 — additionalContext로 Claude에게 전달
jq -n --arg msg "$MSG" '{additionalContext: $msg}' 2>/dev/null || true
exit 0
