#!/bin/bash
# plan-event-smoke.sh — plan_completed 이벤트에 producer 구분 필드(source) 계약 (audit F-Q18)
# 실행: bash scripts/tests/plan-event-smoke.sh
#
# 배경: plan_completed 이벤트를 사람의 `/plan complete`와 auto-build orchestrator의
# ad-hoc 단계 완료 마킹이 공유하는데, 어느 쪽이 emit했는지 구분할 필드가 없어
# telemetry plan_created/plan_completed 조인 시 producer 를 추적할 수 없었다.
# 계약: plan/SKILL.md 의 plan_completed emit 라인이 source 필드를 포함하고,
# auto-build/orchestrator.md 가 그 값을 "auto-build" 로 명시 설정하도록 지시한다.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLAN_SKILL="$REPO_ROOT/core/skills/plan/SKILL.md"
ORCHESTRATOR="$REPO_ROOT/core/skills/auto-build/orchestrator.md"

PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

echo "Test PE1: plan_completed emit 라인에 source 필드 존재"
line=$(grep -n '"type\\":\\"plan_completed\\"' "$PLAN_SKILL" | head -1)
if [ -z "$line" ]; then
  ng "PE1.1 plan_completed emit 라인을 찾지 못함"
else
  if echo "$line" | grep -q '\\"source\\"'; then
    ok "PE1.1 plan_completed emit 라인에 source 필드 존재"
  else
    ng "PE1.1 plan_completed emit 라인에 source 필드 부재"
  fi
fi

echo "Test PE2: source 기본값이 manual(사람 /plan complete)"
if grep -q 'EVENT_SOURCE:-manual' "$PLAN_SKILL"; then
  ok "PE2.1 기본값 manual 명시"
else
  ng "PE2.1 기본값 manual 명시 없음"
fi

echo "Test PE3: auto-build orchestrator 가 완료 마킹 시 source=auto-build 를 명시 설정"
if grep -q 'EVENT_SOURCE=auto-build' "$ORCHESTRATOR"; then
  ok "PE3.1 orchestrator.md 에 EVENT_SOURCE=auto-build 지시 존재"
else
  ng "PE3.1 orchestrator.md 에 EVENT_SOURCE=auto-build 지시 없음"
fi

echo
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "✓ ALL TESTS PASSED"
  exit 0
else
  echo "✗ TESTS FAILED"
  exit 1
fi
