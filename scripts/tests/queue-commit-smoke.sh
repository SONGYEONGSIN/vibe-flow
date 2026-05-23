#!/bin/bash
# core/skills/auto-build/scripts/queue-commit.sh smoke (Phase 3.1 PR-C3)
# 실행: bash scripts/tests/queue-commit-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
QUEUE_COMMIT="$REPO_ROOT/core/skills/auto-build/scripts/queue-commit.sh"

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

# ── Test Q1: DRYRUN echo only ──────────────────────────────
echo "Test Q1: queue-commit.sh DRYRUN echo"
OUT=$(QUEUE_COMMIT_DRYRUN=1 bash "$QUEUE_COMMIT" 2>&1)
EC=$?
assert_exit "Q1.1 DRYRUN exit 0" 0 "$EC"
assert_contains "Q1.2 stderr 'would commit'" "would commit" "$OUT"

# ── Test Q2: queue.jsonl 부재 시 graceful skip ─────────────
echo "Test Q2: queue.jsonl 부재 handling"
TMP=$(mktemp -d)
NONEXISTENT="$TMP/no-such-queue.jsonl"
# QUEUE_STORE을 존재 안 하는 경로로 설정
OUT=$(QUEUE_STORE="$NONEXISTENT" QUEUE_COMMIT_DRYRUN=1 bash "$QUEUE_COMMIT" 2>&1)
EC=$?
assert_exit "Q2.1 부재 시 exit 0 (graceful)" 0 "$EC"
assert_contains "Q2.1 stderr '부재 — skip'" "부재.*skip" "$OUT"
rm -rf "$TMP"

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
