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
ACT_HOOKS=$(find core/hooks -maxdepth 1 -name '*.sh' ! -name '_common.sh' 2>/dev/null | wc -l | tr -d ' ')
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

if [ "$FAIL" -gt 0 ]; then
  echo "❌ 문서 카운트 drift ${FAIL}건 (실측 skills=$ACT_SKILLS agents=$ACT_AGENTS hooks=$ACT_HOOKS rules=$ACT_RULES)"
  exit 1
fi
echo "✓ 문서 카운트 일관 (skills=$ACT_SKILLS agents=$ACT_AGENTS hooks=$ACT_HOOKS rules=$ACT_RULES)"
exit 0
