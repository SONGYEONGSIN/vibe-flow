#!/bin/bash
# core/skills/auto-build/scripts/run-cloud.sh smoke (Phase 3.1 PR-C2)
# 실행: bash scripts/tests/run-cloud-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RUN_CLOUD="$REPO_ROOT/core/skills/auto-build/scripts/run-cloud.sh"
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

setup_fixture() {
  TMP=$(mktemp -d)
  export QUEUE_STORE="$TMP/auto-build-queue.jsonl"
  export QUEUE_LOCK_DIR="$TMP/.lock"
}

teardown() {
  rm -rf "$TMP"
  unset QUEUE_STORE QUEUE_LOCK_DIR
}

# ── Test C1: empty queue → exit 0 + stderr "queue empty" ───
echo "Test C1: empty queue handling"
setup_fixture
OUT=$(bash "$RUN_CLOUD" 2>&1 || true)
EC=$?
# subshell EC 캡처 한계 — 별도 invocation으로 정확한 exit code
bash "$RUN_CLOUD" >/dev/null 2>&1
EC=$?
assert_exit "C1.1 empty queue exit 0" 0 "$EC"
OUT=$(bash "$RUN_CLOUD" 2>&1 || true)
assert_contains "C1.2 stderr 'queue empty'" "queue empty" "$OUT"
teardown

# ── Test C2: DRYRUN 1 task → mock PR + status done ─────────
echo "Test C2: DRYRUN 1 task dispatch"
setup_fixture
bash "$QUEUE" add "cloud cycle test task" >/dev/null
# DRYRUN=1 호출 → mock PR URL stdout + status_update done
OUT_STDOUT=$(AUTO_BUILD_QUEUE_DRYRUN=1 \
  QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" \
  bash "$RUN_CLOUD" 2>/dev/null || true)
EC=$?
assert_exit "C2.1 DRYRUN exit 0" 0 "$EC"
assert_contains "C2.1 stdout 'mock PR URL'" "github.com/SONGYEONGSIN/vibe-flow/pull/MOCK-" "$OUT_STDOUT"
# entry status done in list --all
ALL=$(bash "$QUEUE" list --all)
if echo "$ALL" | grep -q "done.*cloud cycle test task"; then
  echo "  ✓ C2.2 entry status done"
  PASS=$((PASS + 1))
else
  echo "  ✗ C2.2 entry status not done"
  echo "    list --all: $ALL"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test C3: gh CLI 부재 (DRYRUN=0) → graceful abort ───────
echo "Test C3: gh CLI 부재 fallback"
setup_fixture
bash "$QUEUE" add "gh missing test" >/dev/null
# PATH 제한으로 gh 가림 (/bin + /usr/bin에 gh 없음 가정 — brew/.local 경로만 gh 존재)
# 단일 invocation에서 EC + OUT 동시 capture (두 번 호출 시 queue 상태 변경으로 분기 달라짐)
OUT=$(PATH="/bin:/usr/bin" AUTO_BUILD_QUEUE_DRYRUN=0 \
  QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" \
  bash "$RUN_CLOUD" 2>&1)
EC=$?
assert_exit "C3.1 gh missing exit 2" 2 "$EC"
assert_contains "C3.1 stderr 'gh CLI not found'" "gh CLI not found" "$OUT"
# entry aborted (소실 회피 아닌 의도적 abort — gh 없으면 실 PR 불가)
ALL=$(bash "$QUEUE" list --all)
if echo "$ALL" | grep -q "aborted.*gh missing test"; then
  echo "  ✓ C3.2 entry aborted"
  PASS=$((PASS + 1))
else
  echo "  ✗ C3.2 entry not aborted"
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
