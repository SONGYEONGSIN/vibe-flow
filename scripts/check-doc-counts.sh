#!/bin/bash
# check-doc-counts.sh [BASE_DIR]
# 실측 컴포넌트 카운트 ↔ 문서(README 배지+본문, plugin.json, marketplace.json) 일치 게이트.
# 문서 fix가 CI 밖이라 반복 재발하던 stale drift(F-G05/06/07, F-H01, F-I02, 감사 재지적)를 차단.
# ARCHITECTURE.md는 총계(core+ext) 표기 + legacy라 제외.
#
# Exit: 0 일치 / 1 drift / 2 필수 파일 없음
set -u
BASE="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$BASE" || exit 2

FAIL=0
err() { echo "✗ $1"; FAIL=$((FAIL+1)); }

# 필수 문서 존재
for f in README.md .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  [ -f "$f" ] || { echo "✗ 필수 문서 없음: $f"; exit 2; }
done

# 실측 카운트 (core/hooks의 _common.sh 헬퍼, core/agents의 README.md 제외)
ACT_SKILLS=$(find core/skills -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
ACT_AGENTS=$(find core/agents -maxdepth 1 -name '*.md' ! -name 'README.md' 2>/dev/null | wc -l | tr -d ' ')
# F-L05 (audit R12): validate.sh taxonomy(REQUIRED_HOOKS 26 + REQUIRED_UTILITIES)와 통일 —
# message-bus.sh 는 CLI 유틸(F-I03), git-post-commit.sh 는 git 훅이라 Claude hook 카운트에서 제외.
ACT_HOOKS=$(find core/hooks -maxdepth 1 -name '*.sh' ! -name '_common.sh' ! -name 'message-bus.sh' ! -name 'git-post-commit.sh' 2>/dev/null | wc -l | tr -d ' ')
ACT_RULES=$(find core/rules -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')

# 파일에서 regex 매치들의 숫자가 전부 expect와 같은지 (배지 ↔ 본문 divergence까지 포착)
assert_all() {
  local label="$1" file="$2" regex="$3" expect="$4"
  local found=0 n
  while IFS= read -r n; do
    [ -z "$n" ] && continue
    found=1
    [ "$n" != "$expect" ] && err "$label — '$file'에 $n (실측 $expect)"
  done < <(grep -oiE "$regex" "$file" | grep -oE '[0-9]+')
  [ "$found" = 0 ] && err "$label — '$file'에 카운트 패턴 없음"
}

# README: 배지(Skills-N) + 본문(N skills) 양쪽
assert_all "README skills" README.md 'Skills-[0-9]+|[0-9]+ skills' "$ACT_SKILLS"
assert_all "README agents" README.md 'Agents-[0-9]+|[0-9]+ agents' "$ACT_AGENTS"
assert_all "README hooks"  README.md 'Hooks-[0-9]+|[0-9]+ hooks'   "$ACT_HOOKS"
assert_all "README rules"  README.md '[0-9]+ rules'                "$ACT_RULES"

# plugin.json / marketplace.json description (marketplace는 2개 description 모두 스캔됨)
for mf in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  assert_all "$mf skills" "$mf" '[0-9]+ skills' "$ACT_SKILLS"
  assert_all "$mf agents" "$mf" '[0-9]+ agents' "$ACT_AGENTS"
  assert_all "$mf hooks"  "$mf" '[0-9]+ hooks'  "$ACT_HOOKS"
done

# F-L04 (audit R12): 위 assert 는 설명 *문자열*만 대조해, plugin.json 로딩 배열이
# stale(문자열 '23 agents' 정확 / .agents 배열 22)이어도 통과하는 맹점이 있었다.
# 비표준 경로(core/)는 배열 명시 등재가 유일 로딩 경로 — 배열 길이 자체를 실측과 대조.
# jq 실패·키 부재는 null|length=0 으로 mismatch → fail-closed. tr -d '\r': Windows jq CRLF.
PLUGIN_SKILLS_LEN=$(jq '.skills | length' .claude-plugin/plugin.json 2>/dev/null | tr -d '\r')
PLUGIN_AGENTS_LEN=$(jq '.agents | length' .claude-plugin/plugin.json 2>/dev/null | tr -d '\r')
[ "$PLUGIN_SKILLS_LEN" = "$ACT_SKILLS" ] || err "plugin.json .skills 배열 ${PLUGIN_SKILLS_LEN:-?}개 (실측 $ACT_SKILLS)"
[ "$PLUGIN_AGENTS_LEN" = "$ACT_AGENTS" ] || err "plugin.json .agents 배열 ${PLUGIN_AGENTS_LEN:-?}개 (실측 $ACT_AGENTS)"

# F-M04 (audit R13): F-L04 는 배열 *길이*만 대조 — 카운트 보존형 오타/리네임(원소가 실파일
# 미지향)은 length 유지로 통과하나 런타임엔 해당 항목 silent 미로딩. 원소 각각의 실존 대조.
while IFS= read -r p; do
  p="${p%$'\r'}"
  [ -z "$p" ] && continue
  [ -e "${p#./}" ] || err "plugin.json 배열 원소 실파일 없음: $p"
done < <(jq -r '(.skills // [])[], (.agents // [])[]' .claude-plugin/plugin.json 2>/dev/null)

# F-M02 (audit R13): ledger 는 갱신되나 MEMORY.md 인덱스 산문이 뒤처지는 desync 가 라운드마다
# 재발 (R12 F-L01 은 point-fix — 클래스 미일반화). 최신 라운드의 양끝 finding ID 가 인덱스에
# 등장해야 통과 — 전수 나열 강제는 200줄 cap 인덱스 철학과 충돌해 범위 표기('F-X01~F-Xnn')의
# 양끝만 검사, F-L12 류 '라운드 연장 미반영'을 포착. downstream(ledger 부재)은 skip.
LEDGER=".claude/memory/audit-ledger.jsonl"
MEMO=".claude/memory/MEMORY.md"
if [ -f "$LEDGER" ] && [ -f "$MEMO" ]; then
  LATEST_ROUND=$(jq -r 'select(type=="object" and .round != null) | .round' "$LEDGER" 2>/dev/null | tr -d '\r' | tail -1)
  if [ -n "$LATEST_ROUND" ]; then
    ROUND_IDS=$(jq -r --arg r "$LATEST_ROUND" 'select(type=="object" and .round == $r) | .id // empty' "$LEDGER" 2>/dev/null | tr -d '\r' | LC_ALL=C sort)
    for fid in $(echo "$ROUND_IDS" | head -1) $(echo "$ROUND_IDS" | tail -1); do
      [ -z "$fid" ] && continue
      grep -q "$fid" "$MEMO" || err "MEMORY.md 인덱스에 최신 라운드($LATEST_ROUND) finding $fid 미등장 — index desync"
    done
  fi
fi

if [ "$FAIL" -gt 0 ]; then
  echo "❌ 문서 카운트 drift ${FAIL}건 (실측 skills=$ACT_SKILLS agents=$ACT_AGENTS hooks=$ACT_HOOKS rules=$ACT_RULES)"
  exit 1
fi
echo "✓ 문서 카운트 일관 (skills=$ACT_SKILLS agents=$ACT_AGENTS hooks=$ACT_HOOKS rules=$ACT_RULES)"
exit 0
