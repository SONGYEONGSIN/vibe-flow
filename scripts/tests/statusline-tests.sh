#!/bin/bash
# statusline.sh 단위 테스트 (5 케이스)
# 실행: bash core/scripts/tests/statusline-tests.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATUSLINE="$SCRIPT_DIR/statusline.sh"

PASS=0
FAIL=0

assert_equals() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1" pattern="$2" actual="$3"
  if echo "$actual" | grep -q "$pattern"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    pattern:  '$pattern'"
    echo "    actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

setup_fixture() {
  TMP=$(mktemp -d)
  mkdir -p "$TMP/.claude/plans"
  echo "$TMP"
}

cleanup_fixture() {
  rm -rf "$1"
}

# ─── Case 1: 데이터 없음 → 빈 출력 ───
echo "Case 1: 데이터 없음"
TMP=$(setup_fixture)
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$STATUSLINE")
assert_equals "empty output when no data" "" "$out"
cleanup_fixture "$TMP"

# ─── Case 2: verify pass + hook OK + 활성 plan ───
echo ""
echo "Case 2: verify pass + hook OK + 활성 plan"
TMP=$(setup_fixture)
cat > "$TMP/.claude/events.jsonl" <<EOF
{"type":"verify_complete","ts":"2026-04-30T12:00:00Z","overall":"pass","results":[{"hook":"prettier","status":"pass"}]}
{"type":"tool_result","ts":"2026-04-30T12:01:00Z","tool":"prettier","results":[{"hook":"prettier","status":"ok"}]}
EOF
cat > "$TMP/.claude/plans/2026-04-30-auth.md" <<EOF
---
status: in_progress
---

- [x] Step 1
- [x] Step 2
- [x] Step 3
- [ ] Step 4
- [ ] Step 5
- [ ] Step 6
- [ ] Step 7
EOF
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$STATUSLINE")
assert_contains "verify ✓" "✓v" "$out"
assert_contains "hook ✓" "🔧✓" "$out"
assert_contains "plan 3/7" "📋3/7" "$out"
cleanup_fixture "$TMP"

# ─── Case 3: verify fail + 활성 plan ───
echo ""
echo "Case 3: verify fail + 활성 plan"
TMP=$(setup_fixture)
cat > "$TMP/.claude/events.jsonl" <<EOF
{"type":"verify_complete","ts":"2026-04-30T12:00:00Z","overall":"fail","results":[{"hook":"tsc","status":"fail"},{"hook":"test","status":"fail"},{"hook":"lint","status":"pass"}]}
EOF
cat > "$TMP/.claude/plans/2026-04-30-billing.md" <<EOF
---
status: in_progress
---

- [x] Step 1
- [ ] Step 2
EOF
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$STATUSLINE")
assert_contains "verify fail count" "✗v(2 fail)" "$out"
assert_contains "plan 1/2" "📋1/2" "$out"
cleanup_fixture "$TMP"

# ─── Case 4: verify pass, plan 없음 ───
echo ""
echo "Case 4: verify pass, plan 없음"
TMP=$(setup_fixture)
cat > "$TMP/.claude/events.jsonl" <<EOF
{"type":"verify_complete","ts":"2026-04-30T12:00:00Z","overall":"pass","results":[]}
{"type":"tool_result","ts":"2026-04-30T12:01:00Z","tool":"eslint"}
EOF
out=$(CLAUDE_PROJECT_DIR="$TMP" bash "$STATUSLINE")
assert_contains "verify pass shown" "✓v" "$out"
assert_contains "hook ok shown" "🔧✓" "$out"
# plan 부분 없어야
if echo "$out" | grep -q "📋"; then
  echo "  ✗ no plan: should not show 📋 (got '$out')"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ no plan: 📋 not shown"
  PASS=$((PASS + 1))
fi
cleanup_fixture "$TMP"

# ─── Case 5: VIBE_FLOW_STATUSLINE=off → 빈 출력 ───
echo ""
echo "Case 5: VIBE_FLOW_STATUSLINE=off"
TMP=$(setup_fixture)
cat > "$TMP/.claude/events.jsonl" <<EOF
{"type":"verify_complete","ts":"2026-04-30T12:00:00Z","overall":"pass","results":[]}
EOF
out=$(VIBE_FLOW_STATUSLINE=off CLAUDE_PROJECT_DIR="$TMP" bash "$STATUSLINE")
assert_equals "off env disables output" "" "$out"
cleanup_fixture "$TMP"

# ─── 요약 ───
echo ""
echo "=== 결과 ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
