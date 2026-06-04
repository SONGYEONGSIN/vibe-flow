#!/bin/bash
# core/skills/auto-build/scripts/cycles-report.sh smoke 테스트
# F-D3 R3-4: cycles-report queue 상태 집계 + stuck queued 탐지
# 실행: bash scripts/tests/cycles-report-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/core/skills/auto-build/scripts/cycles-report.sh"

PASS=0
FAIL=0

assert_contains() {
  local name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q -- "$needle"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    needle: $needle"
    echo "    haystack: $haystack" | head -3
    FAIL=$((FAIL + 1))
  fi
}

setup() {
  TMP=$(mktemp -d)
  cd "$TMP"
  git init -q -b main 2>/dev/null
  git config user.email "t@t.t"
  git config user.name "t"
  mkdir -p .claude/memory
  export PROJECT_ROOT="$TMP"
  export QUEUE_STORE="$TMP/.claude/memory/auto-build-queue.jsonl"
  export FIRINGS_STORE="$TMP/.claude/memory/auto-build-firings.jsonl"
}

teardown() { cd /; rm -rf "$TMP"; }

# Case 1: empty everything
echo "=== Case 1: empty queue + empty firings ==="
setup
out=$(bash "$SCRIPT" 2>&1)
assert_contains "marker section present" "Cloud cycle marker commits" "$out"
assert_contains "no marker commits" "(no marker commits found)" "$out"
assert_contains "firings empty" "(empty or not present)" "$out"
teardown

# Case 2: queue with mixed states + 1 stuck queued
echo "=== Case 2: queue mix (done/queued) + stuck queued ==="
setup
cat > "$QUEUE_STORE" <<'EOF'
{"id":"task-001","task":"foo","status":"queued","created_ts":"2026-05-01T00:00:00Z"}
{"op":"status_update","id":"task-001","new_status":"running","ts":"2026-05-01T00:05:00Z"}
{"op":"status_update","id":"task-001","new_status":"done","ts":"2026-05-01T00:10:00Z"}
{"id":"task-002","task":"bar","status":"queued","created_ts":"2026-05-02T00:00:00Z"}
{"id":"task-003","task":"baz","status":"queued","created_ts":"2026-05-03T00:00:00Z"}
{"op":"status_update","id":"task-003","new_status":"done","ts":"2026-05-03T01:00:00Z"}
EOF
out=$(bash "$SCRIPT" 2>&1)
assert_contains "done count = 2" "done: 2" "$out"
assert_contains "queued count = 1" "queued: 1" "$out"
assert_contains "stuck queued shows task-002" "task-002" "$out"
# Negative: task-001 (done) and task-003 (was queued → done) must NOT appear in stuck section
stuck_section=$(echo "$out" | awk '/queued entries/,/Cloud routine firings/' || true)
if echo "$stuck_section" | grep -q "task-001\|task-003"; then
  echo "  ✗ stuck section incorrectly includes a done task"
  echo "    stuck section: $stuck_section"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ stuck section excludes done tasks (task-001, task-003)"
  PASS=$((PASS + 1))
fi
teardown

# Case 3: with local firings
echo "=== Case 3: local firings present ==="
setup
echo '{"ts":"2026-05-23T00:09:08Z"}' >> "$FIRINGS_STORE"
echo '{"ts":"2026-05-23T00:09:12Z"}' >> "$FIRINGS_STORE"
out=$(bash "$SCRIPT" 2>&1)
assert_contains "firings total: 2" "total: 2 entries" "$out"
teardown

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
