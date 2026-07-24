#!/bin/bash
# core/skills/auto-build/scripts/run-cloud.sh smoke (Phase 3.1 PR-C2)
# 실행: bash scripts/tests/run-cloud-smoke.sh
#
# CI-SKIP: C3 (gh-absent fallback) 는 PATH=/bin:/usr/bin 로 gh 를 가리는데,
# CI(ubuntu)는 gh 가 /usr/bin 에 있어 포팅 불가 (로컬 gh in brew/.local 에서만 유효).
# → validation-tests.yml 에서 skip, 로컬 검증 전용. (F-G02, audit R7)

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

# ── Test C3: gh CLI 부재 (DRYRUN=0) → hand-off (F-P02) ───────
# F-P02: gh 조기 게이트 제거 — run-cloud.sh 책임은 entry 선택+hand-off 까지.
# gh 판단은 P5(PR 생성)로 이연(agent 가 gh 또는 mcp__github 로 생성). gh 무관한
# P0~P4(브랜치/brainstorm/plan/TDD/verify)가 gh 부재로 무산출 소모되던 회귀 차단.
echo "Test C3: gh CLI 부재 → hand-off (게이트 제거)"
setup_fixture
bash "$QUEUE" add "gh missing test" >/dev/null
# PATH 제한으로 gh 가림 (/bin + /usr/bin에 gh 없음 — brew/.local 경로만 gh 존재)
OUT=$(PATH="/bin:/usr/bin" AUTO_BUILD_QUEUE_DRYRUN=0 \
  QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" \
  bash "$RUN_CLOUD" 2>&1)
EC=$?
assert_exit "C3.1 gh missing → hand-off exit 0 (조기 abort 아님)" 0 "$EC"
assert_contains "C3.2 stderr 'handed off to cloud agent'" "handed off to cloud agent" "$OUT"
assert_contains "C3.3 stderr mcp__github 대체 경로 언급" "mcp__github__create_pull_request" "$OUT"
# entry running 유지 (agent 가 P5 후 status-update) — 조기 abort 아님
ALL=$(bash "$QUEUE" list --all)
if echo "$ALL" | grep -q "running.*gh missing test"; then
  echo "  ✓ C3.4 entry running 유지 (조기 abort 아님)"
  PASS=$((PASS + 1))
else
  echo "  ✗ C3.4 entry not running (조기 abort 회귀?)"
  echo "    list --all: $ALL"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test C4 (F-D7): gh 존재 + DRYRUN=0 → agent hand-off ────
# PR-C2 stub 제거 검증: entry 가 running 상태로 유지되고 exit 0 + hand-off 메시지.
# 실 cycle 은 cloud agent 가 본 script 종료 후 자율 수행 (orchestrator P0~P5).
echo "Test C4: gh 존재 + DRYRUN=0 — agent hand-off (F-D7)"
setup_fixture
bash "$QUEUE" add "agent handoff test" >/dev/null
# mock gh in tmp PATH
GH_STUB_DIR="$TMP/stub-bin"
mkdir -p "$GH_STUB_DIR"
cat > "$GH_STUB_DIR/gh" <<'STUB'
#!/bin/bash
exit 0
STUB
chmod +x "$GH_STUB_DIR/gh"

OUT=$(PATH="$GH_STUB_DIR:/bin:/usr/bin" AUTO_BUILD_QUEUE_DRYRUN=0 \
  QUEUE_STORE="$QUEUE_STORE" QUEUE_LOCK_DIR="$QUEUE_LOCK_DIR" \
  bash "$RUN_CLOUD" 2>&1)
EC=$?
assert_exit "C4.1 hand-off exit 0 (PR-C2 stub 제거 검증)" 0 "$EC"
assert_contains "C4.2 stderr 'handed off to cloud agent'" "handed off to cloud agent" "$OUT"
assert_contains "C4.3 stderr 'orchestrator.md P0~P5' 지시" "orchestrator.md P0~P5" "$OUT"
# entry 가 running 상태 유지 (queued 복구 X — 구 stub 동작 회귀 차단)
ALL=$(bash "$QUEUE" list --all)
if echo "$ALL" | grep -q "running.*agent handoff test"; then
  echo "  ✓ C4.4 entry running 유지 (queued 복구 X — F-D7 회귀 차단)"
  PASS=$((PASS + 1))
else
  echo "  ✗ C4.4 entry running 상태 아님 — stub 회귀 가능성"
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
