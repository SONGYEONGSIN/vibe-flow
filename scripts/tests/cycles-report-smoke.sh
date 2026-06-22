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

# Case 4: marker dedup — squash 머지본 + 브랜치 원본이 같은 cycle 을 중복 카운트하면 안 됨 (F-D9)
echo "=== Case 4: duplicate marker commits dedup to unique cycle count ==="
setup
# 같은 R9 marker 가 브랜치 원본 + PR squash(#NN) 형태로 2번 존재하는 상황 재현
git commit -q --allow-empty -m "feat: R9 dogfooding marker"
git commit -q --allow-empty -m "feat: R9 dogfooding marker (#71)"
# 추가로 서로 다른 cycle R10 도 1건
git commit -q --allow-empty -m "feat: R10 dogfooding marker (#74)"
out=$(bash "$SCRIPT" 2>&1)
# 원시 카운트는 3 이지만 고유 cycle 은 R9, R10 → 2
assert_contains "unique cycle markers = 2 (not raw 3)" "unique cycle markers: 2" "$out"
# 회귀 가드: 중복 포함 raw 3 이 카운트로 새어나오면 안 됨
if echo "$out" | grep -q "marker commits: 3"; then
  echo "  ✗ raw duplicate count (3) leaked into report"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ raw duplicate count (3) not reported"
  PASS=$((PASS + 1))
fi
teardown

# Case 5: marker 문구 변형도 같은 cycle 로 dedup (F-G10 audit R7)
echo "=== Case 5: variant marker suffix dedup (F-G10) ==="
setup
git commit -q --allow-empty -m "feat: R12 dogfooding marker (#80)"
git commit -q --allow-empty -m "chore: R12 dogfooding marker — cloud cycle"
out=$(bash "$SCRIPT" 2>&1)
assert_contains "variant suffix dedup → unique 1 (not 2)" "unique cycle markers: 1" "$out"
teardown

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
