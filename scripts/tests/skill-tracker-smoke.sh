#!/bin/bash
# .claude/hooks/skill-tracker.sh smoke test
# F-F2 (audit round 6): telemetry poisoning 회귀 방지.
# 멀티라인/경로형 /-prefix prompt 가 garbage skill name 으로 events.jsonl 에
# 기록되던 버그 (예: "skill":"goal\n\n1.\n2...") 를 차단하는지 검증.
# 실행: bash scripts/tests/skill-tracker-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# F-G02 (audit R7): core/ 소스를 직접 검증 — .claude/ 런타임 미러는 gitignored 라
# CI fresh clone 에 부재(빈 skill 로 오탐). 로직은 sync 로 동일.
SCRIPT="$REPO_ROOT/core/hooks/skill-tracker.sh"

PASS=0
FAIL=0

setup() {
  TMP=$(mktemp -d)
  cd "$TMP"
  git init -q -b main 2>/dev/null
  # F-H10 (audit R8): 실재 skill 만 기록되므로 fixture 에 검증 대상 skill 디렉토리 생성
  mkdir -p "$TMP/.claude/skills/commit" "$TMP/.claude/skills/brainstorm"
  EVENTS="$TMP/.claude/events.jsonl"
}

teardown() { cd /; rm -rf "$TMP"; }

# prompt(raw) 를 JSON 으로 안전하게 감싸 hook stdin 으로 전달
run_hook() { printf '%s' "$1" | jq -Rs '{prompt: .}' | bash "$SCRIPT"; }

assert_skill() {  # name, expected_skill
  local name="$1" expected="$2"
  if [ -f "$EVENTS" ] && tail -1 "$EVENTS" | jq -e --arg s "$expected" '.skill == $s' >/dev/null 2>&1; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected skill=$expected, got: $(tail -1 "$EVENTS" 2>/dev/null))"
    FAIL=$((FAIL + 1))
  fi
}

assert_no_event() {  # name
  local name="$1"
  if [ ! -s "$EVENTS" ]; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (unexpected event: $(tail -1 "$EVENTS"))"
    FAIL=$((FAIL + 1))
  fi
}

assert_clean_skill_name() {  # name — logged skill must be a single clean token (no newline/garbage)
  local name="$1"
  local skill
  skill=$(tail -1 "$EVENTS" 2>/dev/null | jq -r '.skill // empty' 2>/dev/null)
  # newline/특수문자 포함(멀티라인 garbage)이면 reject — case glob 으로 줄단위 우회 차단
  case "$skill" in
    ''|*[!a-zA-Z0-9_-]*)
      echo "  ✗ $name (garbage skill name: $(printf '%q' "$skill"))"
      FAIL=$((FAIL + 1)) ;;
    *)
      echo "  ✓ $name (clean: $skill)"
      PASS=$((PASS + 1)) ;;
  esac
}

# Case 1: valid /commit
echo "=== Case 1: /commit → skill=commit ==="
setup
run_hook "/commit"
assert_skill "valid slash skill logged" "commit"
teardown

# Case 2: plugin-prefixed /vibe-flow:brainstorm
echo "=== Case 2: /vibe-flow:brainstorm foo → skill=brainstorm ==="
setup
run_hook "/vibe-flow:brainstorm foo"
assert_skill "plugin prefix stripped" "brainstorm"
teardown

# Case 3: multiline paste on a REAL skill /brainstorm — head-n1 로 멀티라인 제거, clean 기록 (F-F2)
echo "=== Case 3: multiline /brainstorm paste → clean token only ==="
setup
run_hook "$(printf '/brainstorm\n\n1.\n2.\n3.\n4.\n5.\n6.')"
assert_clean_skill_name "multiline paste yields clean token only (no newline garbage)"
teardown

# Case 4: path-like /Users/... — MUST be rejected (contains '/')
echo "=== Case 4: /Users/yss/foo path → no event ==="
setup
run_hook "/Users/yss/foo/bar.md"
assert_no_event "path-like token rejected"
teardown

# Case 5: ordinary non-slash prompt → skip
echo "=== Case 5: 'hello world' → no event ==="
setup
run_hook "hello world"
assert_no_event "non-slash prompt skipped"
teardown

# Case 6: F-H10 — 형식은 valid 하나 존재하지 않는 슬래시명(/goal 빌트인) → phantom, 기록 X
echo "=== Case 6: /goal (실재 안 하는 skill) → no event (F-H10) ==="
setup
run_hook "/goal 어떤 목표"
assert_no_event "phantom skill (/goal) 미기록"
teardown

# Case 7: F-H10 회귀가드 — 실재 skill 은 정상 기록됨
echo "=== Case 7: /brainstorm (실재) → 정상 기록 (F-H10 오차단 없음) ==="
setup
run_hook "/brainstorm 주제"
assert_skill "실재 skill 정상 기록" "brainstorm"
teardown

# Case 8: F-K20 — 비 git cwd 에서도 stdin 을 drain 해야 함.
# stdin 미소비 조기 종료 시 writer(Claude Code)가 EPIPE
# ("UserPromptSubmit hook error: Failed to write to socket") —
# pipe buffer(64KB) 초과 payload 로 결정적으로 재현.
echo "=== Case 8: 비 git cwd + 대형 stdin → writer SIGPIPE 없음 (F-K20) ==="
NOGIT=$(mktemp -d)
cd "$NOGIT"
printf 'x%.0s' $(seq 1 120000) | jq -Rs '{prompt: .}' | bash "$SCRIPT" >/dev/null 2>&1
rc=("${PIPESTATUS[@]}")
if [ "${rc[1]}" = "141" ]; then
  echo "  ✗ writer SIGPIPE(141) — stdin 미소비 조기 종료 (EPIPE 재현)"
  FAIL=$((FAIL + 1))
else
  echo "  ✓ writer 정상 종료 (jq exit ${rc[1]}) — stdin drain 확인"
  PASS=$((PASS + 1))
fi
cd /; rm -rf "$NOGIT"

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
