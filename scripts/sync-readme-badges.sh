#!/bin/bash
# sync-readme-badges.sh — README 배지 수치 자동 갱신
#
# 사용:
#   bash scripts/sync-readme-badges.sh
#
# 갱신 대상 (README의 shields.io 정적 배지):
#   Core skills, Extension skills, Hooks, Agents 카운트

set -u

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT" || exit 1

CORE=$(find core/skills -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
EXT=$(find extensions -mindepth 3 -maxdepth 3 -type d -path '*/skills/*' 2>/dev/null | wc -l | tr -d ' ')
HOOKS=$(find core/hooks -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ')
AGENTS_CORE=$(find core/agents -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
AGENTS_EXT=$(find extensions -path '*/agents/*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
AGENTS_TOTAL=$((AGENTS_CORE + AGENTS_EXT))

if [ ! -f README.md ]; then
  echo "ERROR: README.md 없음" >&2
  exit 1
fi

# README 배지 수치 sed 갱신 (shields.io 정적 배지 패턴)
sed -i.tmp \
  -e "s|Core-[0-9]*_skills-|Core-${CORE}_skills-|" \
  -e "s|Extensions-[0-9]*_skills-|Extensions-${EXT}_skills-|" \
  -e "s|Hooks-[0-9]*-|Hooks-${HOOKS}-|" \
  -e "s|Agents-[0-9]*-|Agents-${AGENTS_TOTAL}-|" \
  README.md
rm -f README.md.tmp

echo "✓ Badges synced:"
echo "  Core skills:       ${CORE}"
echo "  Extension skills:  ${EXT}"
echo "  Hooks:             ${HOOKS}"
echo "  Agents (총):       ${AGENTS_TOTAL} (Core ${AGENTS_CORE} + Ext ${AGENTS_EXT})"
