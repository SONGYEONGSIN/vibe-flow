#!/bin/bash
set -uo pipefail
# persona-vote.sh — auto-build Phase 2 ambiguity 자동 결정
#
# 사용법:
#   persona-vote.sh <category> <question>
#
# 동작:
#   1. data/persona-mapping.json 에서 카테고리 → persona 풀 추출
#   2. 각 persona 별 stdout 라인 출력 — orchestrator가 실제 Agent tool dispatch
#      형식: AGENT_DISPATCH:<persona-id>:<question>
#   3. 마지막 라인 — moderator 중재 dispatch
#      형식: MODERATOR_DISPATCH:moderator:<question>:<vote-results-placeholder>
#   4. AUTO_BUILD_RUN_ID env가 set이면 run-log.sh로 jsonl 이벤트 기록
#
# Exit codes:
#   0 — 정상 dispatch 명령 출력
#   1 — usage 오류 (인자 부족)
#   2 — 의존성 부재 (jq, mapping.json)
#   3 — 알 수 없는 카테고리

usage() {
  echo "Usage: $0 <category> <question>" >&2
  echo "  category: design | auth | perf | architecture | ui | test | docs" >&2
  echo "  question: ambiguity 결정 질문 (인용 부호 포함)" >&2
  exit 1
}

[ $# -lt 2 ] && usage

CATEGORY="$1"
QUESTION="$2"

# 의존성 검증
command -v jq >/dev/null 2>&1 || { echo "[persona-vote] jq 부재" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAPPING_FILE="${SCRIPT_DIR}/../data/persona-mapping.json"
[ -f "$MAPPING_FILE" ] || { echo "[persona-vote] persona-mapping.json 부재: $MAPPING_FILE" >&2; exit 2; }

# 카테고리 매핑 추출
PERSONAS=$(jq -r --arg cat "$CATEGORY" '.[$cat] // empty | .[]' "$MAPPING_FILE" 2>/dev/null)
if [ -z "$PERSONAS" ]; then
  echo "[persona-vote] unknown_category: $CATEGORY" >&2
  echo "[persona-vote] 가능 카테고리: $(jq -r 'keys | map(select(startswith("_") | not)) | join(", ")' "$MAPPING_FILE")" >&2
  exit 3
fi

MODERATOR=$(jq -r '._moderator // "moderator"' "$MAPPING_FILE")
PERSONA_COUNT=$(echo "$PERSONAS" | wc -l | tr -d ' ')

# Question truncate (jsonl event용 80자, dispatch 라인은 full)
Q_TRUNC=$(echo "$QUESTION" | head -c 80)

# Prompt template — agent의 자율 부산물 / 스킬 트리거 회피용 (F4)
# orchestrator는 각 AGENT_DISPATCH 라인을 실제 Agent 호출로 변환할 때 본 template 사용
cat <<'PROMPT_TEMPLATE_END'
# === VOTE PROMPT TEMPLATE ===
# [VOTE-ONLY MODE — 자율 스킬 트리거 / 부산물 작업 금지]
#
# 답변은 정확히 다음 4 라인 형식으로만 출력:
#   DECISION: <옵션 1자 — A/B/C 등 brainstorm spec 대안 ID>
#   CONFIDENCE: <0.0~1.0>
#   REASON: <한 문장 50자 이내>
#   PERSONA: <persona id>
#
# ⚠️ 4 라인 외 분석/설명/부산물/자동 스킬 발동 금지.
# === END TEMPLATE ===
PROMPT_TEMPLATE_END

# AGENT_DISPATCH 라인 출력 (각 persona별)
while IFS= read -r persona; do
  [ -z "$persona" ] && continue
  echo "AGENT_DISPATCH:${persona}:${QUESTION}"
done <<< "$PERSONAS"

# MODERATOR_DISPATCH 라인 (마지막)
echo "MODERATOR_DISPATCH:${MODERATOR}:${QUESTION}:<vote-results-placeholder>"

# jsonl 이벤트 기록 (AUTO_BUILD_RUN_ID env가 set일 때만)
if [ -n "${AUTO_BUILD_RUN_ID:-}" ]; then
  RUN_LOG="${SCRIPT_DIR}/run-log.sh"
  if [ -f "$RUN_LOG" ]; then
    bash "$RUN_LOG" start "$AUTO_BUILD_RUN_ID" \
      phase=vote \
      category="$CATEGORY" \
      personas="$PERSONA_COUNT" \
      question="$Q_TRUNC" 2>/dev/null || true
  fi
fi

exit 0
