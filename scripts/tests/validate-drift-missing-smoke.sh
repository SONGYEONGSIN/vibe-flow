#!/bin/bash
# validate.sh — drift 검증 missing-dst 비대칭 회귀 방지 smoke test (audit round 7)
#
# F-G01: agents/skills/rules drift 루프가 `[ -f "$dst" ] && ! diff` 구 패턴이라
#        core 에만 있고 .claude 에 없는 신규 파일을 silent-PASS 하던 비대칭 결함.
#        (hooks/scripts/docs 루프는 F-D8(R5)에서 이미 2-branch 로 고쳐짐)
# F-G03: agents.json (message-bus 레지스트리) 이 *.md 루프 밖이라 drift 미탐지.
#
# 실행: bash scripts/tests/validate-drift-missing-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/validate.sh"

PASS=0
FAIL=0

assert_contains() {  # name, needle, haystack
  local name="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q -- "$needle"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    expected needle: $needle"
    FAIL=$((FAIL + 1))
  fi
}

# ── fixture: core/ 에만 존재하는 ghost 파일 + 불일치 agents.json ──
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude"/{agents,hooks,rules,skills,messages,scripts,plans,memory,memory/brainstorms,memory/reviews}
mkdir -p "$TMP/core"/{agents,rules,skills/ghostskill}

# F-G01 — core 에만 있고 .claude 에 없는 신규 파일 3종 (missing-dst)
echo "ghost agent"  > "$TMP/core/agents/ghost-agent.md"
echo "ghost rule"   > "$TMP/core/rules/ghost-rule.md"
echo "ghost skill"  > "$TMP/core/skills/ghostskill/SKILL.md"

# F-G03 — agents.json 내용 불일치 (drift)
printf '{"participants":["a"]}\n' > "$TMP/core/agents.json"
printf '{"participants":["b"]}\n' > "$TMP/.claude/agents.json"

OUT="$(VIBE_FLOW_ROOT="$TMP" bash "$SCRIPT" "$TMP" 2>&1)"

echo "=== validate.sh drift missing-dst 비대칭 검증 ==="
# F-G01: 세 루프 모두 missing-dst 를 warn 으로 잡아야 함
assert_contains "agent missing-dst 탐지 (F-G01)"  "agent missing in .claude/: ghost-agent.md" "$OUT"
assert_contains "rule  missing-dst 탐지 (F-G01)"  "rule missing in .claude/: ghost-rule.md"   "$OUT"
assert_contains "skill missing-dst 탐지 (F-G01)"  "skill missing in .claude/: ghostskill/SKILL.md" "$OUT"

# F-G03: agents.json drift 탐지
assert_contains "agents.json drift 탐지 (F-G03)"  "agents.json drift" "$OUT"

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
