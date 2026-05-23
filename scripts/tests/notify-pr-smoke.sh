#!/bin/bash
# core/skills/auto-build/scripts/notify-pr.sh smoke (Phase 3.1 PR-C4)
# 실행: bash scripts/tests/notify-pr-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NOTIFY="$REPO_ROOT/core/skills/auto-build/scripts/notify-pr.sh"

PASS=0
FAIL=0

assert_contains() {
  local name="$1" pattern="$2" actual="$3"
  if echo "$actual" | grep -qE "$pattern"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    pattern: '$pattern'"
    echo "    actual:  '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✓ $name (exit $expected)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# ── Test N1: DRYRUN basic — "would notify" stdout ──────────
echo "Test N1: notify-pr.sh DRYRUN basic"
OUT=$(NOTIFY_PR_DRYRUN=1 bash "$NOTIFY" "https://github.com/test/repo/pull/123" 2>&1)
EC=$?
assert_exit "N1.1 DRYRUN exit 0" 0 "$EC"
assert_contains "N1.1 stdout 'would notify'" "would notify" "$OUT"
assert_contains "N1.1 PR URL echoed" "github.com/test/repo/pull/123" "$OUT"

# ── Test N2: R10 cost threshold warning ────────────────────
echo "Test N2: cost threshold warning"
# 50000 임계값 초과 (60000) → stderr "cost ... > threshold"
OUT=$(NOTIFY_PR_DRYRUN=1 bash "$NOTIFY" "https://github.com/test/repo/pull/123" 60000 2>&1)
EC=$?
assert_exit "N2.1 cost > threshold exit 0 (warning only)" 0 "$EC"
assert_contains "N2.1 stderr 'cost ... > threshold'" "cost 60000 tokens > threshold 50000" "$OUT"

# 임계값 미만 (10000) → warning 없음
OUT=$(NOTIFY_PR_DRYRUN=1 bash "$NOTIFY" "https://github.com/test/repo/pull/123" 10000 2>&1)
if ! echo "$OUT" | grep -q "R10 cost warning"; then
  echo "  ✓ N2.2 cost < threshold no warning"
  PASS=$((PASS + 1))
else
  echo "  ✗ N2.2 unexpected warning at cost=10000"
  FAIL=$((FAIL + 1))
fi

# ── Test N3: webhook optional (DRYRUN skip POST) ───────────
echo "Test N3: webhook optional"
OUT=$(NOTIFY_PR_DRYRUN=1 NOTIFY_WEBHOOK_URL="https://discord.test/webhook/abc" \
  bash "$NOTIFY" "https://github.com/test/repo/pull/123" 2>&1)
assert_contains "N3.1 stdout 'webhook: ...'" "webhook: https://discord.test" "$OUT"
assert_contains "N3.1 'DRYRUN — POST skipped'" "DRYRUN.*POST skipped" "$OUT"

# 옵션 webhook 미설정 시 webhook line 없음
OUT=$(NOTIFY_PR_DRYRUN=1 bash "$NOTIFY" "https://github.com/test/repo/pull/123" 2>&1)
if ! echo "$OUT" | grep -q "webhook"; then
  echo "  ✓ N3.2 no webhook when URL unset"
  PASS=$((PASS + 1))
else
  echo "  ✗ N3.2 unexpected webhook line"
  FAIL=$((FAIL + 1))
fi

# ── 결과 ───────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"

if [ "$FAIL" -eq 0 ]; then
  echo "✓ ALL TESTS PASSED"
  exit 0
else
  echo "✗ SOME TESTS FAILED"
  exit 1
fi
