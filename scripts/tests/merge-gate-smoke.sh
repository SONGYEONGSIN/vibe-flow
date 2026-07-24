#!/bin/bash
# merge-gate.sh smoke (T4/PR-3) — 자율 auto-merge 적격 판정.
# 실행: bash scripts/tests/merge-gate-smoke.sh
#
# 계약: 안전코어 touch → 절대 REJECT / CI 미green → HOLD / tier 미graduate → HOLD.
# 기본 AUTO_MERGE_TIER=off → 전부 HOLD (default-safe: T4 머지가 라이브 자율머지 안 켬).
# 테스트 주입: MERGE_GATE_FILES(변경파일) / MERGE_GATE_CI(green|failed|pending) / AUTO_MERGE_TIER.

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$REPO_ROOT/core/skills/audit/scripts/merge-gate.sh"

PASS=0; FAIL=0
# $1 name $2 expected-decision $3 files $4 ci $5 tier
chk() {
  local out ec
  out=$(MERGE_GATE_FILES="$3" MERGE_GATE_CI="$4" AUTO_MERGE_TIER="$5" bash "$GATE" 2>/dev/null)
  ec=$?
  local got; got=$(printf '%s' "$out" | sed -n 's/^DECISION=//p')
  if [ "$got" = "$2" ]; then echo "  ✓ $1 ($got)"; PASS=$((PASS+1));
  else echo "  ✗ $1 (want $2, got '$got', exit $ec)"; FAIL=$((FAIL+1)); fi
}
# exit code 계약: AUTO_MERGE=0, 그 외=1
chk_exit() {
  MERGE_GATE_FILES="$2" MERGE_GATE_CI="$3" AUTO_MERGE_TIER="$4" bash "$GATE" >/dev/null 2>&1
  local ec=$?
  if [ "$ec" = "$5" ]; then echo "  ✓ $1 (exit $ec)"; PASS=$((PASS+1));
  else echo "  ✗ $1 (want exit $5, got $ec)"; FAIL=$((FAIL+1)); fi
}

echo "Test M1: 안전코어 touch → REJECT (tier·CI 무관)"
chk "M1.1 evolution-guard.sh + green + generative → REJECT" "REJECT_SAFETY_CORE" "core/hooks/evolution-guard.sh" "green" "generative"
chk "M1.2 validate.sh + green + docs → REJECT" "REJECT_SAFETY_CORE" "validate.sh README.md" "green" "docs"
chk "M1.3 denylist 자신 → REJECT" "REJECT_SAFETY_CORE" ".claude/evolution-protected" "green" "structural"

echo "Test M2: default-safe (AUTO_MERGE_TIER=off) → 전부 HOLD"
chk "M2.1 docs + green + off → HOLD" "HOLD_TIER" ".claude/memory/MEMORY.md" "green" "off"
chk "M2.2 docs + green + (미설정=off) → HOLD" "HOLD_TIER" "docs/architecture.html" "green" ""

echo "Test M3: tier graduation"
chk "M3.1 docs + green + tier=docs → AUTO_MERGE" "AUTO_MERGE" ".claude/memory/MEMORY.md" "green" "docs"
chk "M3.2 structural(rule) + green + tier=docs → HOLD (tier 초과)" "HOLD_TIER" "core/rules/git.md" "green" "docs"
chk "M3.3 structural + green + tier=structural → AUTO_MERGE" "AUTO_MERGE" "core/rules/git.md" "green" "structural"
chk "M3.4 docs + green + tier=structural → AUTO_MERGE (하위 포함)" "AUTO_MERGE" "README.md" "green" "structural"

echo "Test M4: CI gate"
chk "M4.1 docs + CI failed + tier=docs → HOLD_CI" "HOLD_CI_FAILED" "README.md" "failed" "docs"
chk "M4.2 docs + CI pending + tier=docs → HOLD_CI" "HOLD_CI_PENDING" "README.md" "pending" "docs"

echo "Test M5: exit code (AUTO_MERGE=0, 그 외=1)"
chk_exit "M5.1 AUTO_MERGE → exit 0" "README.md" "green" "docs" 0
chk_exit "M5.2 HOLD → exit 1" "README.md" "green" "off" 1
chk_exit "M5.3 REJECT → exit 1" "validate.sh" "green" "generative" 1

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
