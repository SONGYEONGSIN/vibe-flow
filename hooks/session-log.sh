#!/bin/bash
# Stop hook: 세션 종료 시 작업 기록 저장 + 메트릭 요약

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

cd "$PROJECT_ROOT" || exit 0

LOG_DIR="${PROJECT_ROOT}/.claude/session-logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
LOG_FILE="${LOG_DIR}/${TIMESTAMP}.md"

# 최근 커밋 기록
RECENT_COMMITS=$(git log --oneline -5 --since="today" 2>/dev/null)

# 변경된 파일
CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null)
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)

# 당일 메트릭 요약 수집
TODAY=$(date '+%Y-%m-%d')
METRICS_FILE="${PROJECT_ROOT}/.claude/metrics/daily-${TODAY}.json"
METRICS_SUMMARY="메트릭 없음"
if [ -f "$METRICS_FILE" ] && command -v jq &>/dev/null; then
  TOTAL=$(jq '.events | length' "$METRICS_FILE" 2>/dev/null || echo "0")
  if [ "$TOTAL" -gt 0 ]; then
    ALL_PASS=$(jq '[.events[] | select(.results.prettier == "pass" and .results.eslint == "pass" and .results.typecheck == "pass" and .results.test == "pass")] | length' "$METRICS_FILE" 2>/dev/null || echo "0")
    TS_FAIL=$(jq '[.events[] | select(.results.typecheck == "fail")] | length' "$METRICS_FILE" 2>/dev/null || echo "0")
    SUCCESS_RATE=$((ALL_PASS * 100 / TOTAL))
    METRICS_SUMMARY="이벤트 ${TOTAL}개, 성공률 ${SUCCESS_RATE}%, TS에러 ${TS_FAIL}회"
  fi
fi

# 로그 파일에 비어있으면 생성 안 함
if [ -z "$RECENT_COMMITS" ] && [ -z "$CHANGED_FILES" ] && [ -z "$STAGED_FILES" ]; then
  exit 0
fi

{
  echo "# Session Log - ${TIMESTAMP}"
  echo ""
  echo "## 오늘의 커밋"
  echo "${RECENT_COMMITS:-없음}"
  echo ""
  echo "## 미커밋 변경 파일"
  echo "${CHANGED_FILES:-없음}"
  echo ""
  echo "## 스테이징된 파일"
  echo "${STAGED_FILES:-없음}"
  echo ""
  echo "## 메트릭 요약"
  echo "${METRICS_SUMMARY}"
} > "$LOG_FILE"

exit 0
