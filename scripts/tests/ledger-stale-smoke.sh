#!/bin/bash
# ledger.sh stale smoke — 오래된 open finding 재검토 워크리스트 (audit F-AJ01)
# 실행: bash scripts/tests/ledger-stale-smoke.sh
#
# 왜: Phase 1 VERIFY 는 `status=fixed` 만 본다(pending-verify). **open 은 재검토 경로가
# 없다** — 한 번 등록되면 누가 집지 않는 한 영원히 open 이다. 실측(09-12): open 161건 중
# 89건이 R~Z(한 달 이상)이고, 발굴 78 대 소비 14(최근 9라운드)로 순증한다.
#
# 기계적 일괄 폐기는 금지다. 같은 날 시도한 선별이 evidence 경로 미해석 20건을
# "파일 삭제됨=폐기"로 오독할 뻔했다(실제로는 `telemetry/SKILL.md` 처럼 접두사 누락).
# 그래서 stale 은 **판정하지 않고 워크리스트만 낸다** — 판정은 증거를 본 뒤에 한다.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LEDGER_SH="$REPO_ROOT/core/skills/audit/scripts/ledger.sh"
PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS+1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
L="$TMP/l.jsonl"
add() { printf '{"round":"%s","id":"%s","component":"skills","dimension":"D1","evidence":"e","root_cause":"r","fix":"f","predicted_delta":"+0.1","status":"%s","actual_delta":null,"ts":"%s"}\n' "$1" "$2" "$3" "$4" >> "$L"; }
: > "$L"
add R F-R01 open     2026-08-05T00:00:00Z
add S F-S01 open     2026-08-07T00:00:00Z
add Z F-Z01 verified 2026-08-18T00:00:00Z
add AI F-AI01 open   2026-09-09T00:00:00Z

echo "Test ST1: open 만, 오래된 순"
out=$(LEDGER="$L" bash "$LEDGER_SH" stale 2 2>/dev/null)
first=$(printf '%s' "$out" | head -1 | cut -f1)
[ "$first" = "F-R01" ] && ok "ST1.1 가장 오래된 open 이 먼저" || ng "ST1.2 '$first' (want F-R01)"
printf '%s' "$out" | grep -q 'F-Z01' && ng "ST1.3 verified 가 섞였다" || ok "ST1.4 종결 상태 제외"

echo "Test ST2: 개수 상한"
n=$(LEDGER="$L" bash "$LEDGER_SH" stale 2 2>/dev/null | grep -c .)
[ "$n" = "2" ] && ok "ST2.1 요청한 2건만" || ng "ST2.2 ${n}건 — 상한 없으면 Phase 1 을 삼킨다(F-AE01 교훈)"

echo "Test ST3: 판정하지 않는다 (상태 무변경)"
before=$(md5 -q "$L" 2>/dev/null || md5sum "$L" | cut -d' ' -f1)
LEDGER="$L" bash "$LEDGER_SH" stale 2 >/dev/null 2>&1
after=$(md5 -q "$L" 2>/dev/null || md5sum "$L" | cut -d' ' -f1)
[ "$before" = "$after" ] && ok "ST3.1 원장 무변경 — 워크리스트만" \
  || ng "ST3.2 원장이 바뀌었다 — 일괄 폐기 위험"

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
