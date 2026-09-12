#!/bin/bash
# ledger.sh next-round smoke — 미머지 브랜치가 선점한 라벨까지 보고 채번 (audit F-AG05)
# 실행: bash scripts/tests/ledger-next-round-smoke.sh
#
# 실사고(2026-09-12): 라벨을 **main 원장만 보고** 정하는데, 머지 정체로 브랜치가 쌓이면
# 매 firing 이 같은 값을 다시 계산한다. 라운드 AF 가 3개 PR 에 중복 부여됐고 내용이
# 서로 달라 11건을 손으로 AI 로 재채번해야 했다(F-Y15 재발). 루프 자신도 F-AG05 로
# 이 결함을 지적했고, 08-24 firing 은 충돌을 예감해 라운드 개설을 포기했다(phase2-skip).
#
# 계약: next-round 는 (a) main 원장의 최신 라운드 (b) 원격 `chore/audit-round-*` 브랜치가
# 선점한 라벨 **양쪽의 최대값 + 1** 을 낸다. `git ls-remote` 만 쓰므로 gh 부재 환경
# (F-AI03 실측: cloud 에 gh 없음)에서도 동작한다 — 이게 gh 기반 조회를 쓰지 않은 이유다.

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
mkledger() {  # $1.. = 라운드 라벨들
  : > "$L"
  for r in "$@"; do
    printf '{"round":"%s","id":"F-%s01","component":"skills","dimension":"D1","evidence":"e","root_cause":"r","fix":"f","predicted_delta":"+0.1","status":"open","actual_delta":null,"ts":"2026-01-01T00:00:00Z"}\n' "$r" "$r" >> "$L"
  done
}
# 원격 브랜치 목록 스텁 (실 git ls-remote 의존 없이 분기만 검증 — F-AA14 교훈)
stub() { printf '#!/bin/bash\n%s\n' "$1" > "$TMP/lsr"; chmod +x "$TMP/lsr"; }

run() { LEDGER="$L" LEDGER_REMOTE_BRANCH_CMD="$TMP/lsr" bash "$LEDGER_SH" next-round 2>/dev/null; }

echo "Test NR1: 브랜치 선점 없으면 원장 최신의 다음"
mkledger A B C; stub 'true'
got=$(run); [ "$got" = "D" ] && ok "NR1.1 C → D" || ng "NR1.2 '$got' (want D)"

echo "Test NR2: 미머지 브랜치가 선점한 라벨을 건너뛴다 (F-AG05 핵심)"
mkledger AE; stub 'echo chore/audit-round-AF; echo chore/audit-round-AH'
got=$(run); [ "$got" = "AI" ] && ok "NR2.1 원장 AE + 브랜치 AF/AH → AI" \
  || ng "NR2.2 '$got' (want AI) — 미머지 브랜치 라벨을 못 보면 AF 가 재부여된다"

echo "Test NR3: 자리올림 Z → AA"
mkledger X Y Z; stub 'true'
got=$(run); [ "$got" = "AA" ] && ok "NR3.1 Z → AA" \
  || ng "NR3.2 '$got' (want AA) — 단일 알파벳 전제(F-AF02)가 남아 있다"

echo "Test NR4: 자리올림 AZ → BA"
mkledger AZ; stub 'true'
got=$(run); [ "$got" = "BA" ] && ok "NR4.1 AZ → BA" || ng "NR4.2 '$got' (want BA)"

echo "Test NR5: 브랜치명 대소문자·접미사 혼재 허용"
# 실제로 존재한 형태: chore/audit-round-af (소문자), chore/audit-round-AF-pending-relabel-AH
mkledger AC; stub 'echo chore/audit-round-ad; echo chore/audit-round-AF-pending-relabel-AH'
got=$(run); [ "$got" = "AI" ] && ok "NR5.1 소문자 ad + 접미사 AF..AH → AI" \
  || ng "NR5.2 '$got' (want AI) — 실제 브랜치명 변형을 못 읽는다"

echo "Test NR6: 조회 실패는 원장 기준으로 폴백하되 사유를 남긴다"
mkledger AC; stub 'exit 1'
out=$(LEDGER="$L" LEDGER_REMOTE_BRANCH_CMD="$TMP/lsr" bash "$LEDGER_SH" next-round 2>&1)
echo "$out" | grep -q 'AD' && ok "NR6.1 폴백으로 AD 산출" || ng "NR6.2 폴백 실패: $out"
echo "$out" | grep -qi '조회' && ok "NR6.3 조회 실패 사유 표면화" \
  || ng "NR6.4 조용한 폴백 — 선점 라벨을 못 본 채 채번했는지 알 수 없다"

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
