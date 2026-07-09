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

(cd "$REPO_ROOT" && tar --exclude=.git --exclude=node_modules -cf - . 2>/dev/null) \
  | (cd "$TMP" && tar -xf -) || { echo "fixture 생성 실패"; exit 1; }

echo "=== 양성 대조: evals.json 온전하면 통과 ==="
# yq/python3 부재 시 templates 블록은 warn+skip 이라 exit code 에 영향 없음 (CI-safe).
seed_count=$(find "$TMP" -name evals.json | wc -l | tr -d ' ')
[ "$seed_count" -gt 0 ] || { echo "fixture 에 evals.json 이 없음 — 테스트 전제 붕괴"; exit 1; }
(cd "$TMP" && bash scripts/eval-regression-check.sh >/dev/null 2>&1)
[ $? -eq 0 ] && ok "온전한 fixture (evals=${seed_count}) exit 0" \
             || ng "온전한 fixture 가 이미 실패 — 대조군 무효"

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
