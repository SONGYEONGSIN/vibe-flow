#!/bin/bash
set -u
# round-backlog-guard.sh — 미머지 감사 라운드가 현재 main 위에 있으면 새 라운드를 보류한다.
#
# 배경: 자율 루프는 PR-only(merge-gate HOLD_TIER)라 main 은 사람 머지로만 움직인다.
#   09-21~10-17 사람 머지가 멈춘 동안 매 firing 이 같은 base(ceab844)에서 라운드를 새로 돌려
#   PR 22개가 쌓였다 — 같은 VERIFY 반복, queue 충돌마커 매일 재수복, 같은 fix(F-R08) 4중 PR.
#   이전 라운드가 착지하지 않은 채 같은 main 에서 다시 도는 라운드는 중복만 만든다.
#
# 판정: 원격 chore/audit-round-* 중 "현재 origin/main 을 조상으로 갖고 1커밋 이상 앞선" 브랜치
#   = 현재 main 위의 미착지 라운드 → HOLD_BACKLOG. main 이 그 뒤 움직였으면 그 브랜치는 낡은
#   base 라 막지 않는다(머지·폐기된 옛 브랜치가 남아 있어도 오작동 없음).
#   gh 대신 git 만 쓴다 — cloud 세션엔 gh 가 없다(F-AI03).
#
# 출력: stdout "DECISION=<PROCEED|HOLD_BACKLOG|UNAVAILABLE>\nREASON=<...>"
#   exit 0 = PROCEED / UNAVAILABLE(조회 불가 — 판정 못 했음을 PROCEED 와 구분해 남김)
#   exit 1 = HOLD_BACKLOG
# env: ROUND_GUARD_REMOTE(기본 origin)

REMOTE="${ROUND_GUARD_REMOTE:-origin}"
NS="refs/round-backlog-guard"

emit() { echo "DECISION=$1"; echo "REASON=$2"; [ "$1" = "HOLD_BACKLOG" ] && exit 1 || exit 0; }

# 전용 ref 네임스페이스로 받는다 — 사용자 remote-tracking ref 를 건드리지 않고, 종료 시 지운다.
cleanup() { git for-each-ref --format='%(refname)' "$NS/" | while read -r r; do git update-ref -d "$r"; done; }
cleanup; trap cleanup EXIT
git fetch -q "$REMOTE" "+refs/heads/main:$NS/main" "+refs/heads/chore/audit-round-*:$NS/rounds/*" 2>/dev/null \
  || emit "UNAVAILABLE" "원격($REMOTE) 조회 실패 — 백로그 판정 불가, 라운드 진행"

MAIN=$(git rev-parse "$NS/main")
HELD=""
for r in $(git for-each-ref --format='%(refname)' "$NS/rounds/"); do
  [ "$(git rev-parse "$r")" = "$MAIN" ] && continue
  git merge-base --is-ancestor "$MAIN" "$r" && HELD="$HELD chore/audit-round-${r#$NS/rounds/}"
done

[ -n "$HELD" ] && emit "HOLD_BACKLOG" "현재 main(${MAIN:0:7}) 위에 미머지 라운드:${HELD} — 사람 머지/폐기 후 재개"
emit "PROCEED" "현재 main(${MAIN:0:7}) 위 미머지 라운드 없음"
