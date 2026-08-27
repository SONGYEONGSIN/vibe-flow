#!/bin/bash
# ledger.sh reconcile smoke — 머지된 PR 기준 open→fixed 자동 전이 (audit F-AA03)
# 실행: bash scripts/tests/ledger-reconcile-smoke.sh
#
# 왜: fix PR 머지와 mark-fixed 가 분리돼 있어 사람이 빠뜨리면 finding 이 open 으로 남고,
# 다음 firing 의 Phase 3 가 **이미 끝난 일을 큐에 다시 넣는다**. 실사고(2026-08-24):
# F-AA10/F-AA11 이 #226/#227 머지 후에도 open 이라 재-enqueue 됐고, F-AA10 은 #227 이
# 뒤집은 억제형 방향이라 재적용되면 안 되는 건이었다.
#
# 왜 'PR 생성' 이 아니라 '머지' 기준인가: F-AA03 의 원 처방은 run-cloud 의
# status-update done(=PR 생성 시점) 직전 삽입이었다. 그러면 **머지되지 않은 PR** 의
# finding 이 fixed 로 굳어 재큐잉이 영원히 막힌다 — lifecycle(F-H07)은 mark-fixed 를
# 머지 시점으로 규정한다. 그래서 머지된 PR 목록을 근거로 삼는다.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LEDGER_SH="$REPO_ROOT/core/skills/audit/scripts/ledger.sh"

PASS=0
FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

L="$TMP/ledger.jsonl"
mk() {  # $1=id $2=status
  printf '{"round":"ZZ","id":"%s","component":"skills","dimension":"D1","evidence":"e","root_cause":"r","fix":"f","predicted_delta":"+0.1","status":"%s","actual_delta":null,"ts":"2026-01-01T00:00:00Z"}\n' "$1" "$2" >> "$L"
}
reset_ledger() {
  : > "$L"
  mk F-ZZ01 open      # 머지된 PR 에 등장 → fixed 되어야
  mk F-ZZ02 open      # 열린 PR 에만 등장 → 그대로 open
  mk F-ZZ03 verified  # 종결 상태 → 건드리면 안 됨
  mk F-ZZ04 open      # 등록 PR(chore) 제목에만 등장 → 후보 아님
}

# 머지된 PR 목록 스텁 (실 gh 의존 없이 분기만 검증 — F-AA14 교훈)
STUB="$TMP/merged.sh"
cat > "$STUB" <<'EOF'
#!/bin/bash
echo "fix(x): 뭔가 고침 (F-ZZ01)"
echo "chore: F-ZZ03 재확인"
echo "chore(audit): round ZZ 등록(F-ZZ04~F-ZZ05)"
EOF
chmod +x "$STUB"

echo "Test LR1: 머지된 PR 에 등장하는 open finding → fixed"
reset_ledger
out=$(LEDGER="$L" LEDGER_MERGED_PR_CMD="$STUB" bash "$LEDGER_SH" reconcile --apply 2>&1)
st1=$(jq -r 'select(.id=="F-ZZ01")|.status' "$L")
[ "$st1" = "fixed" ] && ok "LR1.1 F-ZZ01 open → fixed" \
  || ng "LR1.2 F-ZZ01 status=$st1 (want fixed) — 머지됐는데 재큐잉 대상으로 남는다"

echo "Test LR2: 머지 PR 에 없는 open 은 건드리지 않는다"
st2=$(jq -r 'select(.id=="F-ZZ02")|.status' "$L")
[ "$st2" = "open" ] && ok "LR2.1 F-ZZ02 open 유지 (미머지 fix 를 fixed 로 굳히지 않음)" \
  || ng "LR2.2 F-ZZ02 status=$st2 (want open) — 머지 안 된 건이 fixed 로 굳었다"

echo "Test LR3: 종결 상태는 역전 금지"
st3=$(jq -r 'select(.id=="F-ZZ03")|.status' "$L")
[ "$st3" = "verified" ] && ok "LR3.1 F-ZZ03 verified 유지 (단방향 상태머신)" \
  || ng "LR3.2 F-ZZ03 status=$st3 (want verified) — 종결 상태가 뒤집혔다"

echo "Test LR4: 무엇을 전이했는지 표면화"
echo "$out" | grep -q 'F-ZZ01' && ok "LR4.1 전이 대상 stdout 표면화" \
  || ng "LR4.2 조용한 전이 — 무엇이 닫혔는지 알 수 없다"

echo "Test LR5: 멱등 — 재실행해도 추가 전이 없음"
out2=$(LEDGER="$L" LEDGER_MERGED_PR_CMD="$STUB" bash "$LEDGER_SH" reconcile --apply 2>&1)
n=$(jq -r 'select(.status=="fixed")|.id' "$L" | wc -l | tr -d ' ')
[ "$n" = "1" ] && ok "LR5.1 재실행 후에도 fixed 1건" \
  || ng "LR5.2 fixed $n 건 — 중복 전이"

echo "Test LR6: 조회 수단 부재 시 no-op (실 gh 없는 환경)"
reset_ledger
LEDGER="$L" LEDGER_MERGED_PR_CMD="$TMP/nonexistent" bash "$LEDGER_SH" reconcile --apply >/dev/null 2>&1
st=$(jq -r 'select(.id=="F-ZZ01")|.status' "$L")
[ "$st" = "open" ] && ok "LR6.1 조회 실패 시 무변경 (빈 목록을 '머지 0건'으로 오독하지 않음)" \
  || ng "LR6.2 status=$st — 조회 실패인데 상태를 바꿨다"

echo "Test LR7: 기본은 report-only — 상태를 바꾸지 않는다"
# 제목만 봐도 잔여 오탐이 있다(등록만 한 id 가 제목에 실린 경우). 증거 없는 전이를 막는다.
reset_ledger
rep=$(LEDGER="$L" LEDGER_MERGED_PR_CMD="$STUB" bash "$LEDGER_SH" reconcile 2>&1)
st=$(jq -r 'select(.id=="F-ZZ01")|.status' "$L")
[ "$st" = "open" ] && ok "LR7.1 --apply 없이는 무변경" \
  || ng "LR7.2 status=$st — 기본 실행이 상태를 바꿨다"
echo "$rep" | grep -q 'F-ZZ01' && ok "LR7.2 후보를 보고한다" \
  || ng "LR7.3 후보 미보고 — report 모드가 무용"

echo "Test LR8: 등록 PR(chore) 제목은 후보가 아니다"
# `chore(audit): round X 등록(F-X01~F-X10)` 은 finding 을 만든 PR 이지 고친 PR 이 아니다.
reset_ledger
rep8=$(LEDGER="$L" LEDGER_MERGED_PR_CMD="$STUB" bash "$LEDGER_SH" reconcile 2>&1)
if echo "$rep8" | grep -q 'F-ZZ04'; then
  ng "LR8.2 등록 PR 의 F-ZZ04 가 후보에 올랐다 — 만든 것과 고친 것을 구분 못 한다"
else
  ok "LR8.1 등록 PR(chore) 제목 제외"
fi
echo "$rep8" | grep -q 'F-ZZ01' && ok "LR8.3 fix 제목은 여전히 후보" \
  || ng "LR8.4 fix 제목까지 걸러졌다 — 필터가 과차단"

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
