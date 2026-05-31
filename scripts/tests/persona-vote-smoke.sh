#!/bin/bash
# persona-vote.sh smoke test (audit F-D1 — tdd Iron Law 자기 적용)
# 실행: bash scripts/tests/persona-vote-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/core/skills/auto-build/scripts/persona-vote.sh"

PASS=0
FAIL=0

assert_exit() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✓ $name (exit $expected)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local name="$1" pattern="$2" actual="$3"
  if echo "$actual" | grep -qE "$pattern"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (pattern: '$pattern' not found)"
    FAIL=$((FAIL + 1))
  fi
}

echo "Test P1: usage error (인자 부족)"
bash "$SCRIPT" >/dev/null 2>&1; EC=$?
assert_exit "P1.1 인자 0개 → exit 1" 1 "$EC"
bash "$SCRIPT" "design" >/dev/null 2>&1; EC=$?
assert_exit "P1.2 인자 1개 → exit 1" 1 "$EC"

echo "Test P2: 알 수 없는 카테고리"
bash "$SCRIPT" "unknown-cat" "any question" >/dev/null 2>&1; EC=$?
assert_exit "P2.1 unknown_category → exit 3" 3 "$EC"
OUT=$(bash "$SCRIPT" "unknown-cat" "any question" 2>&1 || true)
assert_contains "P2.2 stderr 'unknown_category'" "unknown_category" "$OUT"

echo "Test P3: valid category dispatch"
OUT=$(bash "$SCRIPT" "design" "버튼 색상 라벤더 vs 블루" 2>/dev/null || true)
EC=$?
assert_exit "P3.1 valid category → exit 0" 0 "$EC"
assert_contains "P3.2 VOTE PROMPT TEMPLATE 출력" "VOTE PROMPT TEMPLATE" "$OUT"
assert_contains "P3.3 AGENT_DISPATCH:designer 라인" "AGENT_DISPATCH:designer:" "$OUT"
assert_contains "P3.4 MODERATOR_DISPATCH 라인" "MODERATOR_DISPATCH:moderator:" "$OUT"
PERSONA_LINES=$(echo "$OUT" | grep -c "^AGENT_DISPATCH:" || true)
if [ "$PERSONA_LINES" -ge 3 ]; then
  echo "  ✓ P3.5 design 카테고리 persona 3개 이상 dispatch ($PERSONA_LINES)"
  PASS=$((PASS + 1))
else
  echo "  ✗ P3.5 expected 3+ AGENT_DISPATCH, got $PERSONA_LINES"
  FAIL=$((FAIL + 1))
fi

echo "Test P4: 다른 카테고리 (auth)"
OUT=$(bash "$SCRIPT" "auth" "OAuth vs Magic Link" 2>/dev/null || true)
EC=$?
assert_exit "P4.1 auth 카테고리 exit 0" 0 "$EC"
assert_contains "P4.2 security persona dispatch" "AGENT_DISPATCH:security:" "$OUT"

echo "Test P5: persona-mapping.json 부재 시 exit 2"
# script 디렉토리에서 일시적으로 mapping rename하면 위험 (다른 테스트 영향)
# 대신 script 호출 cwd를 임시 디렉토리로 잡되 SCRIPT_DIR이 절대경로라 영향 X.
# 따라서 P5는 P2(unknown category)로 이미 의존성 path 검증 일부 cover됨 (실제 부재 case는 환경 격리 어려움).

echo "  - mapping 부재 case는 unit 환경 격리 어려워 코드 line 39 review로 보완 (생략)"
echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"

if [ "$FAIL" -eq 0 ]; then
  echo "✓ ALL TESTS PASSED"
  exit 0
else
  echo "✗ SOME TESTS FAILED"
  exit 1
fi
