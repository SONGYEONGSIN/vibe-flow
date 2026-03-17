#!/bin/bash
# session-review.sh — Stop prompt 훅
#
# 세션 종료 시 작업 품질을 종합 평가한다:
# - 미커밋 변경 파일 수
# - 테스트 실행 여부 확인
# - 타입체크 통과 여부
# - 학습 저장 제안 (/learn save)
#
# 기존 uncommitted-warn.sh의 단순 카운트를 대체하여
# 더 풍부한 세션 리뷰를 제공한다.

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       SESSION REVIEW                 ║"
echo "╚══════════════════════════════════════╝"

# 1. 미커밋 변경 확인
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
STAGED=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
UNSTAGED=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

if [ "$UNCOMMITTED" -gt 0 ]; then
  echo ""
  echo "⚠ 미커밋 변경: ${UNCOMMITTED}개 파일"
  [ "$STAGED" -gt 0 ] && echo "  - staged: ${STAGED}개"
  [ "$UNSTAGED" -gt 0 ] && echo "  - modified: ${UNSTAGED}개"
  [ "$UNTRACKED" -gt 0 ] && echo "  - untracked: ${UNTRACKED}개"
  echo "  → 커밋을 잊지 마세요"
else
  echo ""
  echo "✓ 모든 변경이 커밋됨"
fi

# 2. 오늘의 메트릭 확인
TODAY=$(date +%Y-%m-%d)
METRICS_FILE=".claude/metrics/daily-${TODAY}.json"

if [ -f "$METRICS_FILE" ] && command -v jq &>/dev/null; then
  TOTAL_EVENTS=$(jq '.events | length' "$METRICS_FILE" 2>/dev/null || echo "0")

  if [ "$TOTAL_EVENTS" -gt 0 ] 2>/dev/null; then
    ALL_PASS=$(jq '[.events[] | select(.results.prettier == "pass" and .results.eslint == "pass" and .results.typecheck == "pass" and .results.test == "pass")] | length' "$METRICS_FILE" 2>/dev/null || echo "0")
    TS_FAIL=$(jq '[.events[] | select(.results.typecheck == "fail")] | length' "$METRICS_FILE" 2>/dev/null || echo "0")
    TEST_FAIL=$(jq '[.events[] | select(.results.test == "fail")] | length' "$METRICS_FILE" 2>/dev/null || echo "0")

    echo ""
    echo "📊 오늘의 메트릭 (${TOTAL_EVENTS} events):"
    echo "  - 전체 통과: ${ALL_PASS}/${TOTAL_EVENTS}"
    [ "$TS_FAIL" -gt 0 ] && echo "  - TypeScript 에러: ${TS_FAIL}회"
    [ "$TEST_FAIL" -gt 0 ] && echo "  - 테스트 실패: ${TEST_FAIL}회"
  else
    echo ""
    echo "📊 오늘 ${TOTAL_EVENTS}개 이벤트 기록됨"
  fi
fi

# 3. 학습 저장 제안
MEMORY_DIR=".claude/memory"
if [ -d "$MEMORY_DIR" ]; then
  PATTERNS_FILE="$MEMORY_DIR/patterns.md"
  if [ -f "$PATTERNS_FILE" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      MOD_TIME=$(stat -f %m "$PATTERNS_FILE" 2>/dev/null || echo "0")
    else
      MOD_TIME=$(stat -c %Y "$PATTERNS_FILE" 2>/dev/null || echo "0")
    fi
    PATTERNS_AGE=$(( ($(date +%s) - MOD_TIME) / 86400 ))
    if [ "$PATTERNS_AGE" -gt 7 ]; then
      echo ""
      echo "💡 patterns.md가 ${PATTERNS_AGE}일 전에 마지막 수정됨"
      echo "  → /learn save 로 새 패턴을 저장하세요"
    fi
  fi
fi

# 4. 세션 커밋 수
SESSION_COMMITS=$(git log --since="8 hours ago" --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$SESSION_COMMITS" -gt 0 ]; then
  echo ""
  echo "📝 이번 세션 커밋: ${SESSION_COMMITS}개"
fi

echo ""
echo "──────────────────────────────────────"
exit 0
