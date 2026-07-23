#!/bin/bash
# cloud-loop-prompt-smoke.sh (T3/PR-2) — AHE 폐루프 프롬프트 배선 무결성.
# 실행: bash scripts/tests/cloud-loop-prompt-smoke.sh
#
# 프롬프트는 자연어라 실행 단위 테스트가 불가 — 대신 (a)참조 스크립트 경로가 실존·실행가능
# (b)5 phase(health/verify/audit/enqueue/improve)가 모두 배선 (c)PR-only(auto-merge 금지)
# 명시를 게이트한다. broken path/누락 phase/auto-merge 유출 회귀를 차단.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROMPT="$REPO_ROOT/core/skills/auto-build/data/cloud-prompt-template.md"

PASS=0; FAIL=0
have() { if grep -qF "$2" "$PROMPT"; then echo "  ✓ $1"; PASS=$((PASS+1)); else echo "  ✗ $1 ('$2' 부재)"; FAIL=$((FAIL+1)); fi; }
# 스크립트는 프롬프트에서 `bash <path>` 로 호출 → 실행권한 불필요, 실존(-f)만 검증.
exe()  { if [ -f "$REPO_ROOT/$2" ]; then echo "  ✓ $1"; PASS=$((PASS+1)); else echo "  ✗ $1 ($2 부재)"; FAIL=$((FAIL+1)); fi; }

echo "Test L1: 프롬프트 파일 존재"
if [ -f "$PROMPT" ]; then echo "  ✓ L1.1 cloud-prompt-template.md 존재"; PASS=$((PASS+1)); else echo "  ✗ L1.1 부재"; FAIL=$((FAIL+1)); echo "PASS:$PASS FAIL:$FAIL"; exit 1; fi

echo "Test L2: 5 phase 배선"
have "L2.1 bootstrap cloud-init" "cloud-init.sh"
have "L2.2 HEALTH baseline"      "health-metric.sh"
have "L2.3 VERIFY pending-verify" "ledger.sh pending-verify"
have "L2.4 VERIFY resolve"        "ledger.sh resolve"
have "L2.5 AUDIT"                 "/audit"
have "L2.6 ENQUEUE"              "ledger.sh enqueue"
have "L2.7 IMPROVE run-cloud"     "run-cloud.sh"

echo "Test L3: 참조 스크립트 실존 + 실행가능"
exe "L3.1 cloud-init.sh"   "core/skills/auto-build/scripts/cloud-init.sh"
exe "L3.2 health-metric.sh" "core/skills/audit/scripts/health-metric.sh"
exe "L3.3 ledger.sh"        "core/skills/audit/scripts/ledger.sh"
exe "L3.4 run-cloud.sh"     "core/skills/auto-build/scripts/run-cloud.sh"
exe "L3.5 evolution-guard.sh" "core/hooks/evolution-guard.sh"

echo "Test L4: PR-only (auto-merge 금지 명시 + 실 merge 커맨드 부재)"
have "L4.1 auto-merge 금지 명시" "auto-merge 절대 금지"
if grep -qE '^\s*gh pr merge' "$PROMPT"; then
  echo "  ✗ L4.2 실 'gh pr merge' 커맨드 유출"; FAIL=$((FAIL+1))
else
  echo "  ✓ L4.2 실 merge 커맨드 없음"; PASS=$((PASS+1))
fi
have "L4.3 AUTO_BUILD_MODE=1 (guard 활성)" "AUTO_BUILD_MODE=1"

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
