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

# ── Test 5: stale lock 자동 회수 (SIGKILL 시뮬레이션) ────────
echo "Test 5: stale lock auto-recovery"
setup_fixture
# 가짜 lockdir + 죽은 PID (대형 PID = 거의 확실히 미존재) 시뮬레이션
mkdir -p "$QUEUE_LOCK_DIR"
echo "99999999" > "$QUEUE_LOCK_DIR/pid"
# add 호출 — stale 회수 후 성공해야
if bash "$QUEUE" add "after stale" >/dev/null 2>&1; then
  LINE=$(head -1 "$QUEUE_STORE")
  assert_jq_eq "5.1 add 성공 (stale 회수)" '.task' "after stale" "$LINE"
else
  echo "  ✗ 5.1 add 실패 (stale 미회수)"
  FAIL=$((FAIL + 1))
fi
# lockdir 정상 해제
if [ ! -d "$QUEUE_LOCK_DIR" ]; then
  echo "  ✓ 5.2 lockdir 해제 완료"
  PASS=$((PASS + 1))
else
  echo "  ✗ 5.2 lockdir 잔존"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test 6: next — queued 첫 entry pop + running 마킹 ──────
echo "Test 6: next pops first queued entry"
setup_fixture
bash "$QUEUE" add "first task" >/dev/null
sleep 1
bash "$QUEUE" add "second task" >/dev/null
NEXT_ID=$(bash "$QUEUE" next)
FIRST_ID=$(head -1 "$QUEUE_STORE" | jq -r '.id')
if [ "$NEXT_ID" = "$FIRST_ID" ]; then
  echo "  ✓ 6.1 next returns first queued id"
  PASS=$((PASS + 1))
else
  echo "  ✗ 6.1 expected $FIRST_ID, got $NEXT_ID"
  FAIL=$((FAIL + 1))
fi
LAST=$(tail -1 "$QUEUE_STORE")
assert_jq_eq "6.2 status_update running 라인 append" '.new_status' "running" "$LAST"
assert_jq_eq "6.3 id 일치" '.id' "$NEXT_ID" "$LAST"
# 빈 queue: 모든 queued → running 후, next 호출 시 empty + exit 0
bash "$QUEUE" next >/dev/null
EMPTY=$(bash "$QUEUE" next)
if [ -z "$EMPTY" ]; then
  echo "  ✓ 6.4 empty queue: next returns empty"
  PASS=$((PASS + 1))
else
  echo "  ✗ 6.4 expected empty, got '$EMPTY'"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test 7: run-queue DRYRUN=1 → 1 entry done ──────────────
RUN_QUEUE="$REPO_ROOT/core/skills/auto-build/scripts/run-queue.sh"
echo "Test 7: run-queue DRYRUN done"
setup_fixture
bash "$QUEUE" add "dryrun task" >/dev/null
AUTO_BUILD_QUEUE_DRYRUN=1 QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" \
  bash "$RUN_QUEUE" >/dev/null 2>&1
# entry id의 최종 status는 done
ALL=$(bash "$QUEUE" list --all)
if echo "$ALL" | grep -q "done.*dryrun task"; then
  echo "  ✓ 7.1 entry status done (DRYRUN)"
  PASS=$((PASS + 1))
else
  echo "  ✗ 7.1 done 상태 미반영"
  echo "    list --all: $ALL"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test 8: max cycle cap (4 add, MAX=3, 1 queued 잔존) ────
echo "Test 8: max cycle cap"
setup_fixture
bash "$QUEUE" add "a" >/dev/null; sleep 1
bash "$QUEUE" add "b" >/dev/null; sleep 1
bash "$QUEUE" add "c" >/dev/null; sleep 1
bash "$QUEUE" add "d" >/dev/null
AUTO_BUILD_QUEUE_DRYRUN=1 AUTO_BUILD_QUEUE_MAX_CYCLES=3 \
  QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" \
  bash "$RUN_QUEUE" >/dev/null 2>&1
ALL=$(bash "$QUEUE" list --all)
DONE_COUNT=$(echo "$ALL" | grep -cE "done" || true)
QUEUED_REMAIN=$(bash "$QUEUE" list | wc -l | tr -d ' ')
if [ "$DONE_COUNT" -eq 3 ] && [ "$QUEUED_REMAIN" -eq 1 ]; then
  echo "  ✓ 8.1 3 done + 1 queued remaining"
  PASS=$((PASS + 1))
else
  echo "  ✗ 8.1 expected 3 done + 1 queued, got $DONE_COUNT done + $QUEUED_REMAIN queued"
  echo "    list --all: $ALL"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test 9: cycle abort 즉시 종료 ──────────────────────────
echo "Test 9: cycle abort → 즉시 종료"
setup_fixture
bash "$QUEUE" add "first will abort" >/dev/null; sleep 1
bash "$QUEUE" add "second should remain queued" >/dev/null
AUTO_BUILD_QUEUE_DRYRUN=1 AUTO_BUILD_QUEUE_DRYRUN_FAIL=1 \
  QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" \
  bash "$RUN_QUEUE" >/dev/null 2>&1
ALL=$(bash "$QUEUE" list --all)
ABORTED=$(echo "$ALL" | grep -cE "aborted" || true)
QUEUED_REMAIN=$(bash "$QUEUE" list | wc -l | tr -d ' ')
if [ "$ABORTED" -eq 1 ] && [ "$QUEUED_REMAIN" -eq 1 ]; then
  echo "  ✓ 9.1 1 aborted + 1 queued remaining (abort halt)"
  PASS=$((PASS + 1))
else
  echo "  ✗ 9.1 expected 1 aborted + 1 queued, got $ABORTED aborted + $QUEUED_REMAIN queued"
  echo "    list --all: $ALL"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test 10: DRYRUN=0 (미설정) → entry 보존 + exit 1 ────────
echo "Test 10: DRYRUN=0 — entry 보존 (소실 방지)"
setup_fixture
bash "$QUEUE" add "must not be aborted" >/dev/null
# DRYRUN 미설정 + 실 trigger 미구현 → exit 1 + entry는 running 그대로
QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" \
  bash "$RUN_QUEUE" >/dev/null 2>&1
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 1 ]; then
  echo "  ✓ 10.1 exit 1 (실 trigger 미구현 신호)"
  PASS=$((PASS + 1))
else
  echo "  ✗ 10.1 expected exit 1, got $EXIT_CODE"
  FAIL=$((FAIL + 1))
fi
# entry status는 running (aborted 아님)
ALL=$(bash "$QUEUE" list --all)
if echo "$ALL" | grep -q "running.*must not be aborted"; then
  echo "  ✓ 10.2 entry running 보존 (aborted 회피)"
  PASS=$((PASS + 1))
else
  echo "  ✗ 10.2 entry aborted 마킹 발생 (소실)"
  echo "    list --all: $ALL"
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
