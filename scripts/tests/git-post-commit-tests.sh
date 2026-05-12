#!/bin/bash
# core/hooks/git-post-commit.sh 단위 테스트
# 실행: bash scripts/tests/git-post-commit-tests.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/core/hooks/git-post-commit.sh"

PASS=0
FAIL=0

assert_contains() {
  local name="$1" pattern="$2" actual="$3"
  if echo "$actual" | grep -q "$pattern"; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    echo "    pattern:  '$pattern'"
    echo "    actual:   '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_jq_valid() {
  local name="$1" line="$2"
  if echo "$line" | jq empty 2>/dev/null; then
    echo "  ✓ $name (jq empty)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (jq empty)"
    echo "    line: '$line'"
    FAIL=$((FAIL + 1))
  fi
}

setup_fixture() {
  TMP=$(mktemp -d)
  cd "$TMP"
  git init -q -b main
  git config user.email "test@test.test"
  git config user.name "test"
  mkdir -p .claude
}

teardown() {
  cd /
  rm -rf "$TMP"
}

# ── Test 1: 기본 emit ─────────────────────────────────────
echo "Test 1: 기본 emit (ASCII subject)"
setup_fixture
echo "x" > a.txt
git add a.txt
git commit -qm "test commit"
bash "$HOOK"
LINE=$(head -1 .claude/events.jsonl 2>/dev/null || echo "")
assert_jq_valid "1.1 jq empty" "$LINE"
assert_contains "1.2 type=commit_pushed" '"type":"commit_pushed"' "$LINE"
assert_contains "1.3 subject 포함" '"subject":"test commit"' "$LINE"
assert_contains "1.4 branch 포함" '"branch":"main"' "$LINE"
assert_contains "1.5 ts ISO 8601" '"ts":"[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T' "$LINE"
teardown

# ── Test 2: 한글 subject (NFC 정규화) ─────────────────────
echo "Test 2: 한글 subject NFC"
setup_fixture
echo "x" > a.txt
git add a.txt
git commit -qm "한글 커밋"
bash "$HOOK"
LINE=$(head -1 .claude/events.jsonl)
assert_jq_valid "2.1 jq empty" "$LINE"
assert_contains "2.2 한글 subject" '한글 커밋' "$LINE"
# NFC: 한국어 자모 분리 X — composed form
# NFD form은 ㅎ + ㅏ + ㄴ 분리. NFC는 합쳐진 single char
# byte 수로 간접 검증 — NFC '한' = 3 bytes (UTF-8), NFD '한' = 6 bytes
SUBJ=$(echo "$LINE" | jq -r '.subject')
SUBJ_BYTES=$(echo -n "$SUBJ" | wc -c | tr -d ' ')
# "한글 커밋" NFC = 한(3) 글(3) ' '(1) 커(3) 밋(3) = 13 bytes
if [ "$SUBJ_BYTES" -le 15 ]; then
  echo "  ✓ 2.3 NFC byte length (${SUBJ_BYTES} bytes ≤ 15)"
  PASS=$((PASS + 1))
else
  echo "  ✗ 2.3 NFC byte length (${SUBJ_BYTES} bytes — likely NFD)"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test 3: 80자 truncate ────────────────────────────────
echo "Test 3: 긴 subject 80자 truncate"
setup_fixture
echo "x" > a.txt
git add a.txt
LONG=$(printf 'x%.0s' {1..120})  # 120-char subject
git commit -qm "$LONG"
bash "$HOOK"
LINE=$(head -1 .claude/events.jsonl)
SUBJ=$(echo "$LINE" | jq -r '.subject')
SUBJ_LEN=$(echo -n "$SUBJ" | wc -c | tr -d ' ')
if [ "$SUBJ_LEN" -le 80 ]; then
  echo "  ✓ 3.1 truncate ≤ 80 (${SUBJ_LEN} bytes)"
  PASS=$((PASS + 1))
else
  echo "  ✗ 3.1 truncate ≤ 80 (${SUBJ_LEN} bytes)"
  FAIL=$((FAIL + 1))
fi
teardown

# ── Test 4: events.jsonl 부재 시 touch + append ──────────
echo "Test 4: events.jsonl 부재 시 자동 생성"
setup_fixture
# .claude/events.jsonl 미생성 상태로 commit
echo "x" > a.txt
git add a.txt
git commit -qm "first commit"
[ -f .claude/events.jsonl ] && rm .claude/events.jsonl
bash "$HOOK"
if [ -f .claude/events.jsonl ]; then
  echo "  ✓ 4.1 events.jsonl 자동 생성"
  PASS=$((PASS + 1))
else
  echo "  ✗ 4.1 events.jsonl 미생성"
  FAIL=$((FAIL + 1))
fi
teardown

echo ""
echo "═══════════════════════════════════════"
echo "  PASS: $PASS  FAIL: $FAIL"
echo "═══════════════════════════════════════"
[ "$FAIL" -eq 0 ]
