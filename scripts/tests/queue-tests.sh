#!/bin/bash
# core/skills/auto-build/scripts/queue.sh 단위 테스트
# 실행: bash scripts/tests/queue-tests.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
QUEUE="$REPO_ROOT/core/skills/auto-build/scripts/queue.sh"

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

assert_jq_valid() {
  local name="$1" line="$2"
  if echo "$line" | jq empty 2>/dev/null; then
    echo "  ✓ $name (jq empty)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (jq empty)"
    echo "    line: '$line'"
    FAIL=$((FAIL + 1))
  fi
}

assert_jq_eq() {
  local name="$1" expr="$2" expected="$3" line="$4"
  local actual
  actual=$(echo "$line" | jq -r "$expr" 2>/dev/null || echo "")
  if [ "$actual" = "$expected" ]; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

setup_fixture() {
  TMP=$(mktemp -d)
  export QUEUE_STORE="$TMP/auto-build-queue.jsonl"
  export QUEUE_LOCK_DIR="$TMP/.lock"
}

teardown() {
  rm -rf "$TMP"
  unset QUEUE_STORE QUEUE_LOCK_DIR
}

# ── Test 1: add — entry 1개 append ──────────────────────────
echo "Test 1: add 1 entry"
setup_fixture
bash "$QUEUE" add "test task body"
LINE=$(head -1 "$QUEUE_STORE" 2>/dev/null || echo "")
assert_jq_valid "1.1 jq empty" "$LINE"
assert_jq_eq "1.2 task field" '.task' "test task body" "$LINE"
assert_jq_eq "1.3 status=queued" '.status' "queued" "$LINE"
assert_contains "1.4 id present" '"id":"[0-9]{8}T[0-9]{6}Z-[a-f0-9]{4}"' "$LINE"
assert_contains "1.5 created_ts ISO 8601" '"created_ts":"[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$LINE"
teardown

# ── Test 2: list — queued entry 표시 ────────────────────────
echo "Test 2: list shows queued entries"
setup_fixture
bash "$QUEUE" add "task one"
sleep 1
bash "$QUEUE" add "task two"
OUT=$(bash "$QUEUE" list)
assert_contains "2.1 task one 포함" "task one" "$OUT"
assert_contains "2.2 task two 포함" "task two" "$OUT"
assert_contains "2.3 status queued 표시" "queued" "$OUT"
# fold: status_update 없으면 모두 queued
LINE_COUNT=$(echo "$OUT" | grep -E "queued" | wc -l | tr -d ' ')
if [ "$LINE_COUNT" -ge 2 ]; then
  echo "  ✓ 2.4 list shows 2+ queued entries"
  PASS=$((PASS + 1))
else
  echo "  ✗ 2.4 expected ≥2 queued, got $LINE_COUNT"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test 3: remove — status_update aborted ──────────────────
echo "Test 3: remove marks status_update aborted"
setup_fixture
bash "$QUEUE" add "task to remove"
ID=$(head -1 "$QUEUE_STORE" | jq -r '.id')
bash "$QUEUE" remove "$ID"
# status_update 라인 확인
UPDATE_LINE=$(tail -1 "$QUEUE_STORE")
assert_jq_valid "3.1 status_update jq empty" "$UPDATE_LINE"
assert_jq_eq "3.2 op=status_update" '.op' "status_update" "$UPDATE_LINE"
assert_jq_eq "3.3 new_status=aborted" '.new_status' "aborted" "$UPDATE_LINE"
assert_jq_eq "3.4 id 일치" '.id' "$ID" "$UPDATE_LINE"
# list (기본)에서 aborted entry는 표시 안 됨
OUT=$(bash "$QUEUE" list)
if ! echo "$OUT" | grep -q "task to remove"; then
  echo "  ✓ 3.5 aborted entry hidden in default list"
  PASS=$((PASS + 1))
else
  echo "  ✗ 3.5 aborted entry shown in default list"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test 4: clear — 모든 queued → aborted ───────────────────
echo "Test 4: clear marks all queued as aborted"
setup_fixture
bash "$QUEUE" add "a"
sleep 1
bash "$QUEUE" add "b"
sleep 1
bash "$QUEUE" add "c"
bash "$QUEUE" clear
# 3 status_update 라인 추가됨
UPDATE_COUNT=$(grep '"op":"status_update"' "$QUEUE_STORE" | wc -l | tr -d ' ')
if [ "$UPDATE_COUNT" = "3" ]; then
  echo "  ✓ 4.1 3 status_update lines appended"
  PASS=$((PASS + 1))
else
  echo "  ✗ 4.1 expected 3 status_update, got $UPDATE_COUNT"
  FAIL=$((FAIL + 1))
fi
# list 기본은 비어 있음
OUT=$(bash "$QUEUE" list)
QUEUED_COUNT=$(echo "$OUT" | grep -E "queued" | wc -l | tr -d ' ')
if [ "$QUEUED_COUNT" = "0" ]; then
  echo "  ✓ 4.2 default list empty after clear"
  PASS=$((PASS + 1))
else
  echo "  ✗ 4.2 expected 0 queued, got $QUEUED_COUNT"
  FAIL=$((FAIL + 1))
fi
teardown

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
