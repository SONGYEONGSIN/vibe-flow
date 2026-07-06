#!/bin/bash
# extensions/design-system/skills/frontend-flow/scripts/preflight-deps.sh smoke
# 실행: bash scripts/tests/frontend-flow-preflight-smoke.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/extensions/design-system/skills/frontend-flow/scripts/preflight-deps.sh"
PASS=0; FAIL=0

assert_contains() {
  if echo "$3" | grep -qE "$2"; then echo "  ✓ $1"; PASS=$((PASS+1));
  else echo "  ✗ $1"; echo "    pattern: '$2'"; echo "    actual:  '$3'"; FAIL=$((FAIL+1)); fi
}
assert_exit() {
  if [ "$3" = "$2" ]; then echo "  ✓ $1 (exit $2)"; PASS=$((PASS+1));
  else echo "  ✗ $1 (expected $2, got $3)"; FAIL=$((FAIL+1)); fi
}

echo "Test P1: 모든 의존성 존재 → exit 0"
OUT=$(FRONTEND_FLOW_DEPS="jq" bash "$SCRIPT" 2>&1); EC=$?
assert_exit "present-exit" "0" "$EC"
assert_contains "present-msg" "의존성 OK" "$OUT"

echo "Test P2: 누락 의존성 → exit 1 + 안내"
OUT=$(FRONTEND_FLOW_DEPS="jq __nope_missing_cmd__" bash "$SCRIPT" 2>&1); EC=$?
assert_exit "missing-exit" "1" "$EC"
assert_contains "missing-msg" "의존성 누락" "$OUT"
assert_contains "missing-name" "__nope_missing_cmd__" "$OUT"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
