#!/bin/bash
# post-merge-verify.sh smoke (T4/PR-3) — 자율머지 후 fresh 검증 실패 시 auto-revert.
# 실행: bash scripts/tests/post-merge-verify-smoke.sh
#
# 계약: 머지 직후 deterministic health(sync-drift --check + check-doc-counts) 실패 →
#       해당 커밋 git revert + alert. 통과 → no-op. 노출창(bad merge)을 같은 밤 되돌린다.
# 테스트: MERGE_VERIFY_CHECK 로 health 명령 주입(격리), 임시 git repo 에서 revert 관찰.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PMV="$REPO_ROOT/core/skills/audit/scripts/post-merge-verify.sh"

PASS=0; FAIL=0
ok(){ echo "  ✓ $1"; PASS=$((PASS+1)); }
ng(){ echo "  ✗ $1"; FAIL=$((FAIL+1)); }

setup() {
  TMP=$(mktemp -d); PREV=$(pwd); cd "$TMP"
  git init -q; git config user.email t@t; git config user.name t
  echo base > f.txt; git add f.txt; git commit -qm "base"
  echo change > f.txt; git add f.txt; git commit -qm "target merge (entry X)"
  TARGET=$(git rev-parse HEAD)
}
teardown(){ cd "$PREV"; rm -rf "$TMP"; }

echo "Test V1: health 실패 → auto-revert 커밋 생성"
setup
MERGE_VERIFY_CHECK="false" bash "$PMV" "$TARGET" >/dev/null 2>&1; ec=$?
if git log --oneline | grep -qiE 'revert'; then ok "V1.1 revert 커밋 생성됨"; else ng "V1.1 revert 없음"; fi
[ "$ec" != "0" ] && ok "V1.2 exit≠0 (bad merge 신호)" || ng "V1.2 exit 0 (신호 소실)"
[ "$(cat f.txt)" = "base" ] && ok "V1.3 내용 revert됨(base 복원)" || ng "V1.3 내용 미복원: $(cat f.txt)"
teardown

echo "Test V2: health 통과 → no revert"
setup
MERGE_VERIFY_CHECK="true" bash "$PMV" "$TARGET" >/dev/null 2>&1; ec=$?
if git log --oneline | grep -qiE 'revert'; then ng "V2.1 불필요 revert 발생"; else ok "V2.1 revert 없음(정상)"; fi
[ "$ec" = "0" ] && ok "V2.2 exit 0 (healthy)" || ng "V2.2 exit≠0"
[ "$(cat f.txt)" = "change" ] && ok "V2.3 내용 유지" || ng "V2.3 내용 변경됨"
teardown

echo "Test V3: DRYRUN — 실패해도 실 revert 안 함"
setup
OUT=$(MERGE_VERIFY_CHECK="false" MERGE_VERIFY_DRYRUN=1 bash "$PMV" "$TARGET" 2>&1)
if git log --oneline | grep -qiE 'revert'; then ng "V3.1 dryrun 이 실 revert함"; else ok "V3.1 dryrun 실 revert 안 함"; fi
echo "$OUT" | grep -qiE 'would revert|revert.*dryrun|dryrun' && ok "V3.2 stderr 'would revert' 안내" || ng "V3.2 dryrun 안내 없음: $OUT"
teardown

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
