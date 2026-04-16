#!/bin/bash
set -u
# model-suggest.sh — Notification 훅: 스마트 모델 라우팅 제안
#
# Hermes Agent smart_model_routing 패턴 적용.
# events.jsonl에서 최근 N개 상호작용 패턴을 분석하여
# 모델 전환을 additionalContext로 제안한다.
# 비차단 권고만 — 자동 전환하지 않음.

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$PROJECT_ROOT" ] && exit 0

EVENTS_FILE="${PROJECT_ROOT}/.claude/events.jsonl"
[ -f "$EVENTS_FILE" ] || exit 0
command -v jq &>/dev/null || exit 0

# 최근 10개 이벤트 분석
WINDOW=10
RECENT=$(tail -n "$WINDOW" "$EVENTS_FILE" 2>/dev/null)
[ -z "$RECENT" ] && exit 0

# 복잡도 신호 계산
FAILURE_COUNT=$(echo "$RECENT" | jq -r 'select(.type == "tool_failure") | .type' 2>/dev/null | wc -l | tr -d ' ')
UNIQUE_FILES=$(echo "$RECENT" | jq -r '.file // empty' 2>/dev/null | grep -v '^$' | sort -u | wc -l | tr -d ' ')
ERROR_TYPES=$(echo "$RECENT" | jq -r 'select(.error_class != null) | .error_class' 2>/dev/null | sort -u | wc -l | tr -d ' ')
FAIL_EVENTS=$(echo "$RECENT" | jq -r 'select(.status == "fail") | .status' 2>/dev/null | wc -l | tr -d ' ')

# 임계값
SIMPLE_THRESHOLD=1
COMPLEX_THRESHOLD_FAILS=3
COMPLEX_THRESHOLD_FILES=5

SUGGESTION=""

if [ "$FAILURE_COUNT" -eq 0 ] && [ "$FAIL_EVENTS" -eq 0 ] && [ "$UNIQUE_FILES" -le "$SIMPLE_THRESHOLD" ]; then
  SUGGESTION="최근 ${WINDOW}개 상호작용이 단순 패턴입니다 (실패 0, 파일 ${UNIQUE_FILES}개). /model sonnet 또는 /model haiku로 전환하면 비용을 절약할 수 있습니다."
elif [ "$FAILURE_COUNT" -ge "$COMPLEX_THRESHOLD_FAILS" ] || [ "$UNIQUE_FILES" -ge "$COMPLEX_THRESHOLD_FILES" ] || [ "$ERROR_TYPES" -ge 2 ]; then
  SUGGESTION="복잡한 패턴 감지됨 (실패 ${FAILURE_COUNT}회, 파일 ${UNIQUE_FILES}개, 에러유형 ${ERROR_TYPES}종). /model opus 사용을 권장합니다."
fi

# 디바운스: 마지막 제안으로부터 15분 이내면 스킵
DEBOUNCE_FILE="${PROJECT_ROOT}/.claude/messages/.last-model-suggest"
if [ -n "$SUGGESTION" ] && [ -f "$DEBOUNCE_FILE" ]; then
  LAST=$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo "0")
  NOW=$(date +%s)
  DIFF=$((NOW - LAST))
  [ "$DIFF" -lt 900 ] && exit 0
fi

if [ -n "$SUGGESTION" ]; then
  # 디바운스 타임스탬프 기록
  mkdir -p "$(dirname "$DEBOUNCE_FILE")" 2>/dev/null
  date +%s > "$DEBOUNCE_FILE" 2>/dev/null || true

  # additionalContext로 제안 출력
  jq -n --arg msg "[model-suggest] $SUGGESTION" '{additionalContext: $msg}' 2>/dev/null || true
fi

exit 0
