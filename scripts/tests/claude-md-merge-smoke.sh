#!/bin/bash
# setup.sh CLAUDE.md 누락 섹션 병합 smoke test (audit F-AA16)
# 실행: bash scripts/tests/claude-md-merge-smoke.sh
#
# setup.sh:566 은 `if [ ! -f CLAUDE.md ]` — 이미 있으면 skipped 다. rules/agents/skills 는
# safe_copy 로 백업 후 덮어써서 갱신이 전파되는데, CLAUDE.md 만 안 간다.
# settings.local.json 은 같은 skip-if-exists 라도 --upgrade 탈출구가 있으나 이쪽엔 그것도 없다.
# 결과: 템플릿에 새 섹션(F-AA12 Agent Routing)을 추가해도 **기존 프로젝트는 영원히 못 받는다**.
#
# 계약: 템플릿에 있고 대상에 없는 `## ` 섹션은 append 한다.
#   - **비파괴** — 기존 본문은 한 글자도 바꾸지 않는다 (사용자 소유 파일)
#   - 백업 후 수정, 무엇을 넣었는지 stdout 표면화
#   - 멱등 — 재실행해도 중복 append 없음

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SETUP_SH="$REPO_ROOT/setup.sh"
TPL="$REPO_ROOT/templates/CLAUDE.md.template"

PASS=0
FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

GIT_ISOLATE=(env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_CONFIG_NOSYSTEM=1)

PROJ="$TMP/proj"
mkdir -p "$PROJ" && (cd "$PROJ" && git init -q)

# 기존 프로젝트를 모사 — 사용자가 손댄 CLAUDE.md 가 이미 있고, 신규 섹션은 없다
USER_LINE="이 프로젝트는 사내 정산 배치를 다룬다. 절대 지우면 안 되는 사용자 문장."
cat > "$PROJ/CLAUDE.md" <<EOF
# proj

## Tech Stack
- 사용자가 직접 채운 내용

## Commands
$USER_LINE
EOF

echo "=== 1회차: 누락 섹션 append ==="
out1=$(cd "$PROJ" && "${GIT_ISOLATE[@]}" bash "$SETUP_SH" 2>&1)

if grep -q '^## Agent Routing' "$PROJ/CLAUDE.md"; then
  ok "CM.1 템플릿 신규 섹션(Agent Routing) 이 기존 CLAUDE.md 에 반영"
else
  ng "CM.1 Agent Routing 미반영 — 기존 프로젝트는 템플릿 갱신을 영영 못 받는다"
fi

if grep -qF "$USER_LINE" "$PROJ/CLAUDE.md"; then
  ok "CM.2 사용자 본문 보존 (비파괴)"
else
  ng "CM.2 사용자 본문 소실 — 덮어쓰기는 허용되지 않는다"
fi

# 사용자가 채운 Tech Stack 본문이 템플릿 것으로 치환되지 않아야 한다
if grep -qF '사용자가 직접 채운 내용' "$PROJ/CLAUDE.md"; then
  ok "CM.3 이미 있는 섹션의 본문은 템플릿으로 치환 안 함"
else
  ng "CM.3 기존 섹션 본문이 템플릿으로 덮였다"
fi

if ls "$PROJ"/CLAUDE.md.bak.* >/dev/null 2>&1; then
  ok "CM.4 수정 전 백업 생성"
else
  ng "CM.4 백업 없이 사용자 파일 수정"
fi

if echo "$out1" | grep -q 'Agent Routing'; then
  ok "CM.5 무엇을 넣었는지 stdout 표면화"
else
  ng "CM.5 조용한 수정 — 사용자가 알 수 없다"
fi

echo "=== 2회차: 멱등 ==="
(cd "$PROJ" && "${GIT_ISOLATE[@]}" bash "$SETUP_SH" >/dev/null 2>&1)
n=$(grep -c '^## Agent Routing' "$PROJ/CLAUDE.md")
if [ "$n" -eq 1 ]; then
  ok "CM.6 재실행해도 중복 append 없음 (1건)"
else
  ng "CM.6 Agent Routing $n 건 — 재실행마다 누적된다"
fi

echo "=== 신규 프로젝트 경로는 그대로 ==="
PROJ2="$TMP/proj-new"
mkdir -p "$PROJ2" && (cd "$PROJ2" && git init -q)
(cd "$PROJ2" && "${GIT_ISOLATE[@]}" bash "$SETUP_SH" >/dev/null 2>&1)
tpl_secs=$(grep -c '^## ' "$TPL")
new_secs=$(grep -c '^## ' "$PROJ2/CLAUDE.md" 2>/dev/null || echo 0)
if [ "$new_secs" -eq "$tpl_secs" ]; then
  ok "CM.7 신규 생성 경로 유지 (섹션 $new_secs 개 = 템플릿)"
else
  ng "CM.7 신규 생성 섹션 $new_secs (템플릿 $tpl_secs) — 기존 동작 회귀"
fi

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -eq 0 ]
