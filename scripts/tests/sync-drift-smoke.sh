#!/bin/bash
# core/scripts/sync-drift.sh smoke test
# 실행: bash scripts/tests/sync-drift-smoke.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$REPO_ROOT/core/scripts/sync-drift.sh"

PASS=0
FAIL=0

assert_exit() {
  local name="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✓ $name (exit $expected)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
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

setup_fixture() {
  TMP=$(mktemp -d)
  cd "$TMP"
  git init -q -b main 2>/dev/null
  mkdir -p core/agents core/rules core/hooks core/skills/foo .claude/agents .claude/rules .claude/hooks .claude/skills/foo
  # 동일 파일 (drift 없음 baseline)
  cat > core/agents/x.md <<'EOF'
---
name: x
---
EOF
  cp core/agents/x.md .claude/agents/x.md
  cat > core/skills/foo/SKILL.md <<'EOF'
---
name: foo
---
EOF
  cp core/skills/foo/SKILL.md .claude/skills/foo/SKILL.md
}

teardown() { cd /; rm -rf "$TMP"; }

# ── T1: clean state → --check exit 0 ─────────────────────
echo "Test T1: clean state — --check exit 0"
setup_fixture
OUT=$(bash "$SCRIPT" --check 2>&1)
EC=$?
assert_exit "T1.1 --check exit 0 on clean" 0 "$EC"
assert_contains "T1.2 stderr 'no drift'" "no drift detected" "$OUT"
teardown

# ── T2: drift introduced → --check exit 1 + 카운트 ───────
echo "Test T2: drift detected — --check exit 1"
setup_fixture
echo "modified" >> core/agents/x.md  # introduce drift
OUT=$(bash "$SCRIPT" --check 2>&1)
EC=$?
assert_exit "T2.1 --check exit 1 on drift" 1 "$EC"
assert_contains "T2.2 stderr 'drift entries detected'" "drift entries detected" "$OUT"
teardown

# ── T3: apply mode — drift sync'd ────────────────────────
echo "Test T3: apply mode syncs drift"
setup_fixture
echo "new line in core" >> core/agents/x.md
OUT=$(bash "$SCRIPT" 2>&1)
EC=$?
assert_exit "T3.1 apply exit 0" 0 "$EC"
assert_contains "T3.2 stderr 'files synced'" "files synced" "$OUT"
# verify destination matches source after sync
if diff -q core/agents/x.md .claude/agents/x.md >/dev/null; then
  echo "  ✓ T3.3 dest matches source after sync"
  PASS=$((PASS + 1))
else
  echo "  ✗ T3.3 dest still differs after sync"
  FAIL=$((FAIL + 1))
fi
teardown

# ── T4: --verbose lists synced files ─────────────────────
echo "Test T4: --verbose lists files"
setup_fixture
echo "v" >> core/skills/foo/SKILL.md
OUT=$(bash "$SCRIPT" --verbose 2>&1)
EC=$?
assert_exit "T4.1 verbose exit 0" 0 "$EC"
assert_contains "T4.2 stderr lists 'synced: skills/foo/SKILL.md'" "synced: skills/foo/SKILL.md" "$OUT"
teardown

# ── T5: missing dest file → sync creates it ──────────────
echo "Test T5: missing dest file — sync creates"
setup_fixture
cat > core/skills/foo/orchestrator.md <<'EOF'
hand-off
EOF
# .claude/skills/foo/orchestrator.md is missing
OUT=$(bash "$SCRIPT" --verbose 2>&1)
EC=$?
assert_exit "T5.1 missing-file sync exit 0" 0 "$EC"
if [ -f .claude/skills/foo/orchestrator.md ]; then
  echo "  ✓ T5.2 missing dest now exists"
  PASS=$((PASS + 1))
else
  echo "  ✗ T5.2 missing dest still absent"
  FAIL=$((FAIL + 1))
fi
teardown

# ── T6: hooks skip list — git-post-commit.sh 미설치도 정상 ──
echo "Test T6: hooks skip — git-post-commit.sh"
setup_fixture
cat > core/hooks/git-post-commit.sh <<'EOF'
#!/bin/bash
echo "post-commit"
EOF
chmod +x core/hooks/git-post-commit.sh
# .claude/hooks/git-post-commit.sh 일부러 생성 X (실 환경 시뮬레이션)
OUT=$(bash "$SCRIPT" --check 2>&1)
EC=$?
# 다른 drift 도 없으므로 0
assert_exit "T6.1 --check exit 0 (git-post-commit skip)" 0 "$EC"
if [ ! -f .claude/hooks/git-post-commit.sh ]; then
  echo "  ✓ T6.2 git-post-commit.sh 정상 skip (.claude/hooks 미배포)"
  PASS=$((PASS + 1))
else
  echo "  ✗ T6.2 git-post-commit.sh 가 잘못 배포됨"
  FAIL=$((FAIL + 1))
fi
teardown

# ── T7: agents.json drift (F-G03 audit R7) — sync_dir_flat 글롭(core/agents/*) 밖 파일 ──
echo "Test T7: agents.json drift detected (F-G03)"
setup_fixture
printf '{"participants":["a"]}\n' > core/agents.json
printf '{"participants":["b"]}\n' > .claude/agents.json
OUT=$(bash "$SCRIPT" --check 2>&1)
EC=$?
assert_exit "T7.1 --check exit 1 on agents.json drift" 1 "$EC"
bash "$SCRIPT" >/dev/null 2>&1  # apply
if diff -q core/agents.json .claude/agents.json >/dev/null; then
  echo "  ✓ T7.2 agents.json synced (dest matches source)"
  PASS=$((PASS + 1))
else
  echo "  ✗ T7.2 agents.json still differs after sync"
  FAIL=$((FAIL + 1))
fi
teardown

echo
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
