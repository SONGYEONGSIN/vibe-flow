#!/bin/bash
# setup.sh core.hooksPath override 경고 smoke test (audit F-Q12)
# 실행: bash scripts/tests/hooks-path-warn-smoke.sh
#
# core.hooksPath 가 override 상태면 .git/hooks/post-commit 이 실행되지 않아
# commit_pushed telemetry 가 조용히 미기록된다. setup.sh 는 이 상태를 경고해야 한다.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SETUP_SH="$REPO_ROOT/setup.sh"

PASS=0
FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkproj() {  # $1 = 프로젝트 경로
  mkdir -p "$1" && (cd "$1" && git init -q)
}

echo "=== core.hooksPath 미설정(표준) — 경고 없음 ==="
PROJ1="$TMP/proj-standard"
mkproj "$PROJ1"
out1=$(cd "$PROJ1" && bash "$SETUP_SH" 2>&1)
if echo "$out1" | grep -q 'core.hooksPath'; then
  ng "표준 상태인데 hooksPath 경고가 출력됨(오탐)"
else
  ok "표준 상태 — 경고 없음"
fi

echo "=== core.hooksPath override — 경고 1줄 출력 ==="
PROJ2="$TMP/proj-override"
mkproj "$PROJ2"
(cd "$PROJ2" && git config core.hooksPath /nonexistent/custom-hooks)
out2=$(cd "$PROJ2" && bash "$SETUP_SH" 2>&1)
if echo "$out2" | grep -q 'core.hooksPath'; then
  ok "override 상태 — hooksPath 경고 출력됨"
else
  ng "override 상태인데 경고 없음 — post-commit 무효화가 무증상"
fi

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -eq 0 ]
