#!/bin/bash
# round-backlog-guard.sh smoke — 미머지 감사 라운드가 현재 main 위에 있으면 새 라운드 보류.
# 실행: bash scripts/tests/round-backlog-guard-smoke.sh
#
# 배경: 09-21~10-17 사람 머지가 멈춘 동안 야간 루프가 같은 base(ceab844)에서 라운드 PR 22개를
# 쌓았다 — 매 라운드가 같은 VERIFY 를 반복하고 같은 fix(F-R08)를 4번 따로 냈다.
# 계약: 원격 chore/audit-round-* 중 "현재 origin/main 을 조상으로 갖고 1커밋 이상 앞선" 브랜치가
#   있으면 HOLD_BACKLOG(exit 1). main 이 그 뒤 움직였으면(낡은 base) 막지 않는다 → PROCEED(exit 0).
#   원격 조회 불가는 UNAVAILABLE(exit 0) — 판정 불가를 PROCEED 와 구분해 남긴다.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$REPO_ROOT/core/skills/audit/scripts/round-backlog-guard.sh"

PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS+1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

g() { git -C "$WORK" -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
commit() { echo "$1" >> "$WORK/f.txt"; g add f.txt; g commit -q -m "$1"; }

# 새 fixture: bare origin + work clone, main 1커밋
setup() {
  rm -rf "$TMP/origin.git" "$TMP/work"
  git init -q --bare "$TMP/origin.git"
  git -C "$TMP/origin.git" symbolic-ref HEAD refs/heads/main
  WORK="$TMP/work"
  git init -q "$WORK"
  g checkout -q -b main
  commit base
  g remote add origin "$TMP/origin.git"
  g push -q origin main
}

# $1 name $2 expected-decision $3 expected-exit
run() {
  local out ec got
  out=$(cd "$WORK" && bash "$GUARD" 2>/dev/null); ec=$?
  got=$(printf '%s\n' "$out" | sed -n 's/^DECISION=//p')
  if [ "$got" = "$2" ] && [ "$ec" = "$3" ]; then ok "$1 ($got, exit $ec)"
  else ng "$1 (want $2/exit $3, got '$got'/exit $ec)"; fi
  LAST_OUT="$out"
}

echo "Test G1: 라운드 브랜치 없음 → PROCEED"
setup
run "G1.1 빈 원격" PROCEED 0

echo "Test G2: 현재 main 위의 미머지 라운드 → HOLD_BACKLOG"
setup
g checkout -q -b chore/audit-round-BU; commit round-bu; g push -q origin chore/audit-round-BU; g checkout -q main
run "G2.1 BU 가 main tip 위" HOLD_BACKLOG 1
printf '%s' "$LAST_OUT" | grep -q 'chore/audit-round-BU' \
  && ok "G2.2 REASON 에 보류 원인 브랜치명" || ng "G2.2 REASON 에 브랜치명 없음: $LAST_OUT"

echo "Test G3: main 이 그 뒤 움직임(낡은 base) → PROCEED"
commit main-moved; g push -q origin main
run "G3.1 BU 의 base 가 이전 main" PROCEED 0

echo "Test G4: main tip 과 같은 커밋(앞선 커밋 0) → PROCEED"
setup
g push -q origin main:refs/heads/chore/audit-round-ZZ
run "G4.1 빈 라운드 브랜치" PROCEED 0

echo "Test G5: 라운드가 아닌 브랜치는 대상 아님 → PROCEED"
setup
g checkout -q -b fix/something; commit fix; g push -q origin fix/something; g checkout -q main
run "G5.1 fix/* 는 무시" PROCEED 0

echo "Test G6: 원격 조회 불가 → UNAVAILABLE (exit 0, PROCEED 와 구분)"
setup
g remote set-url origin "$TMP/does-not-exist.git"
run "G6.1 origin 접근 불가" UNAVAILABLE 0

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
