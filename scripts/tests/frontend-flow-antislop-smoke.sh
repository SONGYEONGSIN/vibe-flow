#!/bin/bash
# anti-slop-check.js smoke
# 실행: bash scripts/tests/frontend-flow-antislop-smoke.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
JS="$REPO_ROOT/extensions/design-system/skills/frontend-flow/scripts/anti-slop-check.js"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

assert_exit() {
  if [ "$3" = "$2" ]; then echo "  ✓ $1 (exit $2)"; PASS=$((PASS+1));
  else echo "  ✗ $1 (expected $2, got $3)"; FAIL=$((FAIL+1)); fi
}
# jq -e 로 stdout JSON 필드를 검증 (여러 줄 grep 불가 → jq 사용)
assert_jq() {
  if echo "$3" | jq -e "$2" >/dev/null 2>&1; then echo "  ✓ $1"; PASS=$((PASS+1));
  else echo "  ✗ $1"; echo "    filter: '$2'"; echo "    actual:  '$3'"; FAIL=$((FAIL+1)); fi
}
status_of() { echo "$1" | jq -r --arg id "$2" '.checks[] | select(.id==$id) | .status'; }

# clean fixture — 위반 없음
printf 'export const H = () => <h1 className="font-geist text-zinc-900">Hi</h1>\n' > "$TMP/clean.tsx"
# dirty fixture — em-dash, Inter, #000
printf 'export const B = () => <p className="font-inter text-[#000000]">A \xe2\x80\x94 B</p>\n' > "$TMP/dirty.tsx"
# DESIGN.md — Inter/black 브랜드 승인
printf '# DESIGN\n- Body font: Inter\n- Text: #000000 (black)\n' > "$TMP/DESIGN.md"

echo "Test A1: clean → exit 0, failed=0"
OUT=$(node "$JS" "$TMP/clean.tsx" 2>/dev/null); EC=$?
assert_exit "clean-exit" "0" "$EC"
assert_jq "clean-failed0" '.failed == 0' "$OUT"

echo "Test A2: dirty (DESIGN.md 없음) → exit 1, em-dash·font 위반"
OUT=$(node "$JS" "$TMP/dirty.tsx" 2>/dev/null); EC=$?
assert_exit "dirty-exit" "1" "$EC"
[ "$(status_of "$OUT" em-dash-ban)" = "fail" ] && { echo "  ✓ dirty-emdash-fail"; PASS=$((PASS+1)); } || { echo "  ✗ dirty-emdash-fail"; FAIL=$((FAIL+1)); }
[ "$(status_of "$OUT" forbidden-font)" = "fail" ] && { echo "  ✓ dirty-font-fail"; PASS=$((PASS+1)); } || { echo "  ✗ dirty-font-fail"; FAIL=$((FAIL+1)); }

echo "Test A3: dirty + DESIGN.md(Inter/black 승인) → font·black 양보, em-dash만 실패 → exit 1"
OUT=$(node "$JS" "$TMP/dirty.tsx" "$TMP/DESIGN.md" 2>/dev/null); EC=$?
assert_exit "override-exit" "1" "$EC"
[ "$(status_of "$OUT" forbidden-font)" = "pass" ] && { echo "  ✓ override-font-pass"; PASS=$((PASS+1)); } || { echo "  ✗ override-font-pass"; FAIL=$((FAIL+1)); }
[ "$(status_of "$OUT" pure-black-ban)" = "pass" ] && { echo "  ✓ override-black-pass"; PASS=$((PASS+1)); } || { echo "  ✗ override-black-pass"; FAIL=$((FAIL+1)); }
[ "$(status_of "$OUT" em-dash-ban)" = "fail" ] && { echo "  ✓ override-emdash-still-fail"; PASS=$((PASS+1)); } || { echo "  ✗ override-emdash-still-fail"; FAIL=$((FAIL+1)); }

echo "Test A4: 인자 없음 → exit 2"
node "$JS" >/dev/null 2>&1; assert_exit "noarg-exit" "2" "$?"

echo "Test A5: 존재하지 않는 경로 → exit 2 (스택트레이스 아님)"
node "$JS" "$TMP/__nope__" >/dev/null 2>&1; assert_exit "missing-path-exit" "2" "$?"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
