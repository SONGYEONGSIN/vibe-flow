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

# F-AA19: ~/.claude/skills 심볼릭 링크로 유입된 외부 스킬을 세지 않는다 (추적 대상만)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CORE=$(git ls-files core/skills | awk -F/ 'NF>2 {print $3}' | sort -u | wc -l | tr -d ' ')
else
  CORE=$(find core/skills -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
fi
# F-AC03: core/{skills,agents,rules} 는 `~/.claude/*` 심볼릭 링크 대상이라 전역 설치된
# 외부 자산이 작업트리에 상주한다(readlink 실측). F-AA19 가 skills 만 추적 기준으로
# 바꿨고 agents·rules 는 평문 find 로 남아 같은 결함이 잠복해 있었다 — 하나만 깔려도
# 로컬이 CI 와 다른 값을 센다. core/hooks 는 링크 대상이 아니라 그대로 둔다.
tracked_names() {  # $1=서브디렉토리 $2=확장자 → basename 목록 (비-git 은 find 폴백)
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files "core/$1" | awk -F/ -v e="$2" 'NF==3 && $3 ~ ("\\." e "$") {print $3}'
  else
    find "core/$1" -maxdepth 1 -name "*.$2" -exec basename {} \; 2>/dev/null
  fi
}

# F-AA20: 카운트·배제 규칙을 check-doc-counts.sh 의 ACT_* 와 **1:1로 유지**한다.
# 두 계기가 각자 규칙을 정의하면 생성기 산출을 게이트가 거부한다 — 실측(2026-08-23):
#   hooks  30 vs 27  (생성기는 하위 디렉토리 + _common/message-bus/git-post-commit 포함)
#   agents 25 vs 23  (생성기는 core+extensions, 게이트는 core 만)
# Extensions 배지는 **팩 수**(7)지 스킬 수(12)가 아니다 — 세는 대상이 다르므로 별도 식.
EXT_PACKS=$(find extensions -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
AGENTS=$(tracked_names agents md | grep -vxF 'README.md' | grep -c . || true)
HOOKS=$(find core/hooks -maxdepth 1 -name '*.sh' ! -name '_common.sh' ! -name 'message-bus.sh' ! -name 'git-post-commit.sh' 2>/dev/null | wc -l | tr -d ' ')

if [ ! -f README.md ]; then
  echo "ERROR: README.md 없음" >&2
  exit 1
fi

# README 배지 수치 sed 갱신.
# F-AA20: 기존 패턴 `Core-[0-9]*_skills-` / `Extensions-[0-9]*_skills-` 는 현 README
# 형식(`badge/Skills-45-blue`)과 매치조차 안 돼 **조용히 갱신되지 않았다**. 실제 형식에
# 맞춘다 — 배지 형식이 또 바뀌면 BS1 이 미복원 건수로 잡는다.
sed -i.tmp \
  -e "s|badge/Skills-[0-9]*-|badge/Skills-${CORE}-|" \
  -e "s|badge/Extensions-[0-9]*-|badge/Extensions-${EXT_PACKS}-|" \
  -e "s|badge/Hooks-[0-9]*-|badge/Hooks-${HOOKS}-|" \
  -e "s|badge/Agents-[0-9]*-|badge/Agents-${AGENTS}-|" \
  README.md
rm -f README.md.tmp

echo "✓ Badges synced:"
echo "  Skills:      ${CORE}"
echo "  Extensions:  ${EXT_PACKS} (팩 수 — 스킬 수 아님)"
echo "  Hooks:       ${HOOKS}"
echo "  Agents:      ${AGENTS}"

# F-AA20: 자기 산출을 게이트로 검증한다. 생성기와 게이트가 갈라지면 여기서 즉시 드러난다
# (본문 카운트 'N skills' 등 배지 밖 drift 도 같이 보고된다 — 그건 손으로 고칠 몫).
GATE="$(dirname "$0")/check-doc-counts.sh"
if bash "$GATE" >/dev/null 2>&1; then
  echo "✓ check-doc-counts 통과"
else
  echo "✗ 산출이 게이트를 통과하지 못했다:" >&2
  bash "$GATE" 2>&1 | grep '✗' >&2
  exit 1
fi
