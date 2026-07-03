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

echo "=== improve 자동화: enqueue (open finding → auto-build 큐, idempotent) ==="
# stub queue.sh — task 를 QSTORE 에 적재 + queued id 회신 (real queue.sh lock/의존 회피)
export QSTORE="$TMP/queue.jsonl"; : > "$QSTORE"
cat > "$TMP/queue.sh" <<'STUB'
#!/bin/bash
[ "$1" = "add" ] || exit 1
echo "$2" >> "$QSTORE"
echo "queued: Q-$(wc -l < "$QSTORE" | tr -d ' ')"
STUB
chmod +x "$TMP/queue.sh"
# 현재 open: F-H03, F-G01 (앞 단계서 H01 verified / H02 refuted)
QUEUE_SH="$TMP/queue.sh" L enqueue >/dev/null 2>&1
qn=$(wc -l < "$QSTORE" | tr -d ' ')
[ "$qn" = "2" ] && ok "open 2건 enqueue → 큐 2 task" || ng "큐 task=$qn (want 2)"
et=$(jq -r 'select(.id=="F-H03") | .enqueued_task' "$LEDGER")
if [ "$et" = "Q-1" ] || [ "$et" = "Q-2" ]; then ok "finding 에 enqueued_task 기록 ($et)"; else ng "enqueued_task=$et"; fi
grep -q 'audit F-H03' "$QSTORE" && ok "task 에 finding id+fix 컨텍스트 포함" || ng "task 컨텍스트 누락"
QUEUE_SH="$TMP/queue.sh" L enqueue >/dev/null 2>&1
qn2=$(wc -l < "$QSTORE" | tr -d ' ')
[ "$qn2" = "2" ] && ok "재실행 idempotent (중복 큐잉 0)" || ng "재실행 후 큐=$qn2 (want 2)"

echo "=== decision-observability: mark-fixed → pending-verify → resolve ==="
L mark-fixed F-H03 >/dev/null
[ "$(L pending-verify | grep -c 'F-H03')" = "1" ] && ok "mark-fixed 후 pending-verify 등장 (actual_delta null)" || ng "pending-verify 누락"
L pending-verify | grep -q 'F-G01' && ng "open finding 이 pending-verify 에 샘" || ok "open finding 은 pending-verify 제외"
L resolve F-H03 "+0.2 confirmed" verified >/dev/null
[ "$(L pending-verify | grep -c 'F-H03')" = "0" ] && ok "resolve(verified) 후 pending-verify 제거" || ng "여전히 pending"

mkf() { jq -nc '{round:"Z",component:"x",dimension:"D1",evidence:"e",root_cause:"r",fix:"f",predicted_delta:"p"}'; }

echo "=== R8 hardening: resolve 빈 actual_delta 거부 (F-H03) ==="
zid=$(mkf | L append)          # F-Z01
L mark-fixed "$zid" >/dev/null
mkf >/dev/null; L resolve "$zid" "" verified >/dev/null 2>&1 && ng "빈 actual_delta 통과됨" || ok "빈 actual_delta 거부 (F-H03)"
[ "$(L pending-verify | grep -c "$zid")" = "1" ] && ok "빈값 거부 → 미측정 finding 이 pending-verify 유지" || ng "pending-verify 에서 샘"

echo "=== R8 hardening: mark-fixed 단방향 가드 (F-H08) ==="
L resolve "$zid" "+0.1 measured" verified >/dev/null
L mark-fixed "$zid" >/dev/null 2>&1 && ng "verified→fixed 역전 허용됨" || ok "verified→fixed 역전 차단 (F-H08)"

echo "=== R8 hardening: next_num octal 경계 08→09 (F-H12) ==="
LED2="$TMP/led2.jsonl"; : > "$LED2"; lastid=""
for i in $(seq 1 9); do lastid=$(mkf | LEDGER="$LED2" bash "$SCRIPT" append); done
[ "$lastid" = "F-Z09" ] && ok "9번째 finding → F-Z09 (octal 08+1 오해석 없음)" || ng "9번째 id=$lastid (want F-Z09)"

echo "=== R8 hardening: append 동시성 유니크 id (F-H02 mkdir 락) ==="
LED3="$TMP/led3.jsonl"; : > "$LED3"
for i in 1 2 3 4 5; do ( mkf | LEDGER="$LED3" bash "$SCRIPT" append >/dev/null 2>&1 ) & done
wait
u=$(jq -r '.id' "$LED3" 2>/dev/null | sort -u | wc -l | tr -d ' '); t=$(wc -l < "$LED3" | tr -d ' ')
{ [ "$u" = "5" ] && [ "$t" = "5" ]; } && ok "병렬 5 append → 유니크 id 5/5 (race 없음)" || ng "uniq=$u total=$t (want 5/5)"

echo "=== R9: 병렬 resolve lost-update 없음 (F-I04 with_lock) ==="
LED4="$TMP/led4.jsonl"; : > "$LED4"
for i in 1 2 3 4 5 6; do mkf | LEDGER="$LED4" bash "$SCRIPT" append >/dev/null; done
for n in 01 02 03 04 05 06; do LEDGER="$LED4" bash "$SCRIPT" mark-fixed "F-Z$n" >/dev/null; done
for n in 01 02 03 04 05 06; do ( LEDGER="$LED4" bash "$SCRIPT" resolve "F-Z$n" "+0.1 m" verified >/dev/null 2>&1 ) & done
wait
vc=$(jq -r 'select(.status=="verified")|.id' "$LED4" 2>/dev/null | wc -l | tr -d ' ')
[ "$vc" = "6" ] && ok "6-way 병렬 resolve → 6건 전부 verified (lost-update 없음)" || ng "verified=$vc (want 6, lost-update)"
[ ! -d "$LED4.lock" ] && ok "정상 op 후 .lock 잔존 없음 (release_lock)" || ng ".lock 누수"

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
