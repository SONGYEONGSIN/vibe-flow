#!/bin/bash
# sync-readme-badges.sh 계약 smoke (audit F-AA20)
# 실행: bash scripts/tests/badge-sync-smoke.sh
#
# 계약: **배지 생성기의 산출은 배지 게이트를 통과해야 한다.**
# 실측(2026-08-23) — 생성기를 돌리니 check-doc-counts 가 즉시 거부하는 README 가 나왔다:
#   ✗ README hooks  — 'README.md'에 30 (실측 27)   생성기는 하위 디렉토리·유틸까지 전부 셈
#   ✗ README agents — 'README.md'에 25 (실측 23)   생성기는 core+extensions, 게이트는 core 만
# 게다가 Skills 배지의 sed 패턴(`Core-[0-9]*_skills-`)은 현 README 형식(`Skills-45-blue`)과
# 매치조차 안 돼 **조용히 갱신되지 않는다**. 아무도 실행하지 않아 전부 무증상이었다.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PASS=0
FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# fixture = 추적 트리 + working-tree 수정분 (미추적 유입분 제외, F-AA19)
UNTRACKED_EXC=()
while IFS= read -r u; do
  [ -n "$u" ] && UNTRACKED_EXC+=(--exclude="./${u%/}")
done < <(cd "$REPO_ROOT" && git ls-files --others --exclude-standard --directory 2>/dev/null)
(cd "$REPO_ROOT" && tar --exclude=.git --exclude=node_modules "${UNTRACKED_EXC[@]}" -cf - . 2>/dev/null) \
  | (cd "$TMP" && tar -xf -) || { echo "fixture 생성 실패"; exit 1; }

echo "Test BS1: 배지를 흐트러뜨린 뒤 생성기가 복원한다"
# 세 배지를 전부 99 로 오염 — 생성기가 셋 다 되돌려야 한다
sed -i.bak -E 's|badge/Skills-[0-9]+-|badge/Skills-99-|; s|badge/Hooks-[0-9]+-|badge/Hooks-99-|; s|badge/Agents-[0-9]+-|badge/Agents-99-|' "$TMP/README.md"
rm -f "$TMP/README.md.bak"
(cd "$TMP" && bash scripts/sync-readme-badges.sh >/dev/null 2>&1)

left=$(grep -coE 'badge/(Skills|Hooks|Agents)-99-' "$TMP/README.md" || true)
if [ "$left" = "0" ]; then
  ok "BS1.1 Skills/Hooks/Agents 배지 전건 복원"
else
  ng "BS1.2 미복원 배지 $left 건 — sed 패턴이 현 README 형식과 어긋난다"
fi

echo "Test BS2: 생성기 산출이 게이트를 통과한다"
if (cd "$TMP" && bash scripts/check-doc-counts.sh >/dev/null 2>&1); then
  ok "BS2.1 sync 후 check-doc-counts exit 0"
else
  (cd "$TMP" && bash scripts/check-doc-counts.sh 2>&1 | grep '✗' | head -3 | sed 's/^/      /')
  ng "BS2.2 생성기 산출을 게이트가 거부 — 배지를 고치라는 도구가 배지 게이트를 깨뜨린다"
fi

echo "Test BS3: 이미 정합인 README 는 그대로 (멱등)"
cp "$TMP/README.md" "$TMP/README.before"
(cd "$TMP" && bash scripts/sync-readme-badges.sh >/dev/null 2>&1)
if cmp -s "$TMP/README.before" "$TMP/README.md"; then
  ok "BS3.1 재실행해도 무변경"
else
  ng "BS3.2 재실행이 README 를 또 바꾼다 — 수렴하지 않는다"
fi

echo "Test BS4: 배지 밖 drift 는 조용히 통과시키지 않는다"
# 생성기는 배지만 고친다. 본문 카운트('45 skills' 등)가 어긋나면 배지를 다 맞춰도
# 게이트는 실패한다 — 그때 exit 0 을 내면 "동기화 완료"라는 거짓 신호가 된다.
# 자기검증(생성 직후 check-doc-counts 호출)이 있어야만 비-zero 로 떨어진다.
sed -i.bak -E 's|[0-9]+ skills|99 skills|' "$TMP/README.md"; rm -f "$TMP/README.md.bak"
if (cd "$TMP" && bash scripts/sync-readme-badges.sh >/dev/null 2>&1); then
  ng "BS4.2 본문 drift 인데 exit 0 — 자기검증 부재, 거짓 '동기화 완료'"
else
  ok "BS4.1 본문 drift 를 감지해 비-zero 종료"
fi

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
