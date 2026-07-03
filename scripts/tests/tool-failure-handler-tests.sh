#!/bin/bash
# core/hooks/tool-failure-handler.sh 단위 테스트 — classify_error 회귀 방지
# F-D3 R3-3: 파일 경로/파일명 substring 매칭으로 인한 오분류 회귀 차단
# 실행: bash scripts/tests/tool-failure-handler-tests.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/core/hooks/tool-failure-handler.sh"

PASS=0
FAIL=0

# classify_error 함수만 source 가능하도록 hook을 source할 수는 없으므로 (즉시 stdin read)
# 입력을 흉내내어 hook을 직접 실행하고 events.jsonl 마지막 라인을 검사한다.
# 단위 테스트용 임시 PROJECT_ROOT 셋업.
setup() {
  TMP=$(mktemp -d)
  mkdir -p "$TMP/.claude"
  cd "$TMP"
  git init -q -b main 2>/dev/null
}

teardown() {
  cd /
  rm -rf "$TMP"
}

# 헬퍼: 에러 메시지를 hook에 주입하고 마지막 emit된 error_class를 반환
run_classify() {
  local tool="$1" error="$2"
  jq -n --arg t "$tool" --arg e "$error" '{tool_name: $t, error: $e}' | bash "$HOOK" >/dev/null 2>&1
  jq -r '.error_class' < <(tail -1 .claude/events.jsonl)
}

assert_class() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✓ $name → $actual"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

# ── 테스트 케이스 ──────────────────────────────────────────────

echo "=== F-D3 R3-3 — path/filename substring 오분류 회귀 차단 ==="
setup

# 1. 경로에 "/build/" 포함 + 실제는 not_found (가장 빈번한 오분류)
c=$(run_classify "Bash" "Exit code 1
wc: /Users/yss/개발/build/vibe-flow/.claude/agents/test.md: open: No such file or directory")
assert_class "path containing /build/ → not_found (not build_error)" "not_found" "$c"

# 2. 파일명에 "build" 포함 (예: sleep-build-phase2.md) + 실제는 noise output
c=$(run_classify "Bash" "Exit code 1
=== 20260507-213353-sleep-build-phase2-ralph-vote.md ===
status: done")
assert_class "filename containing 'build' → unknown (not build_error)" "unknown" "$c"

# 3. 진짜 빌드 에러 (경로/파일명 아님) → build_error 유지
c=$(run_classify "Bash" "next build failed: webpack compilation error in src/page.tsx")
assert_class "genuine webpack build error → build_error" "build_error" "$c"

# 3b. F-I06 — 'build' 가 경로 부분문자열로 섞여도(빌드에러 문맥 아님) build_error 아님
c=$(run_classify "Bash" "Exit code 1
git log: commit in build/vibe-flow tree")
assert_class "path substring 'build' (문맥 없음) → NOT build_error (F-I06)" "unknown" "$c"

# 4. ENOENT (path-only) → not_found
c=$(run_classify "Bash" "open /etc/missing: ENOENT: no such file or directory")
assert_class "ENOENT path → not_found" "not_found" "$c"

# 5. 401 인증 에러
c=$(run_classify "Bash" "HTTP 401 Unauthorized: invalid api key")
assert_class "auth (401) → auth" "auth" "$c"

# 6. timeout
c=$(run_classify "Bash" "Error: ETIMEDOUT request timed out after 30000ms")
assert_class "ETIMEDOUT → timeout" "timeout" "$c"

# 7. F-G09 — zsh glob no-match (탐색성 비정상 종료) → diagnostic
c=$(run_classify "Bash" "(eval):1: no matches found: *.xyz")
assert_class "no matches found → diagnostic (F-G09)" "diagnostic" "$c"

# 8. F-G09 — subshell sourcing read-only → diagnostic
c=$(run_classify "Bash" "(eval):2: read-only variable: status")
assert_class "read-only variable → diagnostic (F-G09)" "diagnostic" "$c"

# 9. F-G09 negative — 진짜 not_found 는 diagnostic gate 가 삼키지 않음
c=$(run_classify "Bash" "open /etc/missing: ENOENT: no such file or directory")
assert_class "real not_found stays not_found (gate 오작동 없음)" "not_found" "$c"

teardown

echo
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
