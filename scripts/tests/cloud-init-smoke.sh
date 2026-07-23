#!/bin/bash
# cloud-init.sh smoke test (audit F-D1 — tdd Iron Law 자기 적용)
# 실행: bash scripts/tests/cloud-init-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/core/skills/auto-build/scripts/cloud-init.sh"

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

# 격리된 임시 git repo + source 파일 구성
setup_fixture() {
  TMP=$(mktemp -d)
  PREV_CWD=$(pwd)
  cd "$TMP"
  git init -q
  mkdir -p core/hooks settings
  cp "$REPO_ROOT/core/hooks/auto-build-safety.sh" core/hooks/
  cp "$REPO_ROOT/core/hooks/evolution-guard.sh" core/hooks/
  cp "$REPO_ROOT/settings/settings.template.json" settings/
}

teardown_fixture() {
  cd "$PREV_CWD"
  rm -rf "$TMP"
}

echo "Test C1: dryrun"
setup_fixture
OUT=$(CLOUD_INIT_DRYRUN=1 bash "$SCRIPT" 2>&1)
EC=$?
assert_exit "C1.1 dryrun exit 0" 0 "$EC"
assert_contains "C1.2 stderr 'would install: ... safety hook'" "would install:.*auto-build-safety.sh" "$OUT"
assert_contains "C1.3 stderr 'would install: ... settings'" "would install:.*settings.json" "$OUT"
if [ ! -f .claude/hooks/auto-build-safety.sh ]; then
  echo "  ✓ C1.4 dryrun 실 파일 생성 X"
  PASS=$((PASS + 1))
else
  echo "  ✗ C1.4 dryrun이 파일 생성함"
  FAIL=$((FAIL + 1))
fi
teardown_fixture

echo "Test C2: 신규 install (fresh cloud session simulation)"
setup_fixture
OUT=$(bash "$SCRIPT" 2>&1)
EC=$?
assert_exit "C2.1 install exit 0" 0 "$EC"
assert_contains "C2.2 PreToolUse hook installed 메시지" "PreToolUse hook installed" "$OUT"
assert_contains "C2.3 settings.json staged 메시지" "settings.json staged" "$OUT"
if [ -x .claude/hooks/auto-build-safety.sh ]; then
  echo "  ✓ C2.4 hook 파일 executable bit 설정됨"
  PASS=$((PASS + 1))
else
  echo "  ✗ C2.4 hook executable 아님 또는 부재"
  FAIL=$((FAIL + 1))
fi
if [ -f .claude/settings.json ]; then
  echo "  ✓ C2.5 settings.json 파일 생성됨"
  PASS=$((PASS + 1))
else
  echo "  ✗ C2.5 settings.json 파일 부재"
  FAIL=$((FAIL + 1))
fi
if [ -x .claude/hooks/evolution-guard.sh ]; then
  echo "  ✓ C2.6 evolution-guard.sh 설치됨 (executable)"
  PASS=$((PASS + 1))
else
  echo "  ✗ C2.6 evolution-guard.sh 미설치"
  FAIL=$((FAIL + 1))
fi
teardown_fixture

echo "Test C3: skip if exists 정책 (default)"
setup_fixture
bash "$SCRIPT" >/dev/null 2>&1  # 1회 install
OUT=$(bash "$SCRIPT" 2>&1)
EC=$?
assert_exit "C3.1 재실행 exit 0" 0 "$EC"
assert_contains "C3.2 stderr 'skip — hook already exists'" "skip — hook already exists" "$OUT"
assert_contains "C3.3 stderr 'skip — settings already exists'" "skip — settings already exists" "$OUT"
teardown_fixture

echo "Test C4: CLOUD_INIT_FORCE=1 overwrite"
setup_fixture
bash "$SCRIPT" >/dev/null 2>&1
# 첫 install된 파일 변경 후 force 재install로 원복 확인
echo "MODIFIED" > .claude/settings.json
OUT=$(CLOUD_INIT_FORCE=1 bash "$SCRIPT" 2>&1)
EC=$?
assert_exit "C4.1 FORCE 재실행 exit 0" 0 "$EC"
assert_contains "C4.2 stderr 'staged' (skip 메시지 아님)" "settings.json staged" "$OUT"
if ! grep -q "MODIFIED" .claude/settings.json 2>/dev/null; then
  echo "  ✓ C4.3 settings.json overwrite됨 (MODIFIED 흔적 없음)"
  PASS=$((PASS + 1))
else
  echo "  ✗ C4.3 settings.json overwrite 안 됨"
  FAIL=$((FAIL + 1))
fi
teardown_fixture

echo "Test C5: source 파일 부재 시 exit 1"
setup_fixture
rm core/hooks/auto-build-safety.sh
bash "$SCRIPT" >/dev/null 2>&1; EC=$?
assert_exit "C5.1 hook source 부재 exit 1" 1 "$EC"
OUT=$(bash "$SCRIPT" 2>&1 || true)
assert_contains "C5.2 stderr ERROR" "ERROR — source hook not found" "$OUT"
teardown_fixture

setup_fixture
rm settings/settings.template.json
bash "$SCRIPT" >/dev/null 2>&1; EC=$?
assert_exit "C5.3 settings source 부재 exit 1" 1 "$EC"
teardown_fixture

echo "Test C6: F-A12 local-context — settings.local.json has hooks → skip settings.json"
setup_fixture
# 로컬 setup.sh 후 상태를 흉내 — settings.local.json 에 hooks 보유
mkdir -p .claude
echo '{"hooks":{"PostToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"x"}]}]},"env":{"X":"1"}}' > .claude/settings.local.json
OUT=$(bash "$SCRIPT" 2>&1)
EC=$?
assert_exit "C6.1 local context 감지 exit 0" 0 "$EC"
assert_contains "C6.2 stderr 'local context detected'" "local context detected" "$OUT"
if [ ! -f .claude/settings.json ]; then
  echo "  ✓ C6.3 settings.json 생성 안 됨 (F-A11 회피)"
  PASS=$((PASS + 1))
else
  echo "  ✗ C6.3 settings.json 생성됨 — F-A11 회피 실패"
  FAIL=$((FAIL + 1))
fi
# C6.4 FORCE=1 시 local context 무시하고 install
OUT=$(CLOUD_INIT_FORCE=1 bash "$SCRIPT" 2>&1)
assert_contains "C6.4 FORCE=1 시 local context override" "settings.json staged" "$OUT"
teardown_fixture

echo "Test C7: F-A12 cloud-context simulation — settings.local.json 부재 → 정상 install"
setup_fixture
# settings.local.json 없는 cloud 환경
OUT=$(bash "$SCRIPT" 2>&1)
EC=$?
assert_exit "C7.1 cloud context exit 0" 0 "$EC"
assert_contains "C7.2 stderr 'settings.json staged'" "settings.json staged" "$OUT"
if [ -f .claude/settings.json ]; then
  echo "  ✓ C7.3 settings.json 생성됨 (정상 cloud 동작 유지)"
  PASS=$((PASS + 1))
else
  echo "  ✗ C7.3 settings.json 생성 안 됨"
  FAIL=$((FAIL + 1))
fi
teardown_fixture

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
