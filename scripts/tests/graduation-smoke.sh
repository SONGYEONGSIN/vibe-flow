#!/bin/bash
# graduation-smoke.sh (T6/PR-5) — auto-merge tier graduation 상태기계 + circuit breaker.
# 실행: bash scripts/tests/graduation-smoke.sh
#
# 계약: disarmed 기본(off). arm 후 각 tier M(=3)밤 클린 → 다음 tier 개방.
#       health regressed → breaker trip(off 복귀, reset 필요). 격리 상태파일로 테스트.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GR="$REPO_ROOT/core/skills/audit/scripts/graduation.sh"

PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ✗ $1 (got '$2')"; FAIL=$((FAIL+1)); }
setup(){ TMP=$(mktemp -d); export GRADUATION_STATE="$TMP/grad.json"; export GRADUATION_M=3; }
teardown(){ rm -rf "$TMP"; unset GRADUATION_STATE GRADUATION_M; }
g(){ bash "$GR" "$@" 2>/dev/null; }

echo "Test GR1: 기본 disarmed → tier=off"
setup
t=$(g tier); [ "$t" = "off" ] && ok "GR1.1 초기 tier=off" || ng "GR1.1" "$t"
teardown

echo "Test GR2: arm 해도 아직 off (graduated 없음)"
setup
g arm >/dev/null; t=$(g tier)
[ "$t" = "off" ] && ok "GR2.1 arm 직후 tier=off" || ng "GR2.1" "$t"
teardown

echo "Test GR3: arm + clean×3 → docs 개방"
setup
g arm >/dev/null; g tick clean >/dev/null; g tick clean >/dev/null
t2=$(g tier); [ "$t2" = "off" ] && ok "GR3.1 clean×2 아직 off" || ng "GR3.1" "$t2"
g tick clean >/dev/null
t3=$(g tier); [ "$t3" = "docs" ] && ok "GR3.2 clean×3 → docs 개방" || ng "GR3.2" "$t3"
teardown

echo "Test GR4: docs→structural→generative 전체 사다리"
setup
g arm >/dev/null
for i in 1 2 3; do g tick clean >/dev/null; done   # → docs
for i in 1 2 3; do g tick clean >/dev/null; done   # → structural
ts=$(g tier); [ "$ts" = "structural" ] && ok "GR4.1 6 clean → structural" || ng "GR4.1" "$ts"
for i in 1 2 3; do g tick clean >/dev/null; done   # → generative
tg=$(g tier); [ "$tg" = "generative" ] && ok "GR4.2 9 clean → generative" || ng "GR4.2" "$tg"
# generative 에서 더 clean → 유지(초과 승급 없음)
g tick clean >/dev/null; g tick clean >/dev/null; g tick clean >/dev/null
tc=$(g tier); [ "$tc" = "generative" ] && ok "GR4.3 최상위 유지(초과 없음)" || ng "GR4.3" "$tc"
teardown

echo "Test GR5: circuit breaker — regressed → trip(off), reset 필요"
setup
g arm >/dev/null; for i in 1 2 3; do g tick clean >/dev/null; done  # docs
g tick regressed >/dev/null
tr=$(g tier); [ "$tr" = "off" ] && ok "GR5.1 regressed → tier=off(freeze)" || ng "GR5.1" "$tr"
st=$(g status); echo "$st" | grep -qi 'tripped.*true\|"tripped": true' && ok "GR5.2 tripped=true" || ng "GR5.2" "$st"
# tripped 상태에서 clean tick → no-op(여전히 off)
g tick clean >/dev/null; g tick clean >/dev/null; g tick clean >/dev/null
tt=$(g tier); [ "$tt" = "off" ] && ok "GR5.3 tripped 중 clean 무시(off 유지)" || ng "GR5.3" "$tt"
teardown

echo "Test GR6: reset → 재시작 가능"
setup
g arm >/dev/null; for i in 1 2 3; do g tick clean >/dev/null; done; g tick regressed >/dev/null  # tripped
g reset >/dev/null
st=$(g status); echo "$st" | grep -qi '"tripped": false\|tripped.*false' && ok "GR6.1 reset → tripped=false" || ng "GR6.1" "$st"
# reset 후 다시 clean×3 → docs 재개방 (armed 유지)
g tick clean >/dev/null; g tick clean >/dev/null; g tick clean >/dev/null
tre=$(g tier); [ "$tre" = "docs" ] && ok "GR6.2 reset 후 재graduation" || ng "GR6.2" "$tre"
teardown

echo "Test GR7: disarm → off 복귀"
setup
g arm >/dev/null; for i in 1 2 3; do g tick clean >/dev/null; done  # docs
g disarm >/dev/null
td=$(g tier); [ "$td" = "off" ] && ok "GR7.1 disarm → tier=off" || ng "GR7.1" "$td"
teardown

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
