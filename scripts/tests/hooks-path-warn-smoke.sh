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

# 음성 케이스(표준 상태)는 **git config 를 격리해야** 한다. `git config core.hooksPath` 는
# local 뿐 아니라 global/system 도 읽으므로, 개발 머신에 global core.hooksPath 가 설정돼
# 있으면 fixture repo 도 override 로 보여 오탐으로 실패한다(실측: 이 머신 global =
# /Users/…/.config/git/hooks). 그건 setup.sh 의 결함이 아니다 — global hooksPath 도
# 실제로 .git/hooks 를 무효화하므로 경고가 옳다. 격리해야 하는 쪽은 테스트다.
GIT_ISOLATE=(env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1)

echo "=== core.hooksPath 미설정(표준) — 경고 없음 ==="
PROJ1="$TMP/proj-standard"
mkproj "$PROJ1"
out1=$(cd "$PROJ1" && "${GIT_ISOLATE[@]}" bash "$SETUP_SH" 2>&1)
if echo "$out1" | grep -q 'core.hooksPath'; then
  ng "표준 상태인데 hooksPath 경고가 출력됨(오탐)"
else
  ok "표준 상태 — 경고 없음"
fi

echo "=== core.hooksPath override — 경고 1줄 출력 ==="
PROJ2="$TMP/proj-override"
mkproj "$PROJ2"
(cd "$PROJ2" && git config --local core.hooksPath /nonexistent/custom-hooks)
out2=$(cd "$PROJ2" && "${GIT_ISOLATE[@]}" bash "$SETUP_SH" 2>&1)
if echo "$out2" | grep -q 'core.hooksPath'; then
  ok "override 상태 — hooksPath 경고 출력됨"
else
  ng "override 상태인데 경고 없음 — post-commit 무효화가 무증상"
fi

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -eq 0 ]
