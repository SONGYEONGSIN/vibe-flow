#!/bin/bash
# Stop hook: 커밋 안 한 변경사항이 있으면 경고

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

cd "$PROJECT_ROOT" || exit 0

CHANGES=$(git status --porcelain 2>/dev/null)
if [ -n "$CHANGES" ]; then
  COUNT=$(echo "$CHANGES" | wc -l | tr -d ' ')
  echo "⚠️ 커밋되지 않은 변경사항 ${COUNT}개가 있습니다."
  echo "$CHANGES" | head -10
  if [ "$COUNT" -gt 10 ]; then
    echo "... 외 $((COUNT - 10))개"
  fi
fi
