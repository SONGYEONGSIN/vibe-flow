#!/bin/bash
# core/skills/audit/scripts/ledger.sh smoke test (AHE decision-observability)
# rules/harness-evolution.md §3 전역 단일 시퀀스 + §4 predicted/actual delta 추적.
# 실행: bash scripts/tests/audit-ledger-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/core/skills/audit/scripts/ledger.sh"

PASS=0
FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng()  { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export LEDGER="$TMP/audit-ledger.jsonl"

L() { bash "$SCRIPT" "$@"; }
mkfinding() {  # round component dimension
  jq -nc --arg r "$1" --arg c "$2" --arg d "$3" \
    '{round:$r, component:$c, dimension:$d, evidence:"f.sh:10 \"x\"",
      root_cause:"rc", fix:"surgical fix", predicted_delta:"+0.2"}'
}

echo "=== 전역 단일 시퀀스 id 부여 (dimension 무관 충돌 0) ==="
id1=$(mkfinding H skills D1 | L append)
id2=$(mkfinding H hooks D2 | L append)
id3=$(mkfinding H memory D3 | L append)
[ "$id1" = "F-H01" ] && ok "첫 finding → F-H01" || ng "id1=$id1 (want F-H01)"
[ "$id2" = "F-H02" ] && ok "둘째(다른 dimension) → F-H02 (충돌 없음)" || ng "id2=$id2 (want F-H02)"
[ "$id3" = "F-H03" ] && ok "셋째 → F-H03" || ng "id3=$id3 (want F-H03)"

echo "=== 라운드 분리 (다음 라운드는 01부터) ==="
idG=$(mkfinding G skills D1 | L append)
[ "$idG" = "F-G01" ] && ok "다른 라운드 G → F-G01 (라운드별 독립 번호)" || ng "idG=$idG (want F-G01)"
n=$(L next-num H)
[ "$n" = "04" ] && ok "next-num H = 04 (H 3건 뒤)" || ng "next-num H=$n (want 04)"

echo "=== open 목록 + resolve(actual_delta 반증) ==="
opencount=$(L open | wc -l | tr -d ' ')
[ "$opencount" = "4" ] && ok "open 4건" || ng "open=$opencount (want 4)"
L resolve F-H01 "+0.3 confirmed" verified >/dev/null
st=$(jq -r 'select(.id=="F-H01") | .status' "$LEDGER")
ad=$(jq -r 'select(.id=="F-H01") | .actual_delta' "$LEDGER")
[ "$st" = "verified" ] && ok "resolve → status=verified" || ng "status=$st"
[ "$ad" = "+0.3 confirmed" ] && ok "actual_delta 기록됨" || ng "actual_delta=$ad"
opencount2=$(L open | wc -l | tr -d ' ')
[ "$opencount2" = "3" ] && ok "resolve 후 open 3건" || ng "open=$opencount2 (want 3)"

echo "=== 가드: 잘못된 status / 없는 id 거부 ==="
L resolve F-H02 "x" bogus >/dev/null 2>&1 && ng "bogus status 통과됨" || ok "bogus status 거부 (exit≠0)"
L resolve F-Z99 "x" verified >/dev/null 2>&1 && ng "없는 id 통과됨" || ok "없는 id 거부 (exit≠0)"
echo '{"component":"skills"}' | L append >/dev/null 2>&1 && ng "round 누락 통과됨" || ok "round 누락 거부 (exit≠0)"

echo "=== refuted 경로 (fix 가 지표 못 움직임) ==="
L resolve F-H02 "0.0 no movement" refuted >/dev/null
rst=$(jq -r 'select(.id=="F-H02") | .status' "$LEDGER")
[ "$rst" = "refuted" ] && ok "refuted 상태 전이 (메타-학습 신호)" || ng "status=$rst"

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
