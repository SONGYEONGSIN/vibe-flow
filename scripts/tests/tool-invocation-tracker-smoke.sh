#!/bin/bash
# tool-invocation-tracker.sh smoke test (F-D2 fix R1)
# 실행: bash scripts/tests/tool-invocation-tracker-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/core/hooks/tool-invocation-tracker.sh"

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
    echo "  ✗ $name (pattern: '$pattern' not found in: '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

# 격리 임시 git repo로 events.jsonl 별 위치 사용
setup_fixture() {
  TMP=$(mktemp -d)
  PREV_CWD=$(pwd)
  cd "$TMP"
  git init -q
}

teardown_fixture() {
  cd "$PREV_CWD"
  rm -rf "$TMP"
}

echo "Test T1: Skill tool 호출 시 skill_invoked_auto 이벤트 기록"
setup_fixture
echo '{"tool_name":"Skill","tool_input":{"skill":"brainstorm"}}' | bash "$HOOK"
EC=$?
assert_exit "T1.1 exit 0" 0 "$EC"
LINE=$(tail -1 .claude/events.jsonl 2>/dev/null)
assert_contains "T1.2 type=skill_invoked_auto" '"type":"skill_invoked_auto"' "$LINE"
assert_contains "T1.3 skill=brainstorm" '"skill":"brainstorm"' "$LINE"
assert_contains "T1.4 tool_name=Skill" '"tool_name":"Skill"' "$LINE"
assert_contains "T1.5 ts ISO 8601" '"ts":"[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$LINE"
teardown_fixture

echo "Test T2: Agent tool 호출 시 agent_invoked 이벤트 기록"
setup_fixture
echo '{"tool_name":"Agent","tool_input":{"subagent_type":"architecture-reviewer"}}' | bash "$HOOK"
EC=$?
assert_exit "T2.1 exit 0" 0 "$EC"
LINE=$(tail -1 .claude/events.jsonl 2>/dev/null)
assert_contains "T2.2 type=agent_invoked" '"type":"agent_invoked"' "$LINE"
assert_contains "T2.3 agent=architecture-reviewer" '"agent":"architecture-reviewer"' "$LINE"
assert_contains "T2.4 tool_name=Agent" '"tool_name":"Agent"' "$LINE"
teardown_fixture

echo "Test T3: Task tool도 Agent로 처리"
setup_fixture
echo '{"tool_name":"Task","tool_input":{"subagent_type":"general-purpose"}}' | bash "$HOOK"
EC=$?
assert_exit "T3.1 exit 0" 0 "$EC"
LINE=$(tail -1 .claude/events.jsonl 2>/dev/null)
assert_contains "T3.2 type=agent_invoked (Task → agent_invoked)" '"type":"agent_invoked"' "$LINE"
assert_contains "T3.3 agent=general-purpose" '"agent":"general-purpose"' "$LINE"
assert_contains "T3.4 tool_name=Task 보존" '"tool_name":"Task"' "$LINE"
teardown_fixture

echo "Test T4: 다른 tool은 무시 (Bash/Read/Write/Edit)"
setup_fixture
for tool in Bash Read Write Edit Grep Glob; do
  echo "{\"tool_name\":\"$tool\",\"tool_input\":{\"command\":\"ls\"}}" | bash "$HOOK"
done
EC=$?
assert_exit "T4.1 exit 0 (silent skip)" 0 "$EC"
if [ ! -f .claude/events.jsonl ] || [ "$(wc -l < .claude/events.jsonl 2>/dev/null || echo 0)" = "0" ]; then
  echo "  ✓ T4.2 events.jsonl 라인 미생성 (다른 tool 무시)"
  PASS=$((PASS + 1))
else
  echo "  ✗ T4.2 events.jsonl 라인 잘못 기록됨"
  FAIL=$((FAIL + 1))
fi
teardown_fixture

echo "Test T5: target 필드 부재 시 silent skip"
setup_fixture
echo '{"tool_name":"Skill","tool_input":{}}' | bash "$HOOK"
EC=$?
assert_exit "T5.1 skill 필드 부재 exit 0" 0 "$EC"
if [ ! -f .claude/events.jsonl ] || [ "$(wc -l < .claude/events.jsonl 2>/dev/null || echo 0)" = "0" ]; then
  echo "  ✓ T5.2 events.jsonl 라인 미생성 (target empty 무시)"
  PASS=$((PASS + 1))
else
  echo "  ✗ T5.2 라인 잘못 기록됨"
  FAIL=$((FAIL + 1))
fi
teardown_fixture

echo "Test T6: 잘못된 input (tool_name 부재) silent skip"
setup_fixture
echo '{"foo":"bar"}' | bash "$HOOK"
EC=$?
assert_exit "T6.1 invalid input exit 0 (워크플로우 차단 X)" 0 "$EC"
teardown_fixture

echo "Test T7: 누적 append (3 Skill + 2 Agent)"
setup_fixture
for skill in brainstorm plan verify; do
  echo "{\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"$skill\"}}" | bash "$HOOK"
done
for agent in planner security; do
  echo "{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$agent\"}}" | bash "$HOOK"
done
LINES=$(wc -l < .claude/events.jsonl | tr -d ' ')
if [ "$LINES" = "5" ]; then
  echo "  ✓ T7.1 5 라인 누적 ($LINES)"
  PASS=$((PASS + 1))
else
  echo "  ✗ T7.1 expected 5 lines, got $LINES"
  FAIL=$((FAIL + 1))
fi
SKILL_COUNT=$(grep -c '"type":"skill_invoked_auto"' .claude/events.jsonl)
AGENT_COUNT=$(grep -c '"type":"agent_invoked"' .claude/events.jsonl)
if [ "$SKILL_COUNT" = "3" ] && [ "$AGENT_COUNT" = "2" ]; then
  echo "  ✓ T7.2 type별 분류 (skill 3, agent 2)"
  PASS=$((PASS + 1))
else
  echo "  ✗ T7.2 expected skill=3 agent=2, got skill=$SKILL_COUNT agent=$AGENT_COUNT"
  FAIL=$((FAIL + 1))
fi
teardown_fixture

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
