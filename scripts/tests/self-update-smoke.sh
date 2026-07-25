#!/bin/bash
# self-update.sh smoke (T5/PR-4) — 자율 버전 bump 판정 + drift 검증.
# 실행: bash scripts/tests/self-update-smoke.sh
#
# 계약: 마지막 태그 이후 커밋에서 semver(feat→minor/fix→patch) 계산, drift 검증,
#       기본 AUTO_RELEASE off → HOLD_DISABLED(report-only, 태그 안 함). default-safe.
# 테스트: 임시 git repo(태그+커밋+plugin.json) + SELF_UPDATE_DRIFT_CHECK 주입.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SU="$REPO_ROOT/core/skills/audit/scripts/self-update.sh"

PASS=0; FAIL=0
field(){ printf '%s' "$1" | sed -n "s/^$2=//p"; }
setup() {
  TMP=$(mktemp -d); PREV=$(pwd); cd "$TMP"
  git init -q; git config user.email t@t; git config user.name t
  mkdir -p .claude-plugin
  echo '{"name":"vibe-flow","version":"2.4.0"}' > .claude-plugin/plugin.json
  echo '# Changelog' > CHANGELOG.md
  git add -A; git commit -qm "chore: base"; git tag v2.4.0
}
teardown(){ cd "$PREV"; rm -rf "$TMP"; }
run(){ SELF_UPDATE_DRIFT_CHECK="${DRIFT:-true}" AUTO_RELEASE="${AR:-off}" bash "$SU" 2>/dev/null; }

echo "Test U1: feat 커밋 → minor bump, 기본 HOLD_DISABLED(태그 안 함)"
setup
echo x>a; git add a; git commit -qm "feat: new thing"
OUT=$(run);
[ "$(field "$OUT" BUMP)" = "minor" ] && { echo "  ✓ U1.1 feat→minor"; PASS=$((PASS+1)); } || { echo "  ✗ U1.1 BUMP=$(field "$OUT" BUMP)"; FAIL=$((FAIL+1)); }
[ "$(field "$OUT" NEXT_VERSION)" = "2.5.0" ] && { echo "  ✓ U1.2 NEXT_VERSION=2.5.0"; PASS=$((PASS+1)); } || { echo "  ✗ U1.2 =$(field "$OUT" NEXT_VERSION)"; FAIL=$((FAIL+1)); }
[ "$(field "$OUT" DECISION)" = "HOLD_DISABLED" ] && { echo "  ✓ U1.3 기본 HOLD_DISABLED(off)"; PASS=$((PASS+1)); } || { echo "  ✗ U1.3 =$(field "$OUT" DECISION)"; FAIL=$((FAIL+1)); }
git tag | grep -q v2.5.0 && { echo "  ✗ U1.4 off인데 태그 생성됨"; FAIL=$((FAIL+1)); } || { echo "  ✓ U1.4 off → 태그 미생성"; PASS=$((PASS+1)); }
teardown

echo "Test U2: fix 커밋만 → patch"
setup
echo x>a; git add a; git commit -qm "fix: bug"
OUT=$(run)
[ "$(field "$OUT" BUMP)" = "patch" ] && { echo "  ✓ U2.1 fix→patch"; PASS=$((PASS+1)); } || { echo "  ✗ U2.1 =$(field "$OUT" BUMP)"; FAIL=$((FAIL+1)); }
[ "$(field "$OUT" NEXT_VERSION)" = "2.4.1" ] && { echo "  ✓ U2.2 NEXT_VERSION=2.4.1"; PASS=$((PASS+1)); } || { echo "  ✗ U2.2 =$(field "$OUT" NEXT_VERSION)"; FAIL=$((FAIL+1)); }
teardown

echo "Test U3: 태그 이후 커밋 0 → NO_CHANGES"
setup
OUT=$(run)
[ "$(field "$OUT" DECISION)" = "NO_CHANGES" ] && { echo "  ✓ U3.1 NO_CHANGES"; PASS=$((PASS+1)); } || { echo "  ✗ U3.1 =$(field "$OUT" DECISION)"; FAIL=$((FAIL+1)); }
teardown

echo "Test U4: drift 실패 → DRIFT_FAIL, exit≠0"
setup
echo x>a; git add a; git commit -qm "feat: x"
SELF_UPDATE_DRIFT_CHECK="false" AUTO_RELEASE="off" bash "$SU" >/dev/null 2>&1; ec=$?
OUT=$(SELF_UPDATE_DRIFT_CHECK="false" AUTO_RELEASE="off" bash "$SU" 2>/dev/null)
[ "$(field "$OUT" DECISION)" = "DRIFT_FAIL" ] && { echo "  ✓ U4.1 DRIFT_FAIL"; PASS=$((PASS+1)); } || { echo "  ✗ U4.1 =$(field "$OUT" DECISION)"; FAIL=$((FAIL+1)); }
[ "$ec" != "0" ] && { echo "  ✓ U4.2 exit≠0"; PASS=$((PASS+1)); } || { echo "  ✗ U4.2 exit 0"; FAIL=$((FAIL+1)); }
teardown

echo "Test U5: AUTO_RELEASE=on → plugin.json 버전 bump + 태그(RELEASE_APPLIED)"
setup
echo x>a; git add a; git commit -qm "feat: y"
OUT=$(SELF_UPDATE_DRIFT_CHECK="true" AUTO_RELEASE="on" bash "$SU" 2>/dev/null)
[ "$(field "$OUT" DECISION)" = "RELEASE_APPLIED" ] && { echo "  ✓ U5.1 RELEASE_APPLIED"; PASS=$((PASS+1)); } || { echo "  ✗ U5.1 =$(field "$OUT" DECISION)"; FAIL=$((FAIL+1)); }
[ "$(jq -r .version .claude-plugin/plugin.json)" = "2.5.0" ] && { echo "  ✓ U5.2 plugin.json 2.5.0"; PASS=$((PASS+1)); } || { echo "  ✗ U5.2 =$(jq -r .version .claude-plugin/plugin.json)"; FAIL=$((FAIL+1)); }
git tag | grep -q v2.5.0 && { echo "  ✓ U5.3 v2.5.0 태그 생성"; PASS=$((PASS+1)); } || { echo "  ✗ U5.3 태그 없음"; FAIL=$((FAIL+1)); }
teardown

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
