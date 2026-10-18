#!/bin/bash
set -u
# self-prune.sh — 생성 스킬 저사용 은퇴 제안 (T7/PR-6, grow/prune 대칭).
#
# 생성 트랙이 스킬을 만들기만 하면 sprawl(45→비대)로 자멸한다. 본 스크립트는 반대 방향:
# **생성된 스킬**(generated-skills registry 등재분) 중 telemetry 사용 ≤threshold 인 것을
# 은퇴 후보로 보고한다(report-only — 실 은퇴는 사람/gated). Karpathy §5(노이즈 제거) 정합.
#
# **내장 45 스킬은 대상 아님** — registry 등재된 생성분만(오은퇴 방지).
#
# env: GENERATED_REGISTRY(기본 .claude/generated-skills.json) / EVENTS(기본 .claude/events.jsonl)
#      PRUNE_THRESHOLD(기본 0) / PRUNE_PERIOD_DAYS(기본 30, 현재 all-time 근사)
# 출력: RETIRE_CANDIDATES=<comma> COUNT=n (report-only). exit 0.

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REG="${GENERATED_REGISTRY:-$ROOT/.claude/generated-skills.json}"
EV="${EVENTS:-$ROOT/.claude/events.jsonl}"
TH="${PRUNE_THRESHOLD:-0}"

if [ ! -f "$REG" ]; then
  echo "RETIRE_CANDIDATES="; echo "COUNT=0"
  echo "[self-prune] generated-skills registry 부재 — 은퇴 대상 없음(생성 스킬 0)" >&2
  exit 0
fi

names=$(jq -r '.skills[]?.name // empty' "$REG" 2>/dev/null)
cands=""
for n in $names; do
  if [ -f "$EV" ]; then
    used=$(jq -r --arg n "$n" \
      'select((.type=="skill_invoked" or .type=="skill_invoked_auto") and .skill==$n) | .skill' \
      "$EV" 2>/dev/null | grep -c .)
  else
    used=0
  fi
  if [ "$used" -le "$TH" ] 2>/dev/null; then
    cands="${cands:+$cands,}$n"
  fi
done

cnt=0; [ -n "$cands" ] && cnt=$(printf '%s' "$cands" | tr ',' '\n' | grep -c .)
echo "RETIRE_CANDIDATES=$cands"
echo "COUNT=$cnt"
[ "$cnt" -gt 0 ] && echo "[self-prune] 은퇴 후보 $cnt: $cands (사용 ≤$TH). 실 은퇴는 사람 검토 — grow/prune 균형." >&2
exit 0
