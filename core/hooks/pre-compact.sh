#!/bin/bash
set -u
# PreCompact hook: 컨텍스트 압축 전 중요 정보를 보존한다.
# 압축 시 손실될 수 있는 진행 상황, 결정 사항을 additionalContext로 재주입.

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$PROJECT_ROOT" ] && exit 0

CONTEXT=""

# 현재 브랜치 + 최근 커밋 요약
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
RECENT=$(git log --oneline -3 2>/dev/null || echo "")
if [ -n "$RECENT" ]; then
  CONTEXT="${CONTEXT}[현재 브랜치: ${BRANCH}] 최근 커밋:\n${RECENT}\n\n"
fi

# 미커밋 변경 파일 목록
UNCOMMITTED=$(git diff --name-only 2>/dev/null)
STAGED=$(git diff --cached --name-only 2>/dev/null)
if [ -n "$UNCOMMITTED" ] || [ -n "$STAGED" ]; then
  CONTEXT="${CONTEXT}[미커밋 변경]: ${UNCOMMITTED} ${STAGED}\n\n"
fi

# 오늘의 메트릭 요약 (있으면)
DATE=$(date +%Y-%m-%d)
METRICS_FILE="${PROJECT_ROOT}/.claude/metrics/daily-${DATE}.json"
if [ -f "$METRICS_FILE" ]; then
  EVENT_COUNT=$(jq '.events | length' "$METRICS_FILE" 2>/dev/null || echo "0")
  FAIL_COUNT=$(jq '[.events[] | select(.result == "FAIL" or .type == "tool_failure")] | length' "$METRICS_FILE" 2>/dev/null || echo "0")
  CONTEXT="${CONTEXT}[오늘 메트릭] 이벤트: ${EVENT_COUNT}, 실패: ${FAIL_COUNT}\n"
fi

if [ -n "$CONTEXT" ]; then
  # JSON으로 additionalContext 출력
  ESCAPED=$(echo -e "$CONTEXT" | jq -Rs .)
  echo "{\"additionalContext\": ${ESCAPED}}"
fi

exit 0
