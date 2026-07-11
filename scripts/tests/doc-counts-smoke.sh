#!/bin/bash
# check-doc-counts.sh 스모크 — fixture 기반 RED/GREEN
# 실행: bash scripts/tests/doc-counts-smoke.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK="$REPO_ROOT/scripts/check-doc-counts.sh"
PASS=0; FAIL=0
assert_exit() {
  if [ "$3" = "$2" ]; then echo "  ✓ $1 (exit $2)"; PASS=$((PASS+1));
  else echo "  ✗ $1 (expected $2, got $3)"; FAIL=$((FAIL+1)); fi
}

# F-K19: sed -i 는 BSD sed(macOS)에서 백업 suffix 필수 — -i.bak + rm 으로 GNU/BSD 겸용
# ── fixture 빌더: 실측 skills=3 agents=2 hooks=2 rules=1 ──
make_fixture() {
  local d="$1"
  mkdir -p "$d/core/skills/a" "$d/core/skills/b" "$d/core/skills/c"
  mkdir -p "$d/core/agents" "$d/core/hooks" "$d/core/rules" "$d/.claude-plugin"
  for s in a b c; do echo "---" > "$d/core/skills/$s/SKILL.md"; done
  printf 'name: x\n' > "$d/core/agents/x.md"
  printf 'name: y\n' > "$d/core/agents/y.md"
  printf '# readme\n' > "$d/core/agents/README.md"        # 제외 대상
  printf 'echo h1\n' > "$d/core/hooks/h1.sh"
  printf 'echo h2\n' > "$d/core/hooks/h2.sh"
  printf 'echo common\n' > "$d/core/hooks/_common.sh"      # 제외 대상
  printf '# rule\n' > "$d/core/rules/r1.md"
  # 문서: 실측과 일치 (skills3 agents2 hooks2 rules1)
  cat > "$d/README.md" <<'EOF'
[![Skills](https://img.shields.io/badge/Skills-3-blue)](x)
[![Agents](https://img.shields.io/badge/Agents-2-green)](x)
[![Hooks](https://img.shields.io/badge/Hooks-2-orange)](x)

→ 3 skills + 2 agents + 2 hooks + 1 rules are activated.
## enforcement (2 hooks)
EOF
  printf '{"description":"kit. 3 skills + 2 agents + 2 hooks."}\n' > "$d/.claude-plugin/plugin.json"
  printf '{"description":"kit — 3 skills, 2 agents, 2 hooks."}\n' > "$d/.claude-plugin/marketplace.json"
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "Test D1: 문서=실측 일치 → exit 0"
make_fixture "$TMP/ok"
bash "$CHK" "$TMP/ok" >/dev/null 2>&1; assert_exit "match-exit0" "0" "$?"

echo "Test D2: README 배지 hooks 불일치(2→9) → exit 1"
make_fixture "$TMP/badbadge"
sed -i.bak 's/Hooks-2-orange/Hooks-9-orange/' "$TMP/badbadge/README.md" && rm -f "$TMP/badbadge/README.md.bak"
bash "$CHK" "$TMP/badbadge" >/dev/null 2>&1; assert_exit "bad-badge-exit1" "1" "$?"

echo "Test D3: README 본문 skills 불일치(3→7) → exit 1 (본문·배지 divergence 포착)"
make_fixture "$TMP/badbody"
sed -i.bak 's/3 skills/7 skills/' "$TMP/badbody/README.md" && rm -f "$TMP/badbody/README.md.bak"
bash "$CHK" "$TMP/badbody" >/dev/null 2>&1; assert_exit "bad-body-exit1" "1" "$?"

echo "Test D4: plugin.json hooks 불일치(2→5) → exit 1"
make_fixture "$TMP/badplugin"
sed -i.bak 's/2 hooks/5 hooks/' "$TMP/badplugin/.claude-plugin/plugin.json" && rm -f "$TMP/badplugin/.claude-plugin/plugin.json.bak"
bash "$CHK" "$TMP/badplugin" >/dev/null 2>&1; assert_exit "bad-plugin-exit1" "1" "$?"

echo "Test D5: 실제 core/hooks에 훅 추가로 실측 변동 → 문서 미갱신이면 exit 1"
make_fixture "$TMP/newhook"
printf 'echo h3\n' > "$TMP/newhook/core/hooks/h3.sh"   # 실측 hooks 2→3, 문서는 2
bash "$CHK" "$TMP/newhook" >/dev/null 2>&1; assert_exit "inventory-change-exit1" "1" "$?"

echo "Test D6: 필수 문서 파일 없음 → exit 2"
mkdir -p "$TMP/nofile/core/skills/a"
bash "$CHK" "$TMP/nofile" >/dev/null 2>&1; assert_exit "missing-file-exit2" "2" "$?"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
