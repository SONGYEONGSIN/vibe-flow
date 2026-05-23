#!/bin/bash
# core/skills/auto-build/scripts/schedule-register.sh + run-queue.sh schedule 통합 smoke (Phase 3.1 PR-C1)
# 실행: bash scripts/tests/schedule-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REGISTER="$REPO_ROOT/core/skills/auto-build/scripts/schedule-register.sh"
RUN_QUEUE="$REPO_ROOT/core/skills/auto-build/scripts/run-queue.sh"
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
  export FIRINGS_STORE="$TMP/auto-build-firings.jsonl"
}

teardown() {
  rm -rf "$TMP"
  unset QUEUE_STORE QUEUE_LOCK_DIR FIRINGS_STORE
}

# ── Test S1: cron expression validation + DRYRUN echo ──────
echo "Test S1: schedule-register.sh cron expr validation"
# S1.1: invalid cron → exit 1 + stderr 포함
OUT=$(bash "$REGISTER" "invalid-cron" 2>&1 || true)
EC=$?
# Note: subshell capture로 EC는 0이 됨 — 별도 capture 필요
bash "$REGISTER" "invalid-cron" >/dev/null 2>&1
EC=$?
assert_exit "S1.1 invalid cron exit 1" 1 "$EC"
OUT=$(bash "$REGISTER" "invalid-cron" 2>&1 || true)
assert_contains "S1.1 stderr 'invalid cron expression'" "invalid cron expression" "$OUT"

# S1.2: valid cron + DRYRUN=1 → exit 0 + "would register: ..."
SCHEDULE_REGISTER_DRYRUN=1 bash "$REGISTER" "0 */6 * * *" >/dev/null 2>&1
EC=$?
assert_exit "S1.2 valid cron DRYRUN exit 0" 0 "$EC"
OUT=$(SCHEDULE_REGISTER_DRYRUN=1 bash "$REGISTER" "0 */6 * * *" 2>&1 || true)
assert_contains "S1.2 stdout 'would register'" "would register: 0 \\*/6 \\* \\* \\*" "$OUT"

# ── Test S2: run-queue MAX_FIRINGS_PER_DAY cap ─────────────
echo "Test S2: run-queue MAX_FIRINGS_PER_DAY cap"
setup_fixture
bash "$QUEUE" add "firing test 1" >/dev/null; sleep 1
bash "$QUEUE" add "firing test 2" >/dev/null; sleep 1
bash "$QUEUE" add "firing test 3" >/dev/null

# S2.1: 1번째/2번째 firing 정상 처리 (cap=2)
AUTO_BUILD_QUEUE_DRYRUN=1 AUTO_BUILD_QUEUE_MAX_CYCLES=1 AUTO_BUILD_QUEUE_MAX_FIRINGS_PER_DAY=2 \
  QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" FIRINGS_STORE="$FIRINGS_STORE" \
  bash "$RUN_QUEUE" >/dev/null 2>&1
EC1=$?
AUTO_BUILD_QUEUE_DRYRUN=1 AUTO_BUILD_QUEUE_MAX_CYCLES=1 AUTO_BUILD_QUEUE_MAX_FIRINGS_PER_DAY=2 \
  QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" FIRINGS_STORE="$FIRINGS_STORE" \
  bash "$RUN_QUEUE" >/dev/null 2>&1
EC2=$?
FIRINGS_COUNT=$(grep -c '"ts"' "$FIRINGS_STORE" 2>/dev/null || echo 0)
if [ "$EC1" -eq 0 ] && [ "$EC2" -eq 0 ] && [ "$FIRINGS_COUNT" -eq 2 ]; then
  echo "  ✓ S2.1 2 firings within cap (firings.jsonl: 2 lines)"
  PASS=$((PASS + 1))
else
  echo "  ✗ S2.1 expected 2 successful firings + 2 lines, got EC1=$EC1 EC2=$EC2 FIRINGS=$FIRINGS_COUNT"
  FAIL=$((FAIL + 1))
fi

# S2.2: 3번째 firing — cap 도달 → exit 0 + stderr "max firings reached" + 처리 X
OUT=$(AUTO_BUILD_QUEUE_DRYRUN=1 AUTO_BUILD_QUEUE_MAX_CYCLES=1 AUTO_BUILD_QUEUE_MAX_FIRINGS_PER_DAY=2 \
  QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" FIRINGS_STORE="$FIRINGS_STORE" \
  bash "$RUN_QUEUE" 2>&1)
EC3=$?
QUEUED_REMAIN=$(bash "$QUEUE" list | wc -l | tr -d ' ')
if [ "$EC3" -eq 0 ] && [ "$QUEUED_REMAIN" -ge 1 ]; then
  echo "  ✓ S2.2 cap reached: exit 0 + 1+ queued remain"
  PASS=$((PASS + 1))
else
  echo "  ✗ S2.2 expected exit 0 + 1+ queued, got EC=$EC3 queued=$QUEUED_REMAIN"
  FAIL=$((FAIL + 1))
fi
assert_contains "S2.2 stderr 'max firings reached'" "max firings reached" "$OUT"
teardown

# ── Test S3: CRON_FIRING=1 분기 — entry 보존 + firings 1 append ─
echo "Test S3: AUTO_BUILD_QUEUE_CRON_FIRING=1 — entry running 보존"
setup_fixture
bash "$QUEUE" add "cron firing test" >/dev/null
# CRON_FIRING=1 + DRYRUN=0 (실 trigger 미구현) → exit 1 + entry running 보존 + firings 1건 append
OUT=$(AUTO_BUILD_QUEUE_CRON_FIRING=1 \
  QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" FIRINGS_STORE="$FIRINGS_STORE" \
  bash "$RUN_QUEUE" 2>&1)
EC=$?
FIRINGS_COUNT=$(grep -c '"ts"' "$FIRINGS_STORE" 2>/dev/null || echo 0)
ALL=$(bash "$QUEUE" list --all)
assert_exit "S3.1 CRON_FIRING DRYRUN=0 exit 1 (실 trigger 미구현)" 1 "$EC"
if echo "$ALL" | grep -q "running.*cron firing test"; then
  echo "  ✓ S3.2 entry running 보존 (소실 회피)"
  PASS=$((PASS + 1))
else
  echo "  ✗ S3.2 entry running 미보존"
  echo "    list --all: $ALL"
  FAIL=$((FAIL + 1))
fi
if [ "$FIRINGS_COUNT" -eq 1 ]; then
  echo "  ✓ S3.3 firings.jsonl 1 라인 append (cap 카운트 누적)"
  PASS=$((PASS + 1))
else
  echo "  ✗ S3.3 expected firings=1, got $FIRINGS_COUNT"
  FAIL=$((FAIL + 1))
fi
assert_contains "S3.4 stderr 'cron-triggered firing'" "cron-triggered firing" "$OUT"
teardown

# ── Test S4: claude CLI 부재 시 schedule-register exit 2 ───
echo "Test S4: schedule-register claude CLI 부재 → exit 2"
# PATH 제한으로 claude CLI 가려서 시뮬레이션 (/bin + /usr/bin은 OS 표준 — claude는 brew 경로에만 존재)
PATH="/bin:/usr/bin" SCHEDULE_REGISTER_DRYRUN=0 bash "$REGISTER" "0 */6 * * *" >/dev/null 2>&1
EC=$?
assert_exit "S4.1 claude CLI 부재 exit 2" 2 "$EC"
OUT=$(PATH="/bin:/usr/bin" SCHEDULE_REGISTER_DRYRUN=0 bash "$REGISTER" "0 */6 * * *" 2>&1 || true)
assert_contains "S4.1 stderr 'claude CLI not found'" "claude CLI not found" "$OUT"

# ── Test S5: 1h min interval validation (PR-C1.1) ──────────
echo "Test S5: 1h min interval validation"
# S5.1: */30 sub-hour → exit 1 + stderr 'interval too short'
SCHEDULE_REGISTER_DRYRUN=1 bash "$REGISTER" "*/30 * * * *" >/dev/null 2>&1
EC=$?
assert_exit "S5.1 */30 (sub-hour) exit 1" 1 "$EC"
OUT=$(SCHEDULE_REGISTER_DRYRUN=1 bash "$REGISTER" "*/30 * * * *" 2>&1 || true)
assert_contains "S5.1 stderr 'interval too short'" "interval too short" "$OUT"

# S5.2: 0 */1 * * * (정확히 1h) → DRYRUN PASS
SCHEDULE_REGISTER_DRYRUN=1 bash "$REGISTER" "0 */1 * * *" >/dev/null 2>&1
EC=$?
assert_exit "S5.2 0 */1 (1h exact) exit 0" 0 "$EC"

# S5.3: */5 * * * * (5분) → reject
SCHEDULE_REGISTER_DRYRUN=1 bash "$REGISTER" "*/5 * * * *" >/dev/null 2>&1
EC=$?
assert_exit "S5.3 */5 (5min) exit 1" 1 "$EC"

# ── Test S6: RemoteTrigger payload JSON + prompt 템플릿 ────
echo "Test S6: RemoteTrigger payload + prompt template"
# S6.1: DRYRUN stdout이 valid JSON + body.prompt에 /auto-build run-cloud 토큰
OUT=$(SCHEDULE_REGISTER_DRYRUN=1 bash "$REGISTER" "0 */6 * * *" 2>/dev/null || true)
if echo "$OUT" | jq -e . >/dev/null 2>&1; then
  echo "  ✓ S6.1 stdout is valid JSON"
  PASS=$((PASS + 1))
else
  echo "  ✗ S6.1 stdout not valid JSON"
  echo "    actual: $OUT"
  FAIL=$((FAIL + 1))
fi
PROMPT=$(echo "$OUT" | jq -r '.body.prompt // ""' 2>/dev/null || echo "")
assert_contains "S6.1 body.prompt contains '/auto-build run-cloud'" "/auto-build run-cloud" "$PROMPT"

# S6.2: REPO_URL env가 payload prompt에 치환됨
OUT=$(REPO_URL="https://github.com/test/myrepo" SCHEDULE_REGISTER_DRYRUN=1 bash "$REGISTER" "0 */6 * * *" 2>/dev/null || true)
PROMPT=$(echo "$OUT" | jq -r '.body.prompt // ""' 2>/dev/null || echo "")
assert_contains "S6.2 REPO_URL env reflected in prompt" "github.com/test/myrepo" "$PROMPT"

# ── Test S7: run_once_at 모드 ──────────────────────────────
echo "Test S7: --once + RUN_ONCE_AT mode"
# S7.1: --once + RUN_ONCE_AT (RFC 3339) → payload run_once_at, cron 부재
OUT=$(RUN_ONCE_AT="2026-05-24T03:00:00Z" SCHEDULE_REGISTER_DRYRUN=1 \
  bash "$REGISTER" --once 2>/dev/null || true)
EC=$?
RUN_ONCE=$(echo "$OUT" | jq -r '.body.schedule.run_once_at // ""' 2>/dev/null || echo "")
CRON=$(echo "$OUT" | jq -r '.body.schedule.cron // ""' 2>/dev/null || echo "")
if [ "$RUN_ONCE" = "2026-05-24T03:00:00Z" ] && [ -z "$CRON" ]; then
  echo "  ✓ S7.1 run_once_at populated, cron absent"
  PASS=$((PASS + 1))
else
  echo "  ✗ S7.1 expected run_once_at='2026-05-24T03:00:00Z' + cron='', got run_once='$RUN_ONCE' cron='$CRON'"
  FAIL=$((FAIL + 1))
fi

# S7.2: --once 없이 RUN_ONCE_AT 만 → reject (mode flag 강제)
SCHEDULE_REGISTER_DRYRUN=1 RUN_ONCE_AT="2026-05-24T03:00:00Z" \
  bash "$REGISTER" "0 */6 * * *" >/dev/null 2>&1
EC=$?
# 1h+ cron이라 register는 성공해야 (mode 불충족만 verify 어려움 — 다른 접근)
# 대신: --once 인자에 cron expression이 동시에 있으면 reject
SCHEDULE_REGISTER_DRYRUN=1 RUN_ONCE_AT="2026-05-24T03:00:00Z" \
  bash "$REGISTER" --once "0 */6 * * *" >/dev/null 2>&1
EC=$?
assert_exit "S7.2 --once + cron expr 동시 사용 → exit 1" 1 "$EC"

# S7.3: --once 없이 RUN_ONCE_AT 만 + 인자 0 → usage error
SCHEDULE_REGISTER_DRYRUN=1 RUN_ONCE_AT="2026-05-24T03:00:00Z" \
  bash "$REGISTER" >/dev/null 2>&1
EC=$?
assert_exit "S7.3 인자 없이 RUN_ONCE_AT만 → usage error exit 1" 1 "$EC"

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
