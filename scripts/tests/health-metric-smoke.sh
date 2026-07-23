#!/bin/bash
# health-metric.sh smoke test (T2/PR-1)
# 실행: bash scripts/tests/health-metric-smoke.sh
# 검증: 3-지표 JSON 을 exit0 으로 출력 (circuit breaker 입력 계약).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/core/skills/audit/scripts/health-metric.sh"

PASS=0
FAIL=0
chk() { if [ "$2" = "$3" ]; then echo "  ✓ $1"; PASS=$((PASS+1)); else echo "  ✗ $1 (expected '$3', got '$2')"; FAIL=$((FAIL+1)); fi; }

echo "Test H1: 3-지표 JSON 출력 + exit0"
OUT=$(bash "$SCRIPT" 2>/dev/null); EC=$?
chk "H1.1 exit 0" "$EC" 0

KEYS=$(printf '%s' "$OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(sorted(d.keys())))" 2>/dev/null)
chk "H1.2 3 지표 키 존재" "$KEYS" "ci_pass_rate,ledger_health,safetycore_checksum"

VALID=$(printf '%s' "$OUT" | python3 -c "import sys,json; json.load(sys.stdin); print('yes')" 2>/dev/null)
chk "H1.3 유효 JSON" "$VALID" "yes"

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
