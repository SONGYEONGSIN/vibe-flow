#!/bin/bash
# .claude/validate.sh — F-C1 sync drift 블록(4.5/10) 실행 보장 smoke test
# F-F1 (audit round 6): 문서화된 `bash .claude/validate.sh` 실행 시
# VIBE_FLOW_ROOT 가 dirname "$0"(=.claude) 로 잘못 잡혀 drift 블록이
# 조용히 skip 되던 버그(R3~R5 sync 검증 무력화) 회귀 방지.
# 실행: bash scripts/tests/validate-drift-smoke.sh
#
# CI-SKIP: .claude/validate.sh(gitignored 런타임 미러)를 직접 실행하므로 CI fresh clone 에
# 부재. root validate.sh 대상 동형 검증은 validate-drift-missing-smoke.sh 가 CI-safe 로 커버.
# (F-H05, audit R8)

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/.claude/validate.sh"

PASS=0
FAIL=0

assert_contains() {  # name, needle, haystack
  local name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q -- "$needle"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    needle: $needle"
    FAIL=$((FAIL + 1))
  fi
}

# 문서화된 호출 방식 그대로: repo root 에서 `bash .claude/validate.sh` (인자 없음)
echo "=== documented invocation: cd <repo>; bash .claude/validate.sh ==="
cd "$REPO_ROOT"
OUT=$(bash .claude/validate.sh 2>&1)

# 1. drift 섹션 헤더는 항상 출력됨 (sanity)
assert_contains "drift section header present" "core/ ↔ .claude/ sync drift" "$OUT"

# 2. 핵심: drift 블록이 실제로 '실행'됐다는 증거 — agent 동기화 확인 라인.
#    버그 상태에서는 헤더만 찍히고 if [ -d "$VIBE_FLOW_ROOT/core/agents" ] 가
#    false 라 내부 검증(동기화 ok 라인)이 전혀 출력되지 않음.
assert_contains "drift block actually ran (agents 동기화 line)" "core/agents ↔ .claude/agents 동기화" "$OUT"

# 3. rules drift 검증도 실행됨 (VIBE_FLOW_ROOT 가 repo root 로 정확히 해석된 증거)
assert_contains "rules drift block ran" "core/rules ↔ .claude/rules 동기화" "$OUT"

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
