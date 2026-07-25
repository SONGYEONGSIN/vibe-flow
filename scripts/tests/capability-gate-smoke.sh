#!/bin/bash
# capability-gate.sh smoke (T7/PR-6) — 생성 트랙 pre-generation 3중 방어.
# 실행: bash scripts/tests/capability-gate-smoke.sh
#
# 계약: 신규 스킬 생성 후보를 (1)evidence bar(telemetry 반복 ≥N) (2)dedup(기존 스킬 중복)
#       (3)skill-budget(라운드 순증 cap)로 검증. 통과만 skill-creator→eval 진입.
#       speculative/중복/과잉 생성을 pre-gen 에서 차단(anti-sprawl).
# (4번째 eval 방어는 skill-creator 런타임 — 여기선 pre-gen 3중만).

set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$REPO_ROOT/core/skills/audit/scripts/capability-gate.sh"

PASS=0; FAIL=0
dec(){ printf '%s' "$1" | sed -n 's/^DECISION=//p'; }
chk(){ [ "$2" = "$3" ] && { echo "  ✓ $1"; PASS=$((PASS+1)); } || { echo "  ✗ $1 (want $3, got $2)"; FAIL=$((FAIL+1)); }; }

echo "Test C1: 유효 후보(evidence 5, 신규명, budget 여유) → PASS"
out=$(CAP_EVIDENCE_COUNT=5 SKILL_GEN_COUNT=0 SKILL_BUDGET=1 EVIDENCE_MIN=3 bash "$GATE" "zzz-newcap" "brand new distinct capability xyzzy" 2>/dev/null)
chk "C1.1 PASS" "$(dec "$out")" "PASS"

echo "Test C2: evidence 부족(2 < 3) → ABORT_EVIDENCE"
out=$(CAP_EVIDENCE_COUNT=2 SKILL_GEN_COUNT=0 SKILL_BUDGET=1 EVIDENCE_MIN=3 bash "$GATE" "zzz-newcap" "desc" 2>/dev/null)
chk "C2.1 ABORT_EVIDENCE" "$(dec "$out")" "ABORT_EVIDENCE"

echo "Test C3: 기존 스킬명 중복 → ABORT_DEDUP"
out=$(CAP_EVIDENCE_COUNT=5 SKILL_GEN_COUNT=0 SKILL_BUDGET=1 EVIDENCE_MIN=3 bash "$GATE" "commit" "commit related thing" 2>/dev/null)
chk "C3.1 기존 'commit' → ABORT_DEDUP" "$(dec "$out")" "ABORT_DEDUP"

echo "Test C4: budget 초과(gen 1 >= budget 1) → ABORT_BUDGET"
out=$(CAP_EVIDENCE_COUNT=5 SKILL_GEN_COUNT=1 SKILL_BUDGET=1 EVIDENCE_MIN=3 bash "$GATE" "zzz-newcap2" "desc" 2>/dev/null)
chk "C4.1 ABORT_BUDGET" "$(dec "$out")" "ABORT_BUDGET"

echo "Test C5: 게이트 순서 — evidence 가 dedup 보다 먼저(부족 evidence + 기존명 → EVIDENCE)"
out=$(CAP_EVIDENCE_COUNT=1 SKILL_GEN_COUNT=0 SKILL_BUDGET=1 EVIDENCE_MIN=3 bash "$GATE" "commit" "x" 2>/dev/null)
chk "C5.1 evidence 우선 → ABORT_EVIDENCE" "$(dec "$out")" "ABORT_EVIDENCE"

echo "Test C6: exit code (PASS=0, ABORT=1)"
CAP_EVIDENCE_COUNT=5 SKILL_GEN_COUNT=0 SKILL_BUDGET=1 EVIDENCE_MIN=3 bash "$GATE" "zzz-ok" "d" >/dev/null 2>&1
chk "C6.1 PASS exit 0" "$?" "0"
CAP_EVIDENCE_COUNT=1 bash "$GATE" "zzz-x" "d" >/dev/null 2>&1
chk "C6.2 ABORT exit 1" "$?" "1"

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
