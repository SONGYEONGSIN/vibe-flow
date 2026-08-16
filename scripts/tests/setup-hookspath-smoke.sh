#!/bin/bash
# setup.sh core.hooksPath override 경고 smoke (F-Q12)
# 실행: bash scripts/tests/setup-hookspath-smoke.sh
#
# F-Q12: git config core.hooksPath 가 .git/hooks 가 아닌 값으로 override 되어
# 있으면 setup.sh 가 복사한 .git/hooks/post-commit 은 git 에 의해 실행되지 않는다
# (post-commit 이 조용히 무효화됨). setup.sh 는 이 상태를 감지해 경고 1줄을 출력해야 한다.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

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

# ── Test H1: setup.sh 소스에 core.hooksPath 검사 로직이 존재한다 ──
echo "Test H1: setup.sh checks core.hooksPath before installing post-commit"
SRC=$(sed -n '/# git post-commit hook 배포/,/^fi$/p' "$REPO_ROOT/setup.sh")
assert_contains "references core.hooksPath" "core\.hooksPath" "$SRC"
assert_contains "prints a warning line when overridden" "경고|WARN|override" "$SRC"

# ── Test H2: 실제 override 상태에서 검사 스니펫을 실행하면 경고를 낸다 ──
echo "Test H2: hooksPath override triggers actual warning output"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
git init -q "$TMPDIR/proj"
(
  cd "$TMPDIR/proj"
  mkdir -p custom-hooks
  git config core.hooksPath custom-hooks
)
# setup.sh 의 hooksPath 검사 블록만 발췌해 격리 실행 (전체 setup.sh 실행은 side-effect 위험)
BLOCK=$(sed -n '/# git post-commit hook 배포/,/^fi$/p' "$REPO_ROOT/setup.sh" | head -20)
OUT=$(cd "$TMPDIR/proj" && PROJECT_DIR="$TMPDIR/proj" SCRIPT_DIR="$REPO_ROOT" bash -c "$BLOCK" 2>&1)
assert_contains "actual override produces a warning" "hooksPath|경고|WARN" "$OUT"

echo ""
echo "PASS: $PASS  FAIL: $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "ALL TESTS PASSED"
  exit 0
else
  echo "TESTS FAILED"
  exit 1
fi
