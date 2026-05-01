#!/bin/bash
set -u
# UserPromptSubmit hook: prompt 첫 단어가 /<skill_name>이면 events.jsonl에 skill_invoked 이벤트 push.
# 사용자 프로젝트의 .claude/events.jsonl을 dashboard가 tail해서 캐릭터 반응 트리거.
# 실패해도 exit 0 — 기존 워크플로우 절대 차단 X.

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$PROJECT_ROOT" ] && exit 0

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# 첫 단어 추출 (slash로 시작하는 토큰)
FIRST_WORD=$(echo "$PROMPT" | awk '{print $1}')
case "$FIRST_WORD" in
  /*) ;;       # /로 시작 → 처리 진행
  *) exit 0 ;; # 일반 prompt → skip
esac

# /<skill> 또는 /<plugin>:<skill> 형태에서 skill name 추출
SKILL_NAME="${FIRST_WORD#/}"      # 앞의 '/' 제거
# plugin:skill 형태면 skill만
case "$SKILL_NAME" in
  *:*) SKILL_NAME="${SKILL_NAME#*:}" ;;
esac

[ -z "$SKILL_NAME" ] && exit 0

EVENTS_FILE="${PROJECT_ROOT}/.claude/events.jsonl"
mkdir -p "$(dirname "$EVENTS_FILE")"

TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%S')

if command -v jq &>/dev/null; then
  EVENT=$(jq -nc \
    --arg type "skill_invoked" \
    --arg skill "$SKILL_NAME" \
    --arg ts "$TIMESTAMP" \
    '{type: $type, skill: $skill, ts: $ts}')
  echo "$EVENT" >> "$EVENTS_FILE" 2>/dev/null || true
else
  # jq 없으면 단순 echo (escape 안전 — skill name은 영문/숫자/-/_만 가정)
  printf '{"type":"skill_invoked","skill":"%s","ts":"%s"}\n' "$SKILL_NAME" "$TIMESTAMP" >> "$EVENTS_FILE" 2>/dev/null || true
fi

exit 0
