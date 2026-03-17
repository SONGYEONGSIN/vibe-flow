#!/bin/bash
# Stop hook: 커밋 안 한 변경사항이 있으면 경고
# NOTE: session-review.sh에서 더 상세한 리뷰를 수행하므로,
# 이 훅은 session-review.sh 없이 단독으로 사용할 때를 위해 유지.
# 두 훅을 함께 등록할 경우, settings에서 이 훅을 제거하면 중복 출력이 없어짐.

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

cd "$PROJECT_ROOT" || exit 0

# session-review.sh가 같은 디렉토리에 있으면 중복 출력 방지
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/session-review.sh" ]; then
  exit 0
fi

CHANGES=$(git status --porcelain 2>/dev/null)
if [ -n "$CHANGES" ]; then
  COUNT=$(echo "$CHANGES" | wc -l | tr -d ' ')
  echo "⚠️ 커밋되지 않은 변경사항 ${COUNT}개가 있습니다."
  echo "$CHANGES" | head -10
  if [ "$COUNT" -gt 10 ]; then
    echo "... 외 $((COUNT - 10))개"
  fi
fi

exit 0
