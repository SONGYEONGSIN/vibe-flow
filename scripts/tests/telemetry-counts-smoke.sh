#!/bin/bash
# telemetry SKILL.md — events-source 집계 정확도 smoke test (audit round 7, F-G04)
#
# 두 결함 회귀 방지:
#  ① from_entries idiom: `map({type,count}) | from_entries` 는 from_entries 가
#     key/value 키만 인식 → "null object key" 에러 → `|| echo {}` 폴백으로
#     COUNTS 가 항상 빈 객체였음(Top5/Total 무력화). `map({(.k): v}) | add` 로 수정.
#  ② noise 제외: memory_sync_triggered/tool_failure/tool_result 는 hook 부산물이라
#     집계에서 제외해야 Top5/Total 이 실 사용량을 반영.
#
# 실행: bash scripts/tests/telemetry-counts-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$REPO_ROOT/core/skills/telemetry/SKILL.md"

PASS=0
FAIL=0

ok()  { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng()  { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

# ── fixture events.jsonl ──
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
EVENTS="$TMP/events.jsonl"
D="2026-06-01T00:00:00Z"     # window 시작
cat > "$EVENTS" <<'EOF'
{"ts":"2026-06-10T01:00:00Z","type":"brainstorm"}
{"ts":"2026-06-10T02:00:00Z","type":"brainstorm"}
{"ts":"2026-06-11T01:00:00Z","type":"brainstorm"}
{"ts":"2026-06-11T02:00:00Z","type":"agent_invoked"}
{"ts":"2026-06-12T03:00:00Z","type":"agent_invoked"}
{"ts":"2026-06-10T01:00:00Z","type":"memory_sync_triggered"}
{"ts":"2026-06-10T01:00:00Z","type":"memory_sync_triggered"}
{"ts":"2026-06-10T01:00:00Z","type":"tool_failure"}
{"ts":"2026-05-01T00:00:00Z","type":"brainstorm"}
EOF

NOISE_TYPES='["memory_sync_triggered","tool_failure","tool_result"]'

# 교정된 idiom (SKILL.md 와 동일) — noise 제외 + add
COUNTS=$(jq -s --arg d "$D" --argjson noise "$NOISE_TYPES" \
  'map(select(.ts > $d and (.type as $t | ($noise | index($t)) == null))) | group_by(.type) | map({(.[0].type): length}) | add // {}' \
  "$EVENTS")
TOTAL=$(echo "$COUNTS" | jq -r 'to_entries | map(.value) | add // 0')

echo "=== telemetry 집계 정확도 (F-G04) ==="
# ① COUNTS 가 비어있지 않음 (from_entries 폴백 회귀 차단)
[ "$(echo "$COUNTS" | jq 'length')" -gt 0 ] && ok "COUNTS non-empty (from_entries 폴백 회귀 없음)" || ng "COUNTS 빈 객체 — from_entries idiom 깨짐"
# ② window 내 brainstorm 3건 (window 밖 1건 제외)
[ "$(echo "$COUNTS" | jq -r '.brainstorm // 0')" = "3" ] && ok "brainstorm=3 (window 경계 정확)" || ng "brainstorm count 틀림"
# ③ 계측 타입 agent_invoked 2건 surface
[ "$(echo "$COUNTS" | jq -r '.agent_invoked // 0')" = "2" ] && ok "agent_invoked=2 (계측 타입 가시화)" || ng "agent_invoked 누락"
# ④ noise 타입 제외 (memory_sync_triggered/tool_failure 0)
[ "$(echo "$COUNTS" | jq -r 'has("memory_sync_triggered")')" = "false" ] && ok "memory_sync_triggered 제외" || ng "noise 미제외"
# ⑤ TOTAL = 5 (3 brainstorm + 2 agent_invoked, noise 3건 제외)
[ "$TOTAL" = "5" ] && ok "TOTAL=5 (noise 제외 합산)" || ng "TOTAL 틀림 (got $TOTAL, want 5)"

# ── F-M05 (audit R13): per-skill/agent 재키잉 집계 ──
# hook(tool-invocation-tracker)이 기록하는 .skill/.agent 를 소비자가 미참조해
# 45 스킬이 '스킬(자동)' 단일 버킷으로 붕괴하던 dead write 회귀 차단.
EVENTS2="$TMP/events2.jsonl"
cat > "$EVENTS2" <<'EOF'
{"ts":"2026-06-10T01:00:00Z","type":"skill_invoked_auto","skill":"audit"}
{"ts":"2026-06-10T02:00:00Z","type":"skill_invoked_auto","skill":"audit"}
{"ts":"2026-06-10T03:00:00Z","type":"skill_invoked","skill":"release"}
{"ts":"2026-06-10T04:00:00Z","type":"agent_invoked","agent":"runner"}
{"ts":"2026-06-10T05:00:00Z","type":"agent_invoked"}
{"ts":"2026-06-10T06:00:00Z","type":"brainstorm"}
EOF

# 재키잉 idiom (SKILL.md 와 동일)
JQ_KEY='def key: (.type as $t
  | if ($t == "skill_invoked" or $t == "skill_invoked_auto") and ((.skill // "") != "") then .skill
    elif $t == "agent_invoked" and ((.agent // "") != "") then "agent:" + .agent
    else $t end);'
COUNTS2=$(jq -s --arg d "$D" --argjson noise "$NOISE_TYPES" \
  "$JQ_KEY"'map(select(.ts > $d and (.type as $t | ($noise | index($t)) == null))) | group_by(key) | map({(.[0] | key): length}) | add // {}' \
  "$EVENTS2")

echo "=== per-skill/agent 재키잉 (F-M05) ==="
[ "$(echo "$COUNTS2" | jq -r '.audit // 0')" = "2" ] && ok "skill_invoked_auto → named key audit=2" || ng "named skill 키 부재"
[ "$(echo "$COUNTS2" | jq -r '.release // 0')" = "1" ] && ok "skill_invoked → named key release=1" || ng "release 키 부재"
[ "$(echo "$COUNTS2" | jq -r '."agent:runner" // 0')" = "1" ] && ok "agent_invoked → agent:runner=1" || ng "agent:runner 키 부재"
[ "$(echo "$COUNTS2" | jq -r '.agent_invoked // 0')" = "1" ] && ok ".agent 부재 이벤트는 type 폴백" || ng "type 폴백 깨짐"
[ "$(echo "$COUNTS2" | jq -r 'has("skill_invoked_auto")')" = "false" ] && ok "generic 버킷 소멸 (.skill 있는 이벤트)" || ng "generic 버킷 잔존"

# ── 소스 가드: SKILL.md 가 깨진 idiom 을 재도입하지 않았는지 ──
echo "=== SKILL.md 소스 가드 ==="
if grep -q 'count: length}) | from_entries' "$SKILL"; then
  ng "SKILL.md 에 깨진 from_entries idiom 재발"
else
  ok "SKILL.md 깨진 from_entries idiom 없음"
fi
grep -q 'NOISE_TYPES=' "$SKILL" && ok "SKILL.md noise 필터 존재" || ng "SKILL.md NOISE_TYPES 누락"
# F-M05/F-M06 (audit R13): 재키잉 집계 + 스킬 유니버스 동적 유도가 SKILL.md 에 반영됐는지
grep -q 'group_by(key)' "$SKILL" && ok "SKILL.md 재키잉 집계 (F-M05)" || ng "SKILL.md 가 group_by(.type) 단독 — per-skill dead write (F-M05)"
grep -q 'EVENT_ALIAS_TYPES' "$SKILL" && ok "SKILL.md 스킬 유니버스 동적 유도 (F-M06)" || ng "SKILL.md SKILL_TYPES 하드코딩 잔존 (F-M06)"
grep -q '27 스킬' "$SKILL" && ng "SKILL.md '27 스킬' 하드코딩 카탈로그 주석 잔존 (F-M06)" || ok "하드코딩 카탈로그 주석 제거 (F-M06)"

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
