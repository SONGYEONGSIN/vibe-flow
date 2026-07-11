#!/bin/bash
# eval-regression-check.sh 게이트 사각 스모크 — fixture 기반 RED/GREEN
#
# F-L08 (audit R12): section E 플로어가 SKILL.md *파일*이 아니라 *디렉토리* 수를 세고,
# section A 는 부재 파일을 iterate-skip 하므로 두 fail-open 이 합성돼
# "SKILL.md 없는 스킬 디렉토리"가 머지 게이트를 exit 0 으로 통과했다.
#
# F-L09 (audit R12): F-K10 의 "커버리지 0 ≠ 통과" 가드가 section C 에만 적용되고
# 형제 섹션 A(skills)/B(agents)는 glob 0매칭 시 "valid (0 files)" 를 성공으로 렌더.
#
# 원본 트리를 건드리지 않기 위해 pristine 복사본에서 케이스별 fixture 를 만든다.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS+1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

PRISTINE="$TMP/pristine"
mkdir -p "$PRISTINE"
(cd "$REPO_ROOT" && tar --exclude=.git --exclude=node_modules -cf - . 2>/dev/null) \
  | (cd "$PRISTINE" && tar -xf -) || { echo "fixture 생성 실패"; exit 1; }

new_case() { # $1=케이스 dir 이름 → 경로 echo
  local d="$TMP/$1"
  cp -R "$PRISTINE" "$d"
  echo "$d"
}

echo "=== 양성 대조: 온전한 fixture 는 exit 0 ==="
C0="$(new_case c0-intact)"
(cd "$C0" && bash scripts/eval-regression-check.sh >/dev/null 2>&1)
[ $? -eq 0 ] && ok "온전한 fixture exit 0" \
             || ng "온전한 fixture 가 이미 실패 — 대조군 무효"

echo "=== F-L08: SKILL.md 없는 스킬 dir 은 통과가 아니라 실패여야 ==="
C1="$(new_case c1-missing-skillmd)"
rm "$C1/extensions/k8s/skills/k8s-audit/SKILL.md" || { echo "fixture 삭제 실패"; exit 1; }
out1="$(cd "$C1" && bash scripts/eval-regression-check.sh 2>&1)"; rc1=$?
[ "$rc1" -ne 0 ] && ok "SKILL.md 1건 삭제(dir 유지) → exit≠0" \
                 || ng "SKILL.md 없는 스킬 dir 인데 exit 0 (fail-open 합성)"
echo "$out1" | grep -q "✗.*SKILL" \
  && ok "실패 라인에 SKILL.md 진단 존재" \
  || ng "SKILL.md 부재가 어떤 실패 진단도 남기지 않음"

echo "=== F-L09(A): SKILL.md 전량 0건은 'valid (0 files)' 가 아니라 실패여야 ==="
C2="$(new_case c2-zero-skills)"
find "$C2/core/skills" "$C2/extensions" -name SKILL.md -delete
out2="$(cd "$C2" && bash scripts/eval-regression-check.sh 2>&1)"
echo "$out2" | grep -q "All SKILL.md frontmatter valid (0 files)" \
  && ng '"valid (0 files)" 를 성공으로 렌더 (vacuous pass)' \
  || ok "SKILL.md 0건을 성공으로 렌더하지 않음"
echo "$out2" | grep -q "✗.*SKILL.md 0건" \
  && ok "SKILL.md 0건 실패 진단 존재" \
  || ng "SKILL.md 0건이 커버리지-0 진단을 남기지 않음"

echo "=== F-L09(B): agents 0건은 'valid (0 files)' 가 아니라 실패여야 ==="
C3="$(new_case c3-zero-agents)"
find "$C3/core/agents" -name '*.md' -delete
rm -f "$C3"/extensions/*/agents/*.md 2>/dev/null
printf '{"agents": []}\n' > "$C3/core/agents.json"   # section D 간섭 제거 — B 의 자체 가드만 측정
out3="$(cd "$C3" && bash scripts/eval-regression-check.sh 2>&1)"
echo "$out3" | grep -q "All agents.md frontmatter valid (0 files)" \
  && ng '"valid (0 files)" 를 성공으로 렌더 (vacuous pass)' \
  || ok "agents 0건을 성공으로 렌더하지 않음"
echo "$out3" | grep -q "✗.*agents.*0건" \
  && ok "agents 0건 실패 진단 존재" \
  || ng "agents 0건이 커버리지-0 진단을 남기지 않음"

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -eq 0 ]
