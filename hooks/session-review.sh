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

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$PROJECT_ROOT" ] && exit 0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

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

# 2. 오늘의 메트릭 확인 (SQLite 우선, JSON 폴백)
TODAY=$(date +%Y-%m-%d)
STORE_DB="${PROJECT_ROOT}/.claude/store.db"
STORE_JS="${PROJECT_ROOT}/.claude/scripts/store.js"
METRICS_FILE="${PROJECT_ROOT}/.claude/metrics/daily-${TODAY}.json"
METRICS_PRINTED=0

# SQLite 경로
if [ -f "$STORE_DB" ] && [ -f "$STORE_JS" ] && command -v node &>/dev/null && command -v jq &>/dev/null; then
  TODAY_JSON=$(node "$STORE_JS" query today 2>/dev/null)
  if [ -n "$TODAY_JSON" ]; then
    TOTAL=$(echo "$TODAY_JSON" | jq -r '.[0].total // 0' 2>/dev/null || echo "0")
    if [ "$TOTAL" -gt 0 ] 2>/dev/null; then
      PASS=$(echo "$TODAY_JSON" | jq -r '.[0].all_pass // 0')
      TS_FAIL=$(echo "$TODAY_JSON" | jq -r '.[0].ts_fail // 0')
      TEST_FAIL=$(echo "$TODAY_JSON" | jq -r '.[0].test_fail // 0')
      echo ""
      echo "📊 오늘의 메트릭 (${TOTAL} events, SQLite):"
      echo "  - 전체 통과: ${PASS}/${TOTAL}"
      [ "$TS_FAIL" -gt 0 ] && echo "  - TypeScript 에러: ${TS_FAIL}회"
      [ "$TEST_FAIL" -gt 0 ] && echo "  - 테스트 실패: ${TEST_FAIL}회"
      METRICS_PRINTED=1
    fi
  fi
fi

# JSON 폴백 (SQLite 데이터 없거나 실패 시)
if [ "$METRICS_PRINTED" = "0" ] && [ -f "$METRICS_FILE" ] && command -v jq &>/dev/null; then
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

# 3. 에러 분류 요약 (Hermes Agent error_classifier 패턴)
if [ -f "$STORE_DB" ] && [ -f "$STORE_JS" ] && command -v node &>/dev/null && command -v jq &>/dev/null; then
  ERR_CLASSES=$(node "$STORE_JS" query error-classes 1 2>/dev/null)
  if [ -n "$ERR_CLASSES" ] && [ "$ERR_CLASSES" != "[]" ]; then
    echo ""
    echo "🏷 오늘의 에러 분류:"
    echo "$ERR_CLASSES" | jq -r '.[] | "  - \(.error_class): \(.count)건 (재시도 가능: \(.retryable_count)건)"' 2>/dev/null || true
  fi
fi

# 4. 학습 저장 제안
MEMORY_DIR="${PROJECT_ROOT}/.claude/memory"
if [ -d "$MEMORY_DIR" ]; then
  PATTERNS_FILE="$MEMORY_DIR/patterns.md"
  if [ -f "$PATTERNS_FILE" ]; then
    MOD_TIME=$(get_file_mtime "$PATTERNS_FILE")
    PATTERNS_AGE=$(( ($(date +%s) - MOD_TIME) / 86400 ))
    if [ "$PATTERNS_AGE" -gt 7 ]; then
      echo ""
      echo "💡 patterns.md가 ${PATTERNS_AGE}일 전에 마지막 수정됨"
      echo "  → /learn save 로 새 패턴을 저장하세요"
    fi
  fi
fi

# 5. 세션 커밋 수
SESSION_COMMITS=$(git log --since="8 hours ago" --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$SESSION_COMMITS" -gt 0 ]; then
  echo ""
  echo "📝 이번 세션 커밋: ${SESSION_COMMITS}개"
fi

# 6. 에이전트 간 통신: 미커밋 변경이 많으면 feedback에 알림
MSG_BUS="${SCRIPT_DIR}/message-bus.sh"
if [ -f "$MSG_BUS" ] && [ "$UNCOMMITTED" -gt 5 ] 2>/dev/null; then
  bash "$MSG_BUS" send "session-review" "feedback" "request" "medium" \
    "세션 종료 — 미커밋 변경 ${UNCOMMITTED}개" \
    "커밋되지 않은 변경이 ${UNCOMMITTED}개 파일에 있습니다. 다음 세션에서 코드 리뷰를 권장합니다." >/dev/null 2>&1 || true
fi

# 7. events.jsonl 회전 (10MB 초과 시 최근 10000라인만 보관)
EVENTS_FILE="${PROJECT_ROOT}/.claude/events.jsonl"
if [ -f "$EVENTS_FILE" ]; then
  truncate_log_file "$EVENTS_FILE" 10485760 10000
fi

echo ""
echo "──────────────────────────────────────"
exit 0
