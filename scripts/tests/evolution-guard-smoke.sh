#!/bin/bash
# evolution-guard.sh smoke test (T2/PR-1 — TDD Iron Law 자기 적용)
# 실행: bash scripts/tests/evolution-guard-smoke.sh
#
# 검증: 자율 모드(AUTO_BUILD_MODE=1)에서 안전코어(denylist) 수정을 차단하되
#       사람(비-자율)·비보호 파일·조회는 통과.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/core/hooks/evolution-guard.sh"

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

# 격리된 임시 git repo + denylist + guard 구성
setup_fixture() {
  TMP=$(mktemp -d)
  PREV_CWD=$(pwd)
  cd "$TMP"
  git init -q
  mkdir -p core/hooks .claude
  cp "$SCRIPT" core/hooks/evolution-guard.sh
  cp "$REPO_ROOT/.claude/evolution-protected" .claude/evolution-protected 2>/dev/null || \
    cp "$REPO_ROOT/core/evolution-protected" .claude/evolution-protected 2>/dev/null || true
  GUARD="$TMP/core/hooks/evolution-guard.sh"
}

teardown_fixture() {
  cd "$PREV_CWD"
  rm -rf "$TMP"
}

# JSON 입력으로 guard 호출, exit code 반환
run_guard() {  # $1=AUTO_BUILD_MODE $2=json
  echo "$2" | AUTO_BUILD_MODE="$1" bash "$GUARD" >/dev/null 2>&1
  echo $?
}

echo "Test E1: 사람 모드(AUTO_BUILD_MODE 미설정) — 안전코어 편집 허용"
setup_fixture
EC=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"core/hooks/evolution-guard.sh"}}' | bash "$GUARD" >/dev/null 2>&1; echo $?)
assert_exit "E1.1 human + 안전코어 Edit → 통과" 0 "$EC"
teardown_fixture

echo "Test E2: 자율 모드 — 안전코어 Edit 차단"
setup_fixture
EC=$(run_guard 1 '{"tool_name":"Edit","tool_input":{"file_path":"core/hooks/evolution-guard.sh"}}')
assert_exit "E2.1 auto + evolution-guard.sh Edit → 차단" 2 "$EC"
EC=$(run_guard 1 '{"tool_name":"Edit","tool_input":{"file_path":"core/hooks/auto-build-safety.sh"}}')
assert_exit "E2.2 auto + auto-build-safety.sh Edit → 차단" 2 "$EC"
EC=$(run_guard 1 '{"tool_name":"Edit","tool_input":{"file_path":"validate.sh"}}')
assert_exit "E2.3 auto + validate.sh Edit → 차단" 2 "$EC"
teardown_fixture

echo "Test E3: 자율 모드 — 비보호 파일 Edit 허용"
setup_fixture
EC=$(run_guard 1 '{"tool_name":"Edit","tool_input":{"file_path":"core/skills/foo/SKILL.md"}}')
assert_exit "E3.1 auto + 비보호 파일 Edit → 통과" 0 "$EC"
teardown_fixture

echo "Test E4: 자율 모드 — denylist 자기 보호"
setup_fixture
EC=$(run_guard 1 '{"tool_name":"Write","tool_input":{"file_path":".claude/evolution-protected"}}')
assert_exit "E4.1 auto + denylist 자신 Write → 차단" 2 "$EC"
teardown_fixture

echo "Test E5: 자율 모드 — 절대경로 안전코어 차단 (basename 매칭)"
setup_fixture
EC=$(run_guard 1 "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TMP/.claude/hooks/command-guard.sh\"}}")
assert_exit "E5.1 auto + .claude/hooks/command-guard.sh(절대) Edit → 차단" 2 "$EC"
teardown_fixture

echo "Test E6: denylist 부재 → fail-closed (자율 편집 전면 차단)"
setup_fixture
rm -f .claude/evolution-protected
EC=$(run_guard 1 '{"tool_name":"Edit","tool_input":{"file_path":"core/skills/foo/SKILL.md"}}')
assert_exit "E6.1 auto + denylist 부재 + Edit → 차단(fail-closed)" 2 "$EC"
teardown_fixture

echo "Test E7: 자율 모드 — Bash로 안전코어 변경 시도 차단"
setup_fixture
EC=$(run_guard 1 '{"tool_name":"Bash","tool_input":{"command":"sed -i \"s/exit 2/exit 0/\" core/hooks/evolution-guard.sh"}}')
assert_exit "E7.1 auto + sed -i 안전코어 → 차단" 2 "$EC"
EC=$(run_guard 1 '{"tool_name":"Bash","tool_input":{"command":"echo x > validate.sh"}}')
assert_exit "E7.2 auto + redirect validate.sh → 차단" 2 "$EC"
teardown_fixture

echo "Test E8: 자율 모드 — Bash 조회(비변경)는 통과"
setup_fixture
EC=$(run_guard 1 '{"tool_name":"Bash","tool_input":{"command":"cat core/hooks/evolution-guard.sh"}}')
assert_exit "E8.1 auto + cat 안전코어 → 통과" 0 "$EC"
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
