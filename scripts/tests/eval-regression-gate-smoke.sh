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
# F-AA19: `tar .` 는 **미추적 파일까지** fixture 에 복사한다. ~/.claude/skills 가
# core/skills 의 심볼릭 링크라 전역 설치된 외부 스킬이 작업트리에 상주하고, 그것이
# fixture 로 넘어가 대조군(온전한 fixture)이 이미 실패했다 — 워킹트리 오염이 게이트
# 결과를 좌우한다. 추적분은 제외 없이, **미추적 항목만** 빼서 CI 와 같은 트리를 만든다.
# (working-tree 수정분은 남겨야 한다 — 커밋 전 스크립트를 검증하는 것이 이 스모크의 목적)
UNTRACKED_EXC=()
while IFS= read -r u; do
  [ -n "$u" ] && UNTRACKED_EXC+=(--exclude="./${u%/}")
done < <(cd "$REPO_ROOT" && git ls-files --others --exclude-standard --directory 2>/dev/null)
(cd "$REPO_ROOT" && tar --exclude=.git --exclude=node_modules "${UNTRACKED_EXC[@]}" -cf - . 2>/dev/null) \
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
             || { ng "온전한 fixture 가 이미 실패 — 대조군 무효 — 이후 변이 단언 vacuous"; exit 1; }

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
# F-R08: agents.json 을 []로 비워 section D 를 "간섭 제거"하던 과거 방식은 section D 가
# 자체 커버리지-0 가드를 갖기 전까지만 유효했다 — 이제 실제 agent 파일이 0건인 채로
# agents.json 도 0건인 이 fixture는 D 입장에서도 "진짜로 커버리지 0"이라 D 역시 정당하게
# 실패해야 한다(간섭이 아니라 올바른 신규 동작). 그래서 agents.json 은 pristine 그대로
# 두지 않고 "실제로 파일이 0건"이라는 사실과 일치하게 []로 유지하되, B 와 D 양쪽
# 커버리지-0 가드가 모두 발현되는지 둘 다 단언한다(F-R08 fix).
printf '{"agents": []}\n' > "$C3/core/agents.json"
out3="$(cd "$C3" && bash scripts/eval-regression-check.sh 2>&1)"
echo "$out3" | grep -q "All agents.md frontmatter valid (0 files)" \
  && ng '"valid (0 files)" 를 성공으로 렌더 (vacuous pass)' \
  || ok "agents 0건을 성공으로 렌더하지 않음"
echo "$out3" | grep -q "✗.*agents.*0건" \
  && ok "agents 0건 실패 진단 존재" \
  || ng "agents 0건이 커버리지-0 진단을 남기지 않음"
echo "$out3" | grep -q "agents.json .agents 0건" \
  && ok "F-R08: agents.json .agents 0건도 별도로 진단됨 (section D 커버리지-0 가드)" \
  || ng "F-R08: agents.json 쪽 커버리지-0 가드가 발현되지 않음"

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -eq 0 ]
