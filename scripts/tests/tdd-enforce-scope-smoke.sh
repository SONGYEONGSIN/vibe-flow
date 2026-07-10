#!/bin/bash
# tdd-enforce.sh 스코프 스모크 (F-K18) — 프로젝트 루트 밖 파일 오차단 방지
# 실행: bash scripts/tests/tdd-enforce-scope-smoke.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/core/hooks/tdd-enforce.sh"
PASS=0; FAIL=0
assert_exit() {
  if [ "$3" = "$2" ]; then echo "  ✓ $1 (exit $2)"; PASS=$((PASS+1));
  else echo "  ✗ $1 (expected $2, got $3)"; FAIL=$((FAIL+1)); fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/proj"; OUT="$TMP/outside"
mkdir -p "$PROJ/src" "$OUT"

run_hook() { # $1=file_path — strict 모드 + CLAUDE_PROJECT_DIR=$PROJ 로 실행
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$1" "$PROJ" \
    | env CLAUDE_TDD_ENFORCE=strict CLAUDE_PROJECT_DIR="$PROJ" bash "$HOOK" >/dev/null 2>&1
  echo $?
}

# 1. 프로젝트 밖 .js 스크래치 — 게이트 대상 아님, 통과해야 함 (F-K18 핵심)
assert_exit "프로젝트 밖 스크래치 .js 통과" 0 "$(run_hook "$OUT/scratch.js")"

# 2. 프로젝트 안 무테스트 .ts — strict 차단 유지 (회귀 방지)
assert_exit "프로젝트 안 무테스트 .ts 차단 유지" 2 "$(run_hook "$PROJ/src/foo.ts")"

# 3. 프로젝트 안 테스트 있는 .ts — 통과 유지
touch "$PROJ/src/bar.test.ts"
assert_exit "프로젝트 안 테스트 있는 .ts 통과 유지" 0 "$(run_hook "$PROJ/src/bar.ts")"

# 4. CLAUDE_PROJECT_DIR 미설정 — payload .cwd 폴백으로 프로젝트 밖 통과
rc=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$OUT/x.js" "$PROJ" \
  | env -u CLAUDE_PROJECT_DIR CLAUDE_TDD_ENFORCE=strict bash "$HOOK" >/dev/null 2>&1; echo $?)
assert_exit "PROJECT_DIR 미설정 시 cwd 폴백으로 프로젝트 밖 통과" 0 "$rc"

# 5. 루트 정보가 전혀 없으면 기존 동작 유지 (보수적 — 무테스트 .ts 차단)
rc=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$PROJ/src/foo.ts" \
  | env -u CLAUDE_PROJECT_DIR CLAUDE_TDD_ENFORCE=strict bash "$HOOK" >/dev/null 2>&1; echo $?)
assert_exit "루트 미확보 시 기존 동작 유지 (차단)" 2 "$rc"

echo ""
echo "tdd-enforce-scope-smoke: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
