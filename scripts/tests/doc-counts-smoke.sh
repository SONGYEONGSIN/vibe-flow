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
  # F-L04: plugin.json 은 description 문자열 + 로딩 배열(skills/agents) 양쪽을 검증 대상으로 포함
  cat > "$d/.claude-plugin/plugin.json" <<'EOF'
{"description":"kit. 3 skills + 2 agents + 2 hooks.",
 "skills":["./core/skills/a","./core/skills/b","./core/skills/c"],
 "agents":["./core/agents/x.md","./core/agents/y.md"]}
EOF
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

echo "Test D7 (F-L04): plugin.json .agents 배열 stale(문자열 2 정확, 배열 1개) → exit 1"
make_fixture "$TMP/stalearr"
# 설명 문자열은 '2 agents' 그대로, 배열에서만 y.md 제거 — F-H01/F-I02 류 배열 drift 모델
jq -c 'del(.agents[1])' "$TMP/stalearr/.claude-plugin/plugin.json" > "$TMP/stalearr/p.tmp" \
  && mv "$TMP/stalearr/p.tmp" "$TMP/stalearr/.claude-plugin/plugin.json"
bash "$CHK" "$TMP/stalearr" >/dev/null 2>&1; assert_exit "stale-array-exit1" "1" "$?"

echo "Test D8 (F-L04): plugin.json .agents 키 자체 부재 → exit 1 (fail-closed)"
make_fixture "$TMP/noarr"
jq -c 'del(.agents)' "$TMP/noarr/.claude-plugin/plugin.json" > "$TMP/noarr/p.tmp" \
  && mv "$TMP/noarr/p.tmp" "$TMP/noarr/.claude-plugin/plugin.json"
bash "$CHK" "$TMP/noarr" >/dev/null 2>&1; assert_exit "missing-array-exit1" "1" "$?"

echo "Test D9 (F-M04): 배열 원소가 실파일 미지향(카운트 보존형 리네임) → exit 1"
make_fixture "$TMP/ghostelem"
# 길이 3 유지 + 설명 문자열 '3 skills' 그대로 — 원소만 존재하지 않는 경로로 교체
sed -i.bak 's|\./core/skills/c|./core/skills/zz|' "$TMP/ghostelem/.claude-plugin/plugin.json" \
  && rm -f "$TMP/ghostelem/.claude-plugin/plugin.json.bak"
bash "$CHK" "$TMP/ghostelem" >/dev/null 2>&1; assert_exit "ghost-element-exit1" "1" "$?"

# ── F-M02 fixture: ledger 최신 라운드 양끝 ID 가 MEMORY.md 인덱스에 등장해야 통과 ──
add_ledger() { # dir, memo_text
  mkdir -p "$1/.claude/memory"
  printf '%s\n' \
    '{"round":"X","id":"F-X01","status":"open"}' \
    '{"round":"X","id":"F-X02","status":"open"}' > "$1/.claude/memory/audit-ledger.jsonl"
  printf '%s\n' "$2" > "$1/.claude/memory/MEMORY.md"
}

echo "Test D10 (F-M02): ledger 최신 라운드 끝 ID(F-X02) 가 MEMORY.md 미등장 → exit 1"
make_fixture "$TMP/desync"
add_ledger "$TMP/desync" "감사 F-X01 등록"
bash "$CHK" "$TMP/desync" >/dev/null 2>&1; assert_exit "index-desync-exit1" "1" "$?"

echo "Test D11 (F-M02): 양끝 ID 등장(범위 표기) → exit 0"
make_fixture "$TMP/insync"
add_ledger "$TMP/insync" "감사 F-X01~F-X02 등록"
bash "$CHK" "$TMP/insync" >/dev/null 2>&1; assert_exit "index-insync-exit0" "0" "$?"

echo "Test D-U: 미추적 스킬 디렉토리는 카운트에서 제외 (F-AA19)"
# ~/.claude/skills 가 core/skills 의 심볼릭 링크라 전역 설치된 외부 스킬이 작업트리에
# 나타난다. find 기반 카운트는 그걸 세어 로컬(48)과 CI 깨끗한 체크아웃(45)이 갈렸다 —
# 같은 게이트가 환경에 따라 다른 것을 센다. 실측 대상은 **추적되는 것**이어야 한다.
make_fixture "$TMP/untracked"
(cd "$TMP/untracked" && git init -q \
   && git add -A >/dev/null 2>&1 \
   && git -c user.email=t@t -c user.name=t commit -qm init >/dev/null 2>&1)
mkdir -p "$TMP/untracked/core/skills/foreign-global"
echo "---" > "$TMP/untracked/core/skills/foreign-global/SKILL.md"
bash "$CHK" "$TMP/untracked" >/dev/null 2>&1
assert_exit "untracked-skill-무시" "0" "$?"

echo "Test D-U2: 미추적 agent/rule 도 카운트에서 제외 (F-AC03)"
# F-AA19 는 core/skills 만 추적 기준으로 바꿨다. 실측(08-26): `~/.claude/agents`·
# `~/.claude/rules` 도 리포 core/ 의 심볼릭 링크라 **같은 오염 경로가 열려 있다**
# (readlink 확인). 지금은 외부 설치분이 없어 잠복 중일 뿐, 하나라도 깔리면 로컬 게이트가
# CI 와 다른 값을 센다 — F-AA19 와 동일한 결함이 두 디렉토리에 남아 있었다.
make_fixture "$TMP/untracked2"
(cd "$TMP/untracked2" && git init -q \
   && git add -A >/dev/null 2>&1 \
   && git -c user.email=t@t -c user.name=t commit -qm init >/dev/null 2>&1)
printf 'name: foreign\n' > "$TMP/untracked2/core/agents/foreign-global.md"
printf '# foreign rule\n'  > "$TMP/untracked2/core/rules/foreign-global.md"
bash "$CHK" "$TMP/untracked2" >/dev/null 2>&1
assert_exit "untracked-agent-rule-무시" "0" "$?"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
