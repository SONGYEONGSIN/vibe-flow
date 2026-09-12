#!/bin/bash
# eval-regression-check.sh 공허한 통과(vacuous pass) 스모크 — fixture 기반 RED/GREEN
#
# F-K10 (audit R11): `for f in <glob>; do [ -f "$f" ] || continue; ...; done` 뒤에
# `[ "$FAIL" = "$BEFORE" ] && ok "... (${COUNT} files)"` 형태는 glob 미매칭 시
# FAIL 이 불변이라 "검사 대상 0건"을 "결함 0건"으로 렌더한다. evals.json 33개를
# 전부 지워도 머지 게이트가 exit 0 을 반환하던 경로를 고정한다.
#
# 원본 트리를 건드리지 않기 위해 tar 로 임시 fixture 를 만든 뒤 그 안에서만 실행한다.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS+1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

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
  | (cd "$TMP" && tar -xf -) || { echo "fixture 생성 실패"; exit 1; }

echo "=== 양성 대조: evals.json 온전하면 통과 ==="
# yq/python3 부재 시 templates 블록은 warn+skip 이라 exit code 에 영향 없음 (CI-safe).
seed_count=$(find "$TMP" -name evals.json | wc -l | tr -d ' ')
[ "$seed_count" -gt 0 ] || { echo "fixture 에 evals.json 이 없음 — 테스트 전제 붕괴"; exit 1; }
(cd "$TMP" && bash scripts/eval-regression-check.sh >/dev/null 2>&1)
[ $? -eq 0 ] && ok "온전한 fixture (evals=${seed_count}) exit 0" \
             || { ng "온전한 fixture 가 이미 실패 — 대조군 무효 — 이후 변이 단언 vacuous"; exit 1; }

echo "=== F-K10: evals.json 0건은 통과가 아니라 실패여야 ==="
find "$TMP" -name evals.json -delete
[ "$(find "$TMP" -name evals.json | wc -l | tr -d ' ')" -eq 0 ] || { echo "삭제 실패"; exit 1; }

out="$(cd "$TMP" && bash scripts/eval-regression-check.sh 2>&1)"; rc=$?

[ "$rc" -ne 0 ] && ok "evals 0건 → exit≠0 (커버리지 0 ≠ 통과)" \
                || ng "evals 0건인데 exit 0 (공허한 통과)"

echo "$out" | grep -q "valid (0 files)" \
  && ng '"All evals.json valid (0 files)" 를 성공으로 출력' \
  || ok "0건을 성공으로 렌더하지 않음"

# 성공 라인("✓ All evals.json valid")에도 "evals" 가 들어가므로 실패 마커에 한정해 검사한다
# (느슨한 grep 은 fix 전후 모두 통과하는 공허한 단언 — 본 테스트가 잡으려는 결함과 동형).
echo "$out" | grep -q "✗.*evals" \
  && ok "실패 라인에 evals 진단 존재" \
  || ng "evals 0건이 어떤 실패 진단도 남기지 않음"

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -eq 0 ]
