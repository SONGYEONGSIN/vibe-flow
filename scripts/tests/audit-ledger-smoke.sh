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
# F-R06(#185) 이 resolve) 에 queue.sh status-update 호출을 추가한 뒤로, enqueued_task 가
# 채워진 finding 을 resolve 하는 구간이 **실** .claude/memory/auto-build-queue.jsonl 에
# 쓴다(stub id "Q-1" 이 실 store 로 누출된 것을 실측). LEDGER 처럼 최상단에서 전역
# 격리해, 이후 어떤 섹션을 추가해도 실 store 를 오염시킬 수 없게 한다.
export QUEUE_STORE="$TMP/auto-build-queue.jsonl"

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

# F-P05 (audit round P): round 커맨드(Phase5 라운드 리포트, 헤더에 공개 API 로 문서화)가
# 테스트 커버리지 0 이었음 — 라운드 필터 + tab-필드 포맷 회귀를 게이트.
rout=$(L round H)
h_lines=$(printf '%s\n' "$rout" | grep -cE '^F-H0[123]')
[ "$h_lines" = "3" ] && ok "round H = F-H01~03 3줄" || ng "round H 출력 이상: $rout"
printf '%s\n' "$rout" | grep -qE '^F-G' && ng "round H 에 G 라운드 누출(필터 실패)" || ok "round H 라운드 필터 정확(G 미포함)"
printf '%s\n' "$rout" | head -1 | grep -qE '^F-H0[123].*open' && ok "round H tab-필드(id+status) 포맷" || ng "round H 포맷 이상: $(printf '%s' "$rout" | head -1)"

# F-Q09 (audit round Q): 위 두 assertion 은 id/status(1·2번째 tab-필드)만 검증해
# predicted_delta/actual_delta(3·4번째)가 append/resolve 값과 실제로 대조되는지는
# 반증 안 된 사각이었다 — 변이 주입 실측(.predicted_delta 오타 → smoke exit 0 그대로)으로 확인.
h01_line=$(printf '%s\n' "$rout" | grep '^F-H01')
h01_predicted=$(printf '%s' "$h01_line" | cut -f3)
[ "$h01_predicted" = "+0.2" ] && ok "round H 3번째 필드(predicted_delta) = append 값" || ng "predicted_delta=$h01_predicted (want +0.2)"
h01_actual=$(printf '%s' "$h01_line" | cut -f4)
[ "$h01_actual" = "-" ] && ok "round H 4번째 필드(actual_delta) = 미해결 시 '-'" || ng "actual_delta=$h01_actual (want -)"

echo "=== open 목록 + resolve(actual_delta 반증) ==="
opencount=$(L open | wc -l | tr -d ' ')
[ "$opencount" = "4" ] && ok "open 4건" || ng "open=$opencount (want 4)"
L resolve F-H01 "+0.3 confirmed" verified >/dev/null
st=$(jq -r 'select(.id=="F-H01") | .status' "$LEDGER")
ad=$(jq -r 'select(.id=="F-H01") | .actual_delta' "$LEDGER")
[ "$st" = "verified" ] && ok "resolve → status=verified" || ng "status=$st"
[ "$ad" = "+0.3 confirmed" ] && ok "actual_delta 기록됨" || ng "actual_delta=$ad"
rout2=$(L round H)
h01_actual2=$(printf '%s\n' "$rout2" | grep '^F-H01' | cut -f4)
[ "$h01_actual2" = "+0.3 confirmed" ] && ok "round H 4번째 필드(actual_delta) resolve 후 갱신 반영" || ng "round 재조회 actual_delta=$h01_actual2 (want +0.3 confirmed)"
opencount2=$(L open | wc -l | tr -d ' ')
[ "$opencount2" = "3" ] && ok "resolve 후 open 3건" || ng "open=$opencount2 (want 3)"

echo "=== 가드: 잘못된 status / 없는 id 거부 ==="
L resolve F-H02 "x" bogus >/dev/null 2>&1 && ng "bogus status 통과됨" || ok "bogus status 거부 (exit≠0)"
L resolve F-Z99 "x" verified >/dev/null 2>&1 && ng "없는 id 통과됨" || ok "없는 id 거부 (exit≠0)"
echo '{"component":"skills"}' | L append >/dev/null 2>&1 && ng "round 누락 통과됨" || ok "round 누락 거부 (exit≠0)"

# F-K01 (audit R11): SKILL.md 가 선언한 "4 필드 누락 시 append 거부" 계약이 실재하는지.
# 계약 부재 시 4 필드 전부 null 인 finding 이 유효 id 를 달고 status:open 으로 기록되어,
# 다음 라운드 pending-verify 가 반증할 predicted_delta 자체를 잃는다 (폐루프 단락).
echo '{"round":"ZZ"}' | L append >/dev/null 2>&1 && ng "4 필드 전부 누락 통과됨" || ok "4 필드 누락 거부 (exit≠0)"
for miss in evidence root_cause fix predicted_delta; do
  jq -nc --arg m "$miss" '{round:"ZZ",evidence:"e",root_cause:"r",fix:"f",predicted_delta:"p"}
    | del(.[$m])' | L append >/dev/null 2>&1 \
    && ng "$miss 누락 통과됨" || ok "$miss 누락 거부 (exit≠0)"
done
# 빈 문자열도 누락과 동치 (resolve 의 F-H03 과 동형)
echo '{"round":"ZZ","evidence":"","root_cause":"r","fix":"f","predicted_delta":"p"}' \
  | L append >/dev/null 2>&1 && ng "빈 evidence 통과됨" || ok "빈 evidence 거부 (exit≠0)"

# F-O01 (audit round P): component/dimension 귀속도 강제 (SKILL.md Phase2 요구 축).
# null/null 이 enqueue 큐 task 문자열 "[audit id/null/null]" 로 꽂히던 오염 차단.
for miss in component dimension; do
  jq -nc --arg m "$miss" '{round:"ZZ",component:"skills",dimension:"D2",evidence:"e",root_cause:"r",fix:"f",predicted_delta:"p"}
    | del(.[$m])' | L append >/dev/null 2>&1 \
    && ng "$miss 누락 통과됨" || ok "$miss 누락 거부 (exit≠0)"
done

echo "=== refuted 경로 (fix 가 지표 못 움직임) ==="
L resolve F-H02 "0.0 no movement" refuted >/dev/null
rst=$(jq -r 'select(.id=="F-H02") | .status' "$LEDGER")
[ "$rst" = "refuted" ] && ok "refuted 상태 전이 (메타-학습 신호)" || ng "status=$rst"

# F-K02 (audit R11): mark-fixed 는 F-H08 로 단방향 가드를 얻었으나 resolve 는 무가드였다.
# 종결(verified/refuted)된 finding 의 측정값이 조용히 덮어써지면 감사 이력이 재기록 가능해진다.
echo "=== 가드: resolve 종결 상태 역전 차단 (F-K02) ==="
L resolve F-H01 "OVERWRITTEN -9.9" refuted >/dev/null 2>&1 \
  && ng "verified → refuted 역전 통과됨" || ok "verified 역전 거부 (exit≠0)"
ad1=$(jq -r 'select(.id=="F-H01") | .actual_delta' "$LEDGER")
[ "$ad1" = "+0.3 confirmed" ] && ok "원 측정값 보존됨" || ng "actual_delta 덮어써짐: $ad1"
L resolve F-H02 "flip" verified >/dev/null 2>&1 \
  && ng "refuted → verified 역전 통과됨" || ok "refuted 역전 거부 (exit≠0)"

# resolve 로 status=fixed 를 쓰면 actual_delta 가 채워진 채 fixed 가 되어
# open(status=="open") 과 pending-verify(actual_delta=="") 양쪽 워크리스트에서 사라진다.
# 다음 라운드 Phase 0 은 빈 pending-verify 를 "전부 검증됨"으로 읽는다. mark-fixed 가 유일 경로.
L resolve F-H03 "x" fixed >/dev/null 2>&1 \
  && ng "resolve → fixed 통과됨 (워크리스트 소실)" || ok "resolve → fixed 거부 (mark-fixed 전용)"

# F-K11 (audit R11): 손상된 라인 1개가 next_num 과 id 충돌검사 둘 다를 fail-open 시켜
# 이미 존재하는 id 를 재발급한다 (중복 primary key). 격리된 LEDGER 로 검증.
echo "=== 가드: 손상된 ledger 감지 (F-K11) ==="
CORRUPT="$TMP/corrupt.jsonl"
printf 'NOT JSON AT ALL\n{"ts":"t","round":"B","id":"F-B01","status":"open"}\n' > "$CORRUPT"
out=$(mkfinding B skills D1 | LEDGER="$CORRUPT" bash "$SCRIPT" append 2>&1); rc=$?
[ "$rc" -eq 3 ] && ok "손상 ledger → exit 3" || ng "손상 ledger append rc=$rc (want 3), out=$out"
dup=$(grep -c '"id":"F-B01"' "$CORRUPT")
[ "$dup" -eq 1 ] && ok "중복 id 미발급" || ng "F-B01 이 ${dup}건 (중복 primary key)"

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

echo "=== F-R06: resolve 가 enqueue 된 큐 entry 도 닫는다 (이중장부 분기 차단) ==="
# ledger 는 resolve 로 닫히는데 queue 엔트리를 닫는 주체가 없어, 이미 verified 된
# finding 이 queued 좀비로 남아 첫 firing 이 끝난 일을 pop 한다(R17/R 실측 8건).
QSTORE="$TMP/queue.jsonl"; : > "$QSTORE"
QSH="$REPO_ROOT/core/skills/auto-build/scripts/queue.sh"
rid=$(mkfinding R6 skills D2 | L append)
QUEUE_STORE="$QSTORE" LEDGER="$LEDGER" bash "$SCRIPT" enqueue R6 >/dev/null 2>&1
qid=$(jq -r 'select(.op!="status_update")|.id' "$QSTORE" 2>/dev/null | head -1)
if [ -z "$qid" ]; then
  ng "enqueue 가 큐 entry 를 만들지 못함 — 전제 실패"
else
  L mark-fixed "$rid" >/dev/null
  QUEUE_STORE="$QSTORE" LEDGER="$LEDGER" bash "$SCRIPT" resolve "$rid" "+0.1 측정" verified >/dev/null
  qst=$(QUEUE_STORE="$QSTORE" bash "$QSH" list --all 2>/dev/null | awk -v i="$qid" '$1==i{print $2}')
  [ "$qst" = "aborted" ] && ok "resolve → 큐 entry $qid 가 aborted 로 전이" \
    || ng "resolve 후에도 큐 entry $qid status=$qst (좀비 잔존, want aborted)"
  # enqueued_task 가 없는 finding 은 큐 조작 없이 정상 resolve 되어야 한다(회귀 가드)
  rid2=$(mkfinding R6 memory D1 | L append)
  L mark-fixed "$rid2" >/dev/null
  if QUEUE_STORE="$QSTORE" LEDGER="$LEDGER" bash "$SCRIPT" resolve "$rid2" "+0.1" verified >/dev/null 2>&1; then
    ok "enqueued_task 없는 finding 도 resolve 정상 (부작용 없음)"
  else
    ng "enqueued_task 없는 finding 의 resolve 가 깨짐"
  fi
fi

echo "=== F-V08: 오검증 정정 경로 (correct) ==="
# F-K02 가 넣은 종결-상태 가드는 '악의적 재기록'과 '오검증 정정'을 구분하지 못한다.
# 실제 사고: R21/V 가 무효 계기(push --dry-run)로 F-S10 을 거짓 refuted 처리했고,
# 실 push 거부 로그를 확보하고도 resolve 가 거부해 되돌릴 수 없었다(F-V07/F-V08).
# correct 는 원 값을 correction 레코드로 보존한 채 종결 상태를 정정한다.
CID=$(mkf | L append)                       # F-Z**
L mark-fixed "$CID" >/dev/null
L resolve "$CID" "+0.1 잘못된 측정" verified >/dev/null

L correct "$CID" refuted "0.0 실측 재수행" "무효 계기로 판정했음" >/dev/null 2>&1
cst=$(jq -r --arg i "$CID" 'select(.id==$i) | .status' "$LEDGER")
cad=$(jq -r --arg i "$CID" 'select(.id==$i) | .actual_delta' "$LEDGER")
[ "$cst" = "refuted" ] && ok "correct → 종결 상태 정정 (verified→refuted)" || ng "status=$cst (want refuted)"
[ "$cad" = "0.0 실측 재수행" ] && ok "actual_delta 재측정값으로 교체" || ng "actual_delta=$cad"

# 원 값이 correction 레코드로 보존돼야 한다 — 정정은 삭제가 아니다
prev=$(jq -r --arg i "$CID" 'select(.op=="correction") | select(.target_id==$i) | .prev_status' "$LEDGER" 2>/dev/null)
[ "$prev" = "verified" ] && ok "correction 레코드에 prev_status 보존" || ng "prev_status=$prev (이력 소실)"
preva=$(jq -r --arg i "$CID" 'select(.op=="correction") | select(.target_id==$i) | .prev_actual_delta' "$LEDGER" 2>/dev/null)
[ "$preva" = "+0.1 잘못된 측정" ] && ok "correction 레코드에 prev_actual_delta 보존" || ng "prev_actual_delta=$preva"
rsn=$(jq -r --arg i "$CID" 'select(.op=="correction") | select(.target_id==$i) | .reason' "$LEDGER" 2>/dev/null)
[ -n "$rsn" ] && [ "$rsn" != "null" ] && ok "correction 사유 기록" || ng "reason 누락"

echo "=== F-V08 가드 ==="
L correct "$CID" verified "x" "" >/dev/null 2>&1 && ng "빈 사유 통과됨" || ok "빈 사유 거부 (정정은 근거 필수)"
L correct "F-ZZ99" verified "x" "r" >/dev/null 2>&1 && ng "없는 id 통과됨" || ok "없는 id 거부"
OID=$(mkf | L append)
L correct "$OID" verified "x" "r" >/dev/null 2>&1 && ng "open 상태 correct 통과됨" || ok "비-종결 상태 거부 (resolve 를 쓸 것)"
L correct "$CID" bogus "x" "r" >/dev/null 2>&1 && ng "bogus status 통과됨" || ok "bogus status 거부"

# 조회 커맨드가 correction 레코드에 오염되지 않아야 한다
opn=$(L open | grep -c "$OID")
[ "$opn" = "1" ] && ok "open 목록이 correction 레코드에 영향 없음" || ng "open 출력 이상"
rnd=$(L round Z | grep -c "^$CID")
[ "$rnd" = "1" ] && ok "round 출력에 finding 1행만 (correction 미유출)" || ng "round 출력 행수 이상: $rnd"

echo "=== F-Q20: 실 repo ledger 자신을 검증 (정본 파일이 무게이트였음) ==="
# 종전 스모크는 전부 fixture 위에서만 돌아, 정본 .claude/memory/audit-ledger.jsonl 이
# 손상돼도(수기 편집·부분 write) 어떤 테스트도 울지 않았다. 아래 validator 를
# (a) 실 ledger 와 (b) 변이 사본 양쪽에 적용해, 검사가 공허하지 않음을 함께 보인다.
REAL_LEDGER="$REPO_ROOT/.claude/memory/audit-ledger.jsonl"
# 필수 키: rules/harness-evolution.md §4 의 ledger entry 계약 중 반증 루프가 소비하는 축
validate_ledger() {  # <file> → 위반 사유를 stdout 으로, 위반 0 이면 무출력
  local f="$1" n=0
  while IFS= read -r line; do
    n=$((n+1))
    [ -z "$line" ] && continue
    if ! echo "$line" | jq -e . >/dev/null 2>&1; then echo "line $n: JSON 파싱 실패"; continue; fi
    # F-V08: 원장에는 finding 엔트리 외에 correction(op) 레코드가 섞인다. 두 종류는
    # 필수 키가 다르므로 종류별로 검증한다 — op 라인을 그냥 skip 하면 correction 이
    # 무게이트가 되어 F-Q20 이 닫은 "정본 파일이 검증 밖" 사각이 되돌아온다.
    if [ "$(echo "$line" | jq -r '.op // ""')" = "correction" ]; then
      for k in target_id prev_status new_status reason ts; do
        echo "$line" | jq -e --arg k "$k" 'has($k)' >/dev/null 2>&1 || echo "line $n(correction): .$k 부재"
      done
      continue
    fi
    for k in round id status predicted_delta; do
      echo "$line" | jq -e --arg k "$k" 'has($k)' >/dev/null 2>&1 || echo "line $n: .$k 부재"
    done
  done < "$f"
}

if [ ! -f "$REAL_LEDGER" ]; then
  ng "실 ledger 부재 — $REAL_LEDGER"
else
  violations=$(validate_ledger "$REAL_LEDGER")
  if [ -z "$violations" ]; then
    ok "실 ledger 전 라인 유효 JSON + round/id/status/predicted_delta 보유 ($(grep -c . "$REAL_LEDGER")건)"
  else
    ng "실 ledger 계약 위반: $(echo "$violations" | head -3 | tr '\n' ';')"
  fi

  # 비공허 대조 — 변이를 실제로 잡는지 확인 (잡지 못하면 위 통과는 무의미)
  MUT="$TMP/mutated.jsonl"
  head -1 "$REAL_LEDGER" | jq -c 'del(.predicted_delta)' > "$MUT"
  echo '{"round":"X","id":"F-X01",' >> "$MUT"   # 손상 라인(불완전 JSON)
  mv=$(validate_ledger "$MUT")
  if echo "$mv" | grep -q 'predicted_delta 부재' && echo "$mv" | grep -q 'JSON 파싱 실패'; then
    ok "변이 주입(키 삭제 + 손상 라인) 양쪽 검출 — 검사 비공허"
  else
    ng "변이 미검출 — 실 ledger 통과가 공허함: $mv"
  fi
fi

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
