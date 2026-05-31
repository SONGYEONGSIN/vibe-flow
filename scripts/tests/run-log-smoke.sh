#!/bin/bash
# run-log.sh smoke test (audit F-D1 — tdd Iron Law 자기 적용)
# 실행: bash scripts/tests/run-log-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/core/skills/auto-build/scripts/run-log.sh"

PASS=0
FAIL=0

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

assert_contains() {
  local name="$1" pattern="$2" actual="$3"
  if echo "$actual" | grep -qE "$pattern"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (pattern: '$pattern' not found)"
    FAIL=$((FAIL + 1))
  fi
}

# 격리된 임시 cwd 사용 — log file이 .claude/memory/auto-build-runs.jsonl 에 append
setup_tmp() {
  TMP=$(mktemp -d)
  PREV_CWD=$(pwd)
  cd "$TMP"
}

teardown_tmp() {
  cd "$PREV_CWD"
  rm -rf "$TMP"
}

echo "Test R1: usage error"
bash "$SCRIPT" >/dev/null 2>&1; EC=$?
assert_exit "R1.1 인자 0개 → exit 1" 1 "$EC"
bash "$SCRIPT" "start" >/dev/null 2>&1; EC=$?
assert_exit "R1.2 인자 1개 → exit 1" 1 "$EC"
bash "$SCRIPT" "invalid-event" "run-1" >/dev/null 2>&1; EC=$?
assert_exit "R1.3 invalid event → exit 1" 1 "$EC"

echo "Test R2: 기본 jsonl 라인 append (start)"
setup_tmp
bash "$SCRIPT" start "run-test-1" >/dev/null 2>&1; EC=$?
assert_exit "R2.1 start exit 0" 0 "$EC"
LINE=$(tail -1 .claude/memory/auto-build-runs.jsonl)
assert_contains "R2.2 jsonl event=start" '"event":"start"' "$LINE"
assert_contains "R2.3 jsonl run_id 기록" '"run_id":"run-test-1"' "$LINE"
assert_contains "R2.4 jsonl ts ISO 8601" '"ts":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$LINE"
teardown_tmp

echo "Test R3: extra key=value 누적"
setup_tmp
bash "$SCRIPT" start "run-2" phase=P1 branch=main steps=3 >/dev/null 2>&1; EC=$?
assert_exit "R3.1 extra args exit 0" 0 "$EC"
LINE=$(tail -1 .claude/memory/auto-build-runs.jsonl)
assert_contains "R3.2 phase=P1 string" '"phase":"P1"' "$LINE"
assert_contains "R3.3 branch=main string" '"branch":"main"' "$LINE"
assert_contains "R3.4 steps=3 number (no quotes)" '"steps":3[,}]' "$LINE"
teardown_tmp

echo "Test R4: abort/done 이벤트"
setup_tmp
bash "$SCRIPT" abort "run-3" exit_reason=test_fail >/dev/null 2>&1; EC=$?
assert_exit "R4.1 abort exit 0" 0 "$EC"
LINE=$(tail -1 .claude/memory/auto-build-runs.jsonl)
assert_contains "R4.2 abort event" '"event":"abort"' "$LINE"
assert_contains "R4.3 exit_reason 기록" '"exit_reason":"test_fail"' "$LINE"

bash "$SCRIPT" done "run-3" pr_url=https://example/pr/1 >/dev/null 2>&1; EC=$?
assert_exit "R4.4 done exit 0" 0 "$EC"
LINE=$(tail -1 .claude/memory/auto-build-runs.jsonl)
assert_contains "R4.5 done event" '"event":"done"' "$LINE"
teardown_tmp

echo "Test R5: 여러 이벤트 append 누적"
setup_tmp
bash "$SCRIPT" start "run-4" phase=P1 >/dev/null 2>&1
bash "$SCRIPT" start "run-4" phase=P2 >/dev/null 2>&1
bash "$SCRIPT" done  "run-4" >/dev/null 2>&1
LINES=$(wc -l < .claude/memory/auto-build-runs.jsonl | tr -d ' ')
if [ "$LINES" = "3" ]; then
  echo "  ✓ R5.1 3 라인 누적 ($LINES)"
  PASS=$((PASS + 1))
else
  echo "  ✗ R5.1 expected 3 lines, got $LINES"
  FAIL=$((FAIL + 1))
fi
teardown_tmp

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
