#!/bin/bash
# self-prune-smoke.sh (T7/PR-6) — 생성 스킬 저사용 은퇴 제안 (grow/prune 대칭).
# 실행: bash scripts/tests/self-prune-smoke.sh
#
# 계약: **생성 스킬**(registry 등재)만 대상 — telemetry 사용 ≤threshold면 은퇴 후보(report-only).
#       내장 45 스킬은 대상 아님(오은퇴 방지). 생성만 하면 sprawl → prune 으로 균형.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SP="$REPO_ROOT/core/skills/audit/scripts/self-prune.sh"

PASS=0; FAIL=0
field(){ printf '%s' "$1" | sed -n "s/^$2=//p"; }
setup(){
  TMP=$(mktemp -d)
  export GENERATED_REGISTRY="$TMP/gen.json"
  export EVENTS="$TMP/events.jsonl"
  export PRUNE_THRESHOLD=0
  : > "$EVENTS"
}
teardown(){ rm -rf "$TMP"; unset GENERATED_REGISTRY EVENTS PRUNE_THRESHOLD; }

echo "Test P1: 생성 스킬 0 사용 → 은퇴 후보"
setup
echo '{"skills":[{"name":"zzz-unused","created_round":"P"}]}' > "$GENERATED_REGISTRY"
out=$(bash "$SP" 2>/dev/null)
echo "$(field "$out" RETIRE_CANDIDATES)" | grep -q "zzz-unused" && { echo "  ✓ P1.1 zzz-unused 은퇴 후보"; PASS=$((PASS+1)); } || { echo "  ✗ P1.1 (got '$out')"; FAIL=$((FAIL+1)); }
teardown

echo "Test P2: 사용된 생성 스킬 → 은퇴 후보 아님"
setup
echo '{"skills":[{"name":"zzz-used","created_round":"P"}]}' > "$GENERATED_REGISTRY"
printf '{"type":"skill_invoked","skill":"zzz-used","ts":"2026-07-25T00:00:00Z"}\n' > "$EVENTS"
out=$(bash "$SP" 2>/dev/null)
echo "$(field "$out" RETIRE_CANDIDATES)" | grep -q "zzz-used" && { echo "  ✗ P2.1 사용됐는데 은퇴 후보"; FAIL=$((FAIL+1)); } || { echo "  ✓ P2.1 사용 스킬 제외"; PASS=$((PASS+1)); }
teardown

echo "Test P3: 빈 registry → 후보 0 (내장 스킬 미대상)"
setup
echo '{"skills":[]}' > "$GENERATED_REGISTRY"
out=$(bash "$SP" 2>/dev/null)
[ "$(field "$out" COUNT)" = "0" ] && { echo "  ✓ P3.1 후보 0"; PASS=$((PASS+1)); } || { echo "  ✗ P3.1 COUNT=$(field "$out" COUNT)"; FAIL=$((FAIL+1)); }
teardown

echo "Test P4: registry 부재 → 안전(후보 0, exit 0)"
setup
rm -f "$GENERATED_REGISTRY"
bash "$SP" >/dev/null 2>&1; ec=$?
[ "$ec" = "0" ] && { echo "  ✓ P4.1 registry 부재 exit 0"; PASS=$((PASS+1)); } || { echo "  ✗ P4.1 exit $ec"; FAIL=$((FAIL+1)); }
teardown

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
