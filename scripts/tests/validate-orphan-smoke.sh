#!/bin/bash
# validate.sh [9/10] State ↔ Filesystem reconciliation 스모크 — fixture 기반 RED/GREEN
#
# F-K05 (audit R11): reconciliation 블록은 `[ -f "$STATE" ]` 게이트 뒤에 있고
# STATE=.claude/.vibe-flow.json 은 setup.sh 만 생성한다. vibe-flow 소스 트리는 자기 자신에
# setup 을 돌리지 않고 CI 는 fresh clone 이라, 이 블록은 dead code 가 아니라 *unexercised*
# code 였다. 그래서 F-J07(R10) 은 참·거짓을 만들 실행 경로 없이 refuted 됐다.
# 여기서 STATE 를 갖춘 임시 프로젝트를 만들어 orphan 경로를 실제로 태운다.
#
# F-K04 (audit R11): EXT_SIGNATURES 가 하드코딩 리터럴 10개라 extensions/ 실측 12개 중
# i18n-audit·k8s-audit 을 놓친다. 아래 assert 는 F-K04 적용 전 RED 다.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS+1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# 최소 프로젝트: STATE 존재(= reconciliation 진입) + extension 스킬 2개가 state 에 미등록(= orphan)
mkdir -p "$TMP/.claude/skills/frontend-flow" "$TMP/.claude/skills/i18n-audit"
echo '{"extensions":{}}' > "$TMP/.claude/.vibe-flow.json"

# VIBE_FLOW_ROOT 를 실 repo 로 고정해 is_base_skill 이 core/skills/ 를 실측 enumerate 하게 한다
# (두 스킬 모두 core 가 아니므로 orphan 판정 단계까지 도달).
out="$(VIBE_FLOW_ROOT="$REPO_ROOT" bash "$REPO_ROOT/validate.sh" "$TMP" 2>&1)"

echo "=== reconciliation 블록이 실제로 실행되는가 ==="
echo "$out" | grep -q "reconciliation 건너뜀" \
  && ng "STATE 있는데도 건너뜀 — 블록 미진입" \
  || ok "STATE 존재 → reconciliation 진입"

echo "=== orphan 탐지: extensions/ 실측 전량 커버 (F-K04) ==="
# extensions/ 에서 실측한 스킬은 전부 EXT_SIGNATURES 에 잡혀야 한다.
# 하드코딩 리터럴이면 신규 확장이 조용히 누락된다.
for skill in frontend-flow i18n-audit; do
  echo "$out" | grep -q "orphan ext skill: $skill" \
    && ok "orphan 탐지: $skill" \
    || ng "orphan 미탐지: $skill (EXT_SIGNATURES 누락)"
done

echo "=== 음성 대조: state 에 등록된 확장은 orphan 아님 ==="
cat > "$TMP/.claude/.vibe-flow.json" <<'JSON'
{"extensions":{"design-system":{"files":["skills/frontend-flow/SKILL.md"]}}}
JSON
out2="$(VIBE_FLOW_ROOT="$REPO_ROOT" bash "$REPO_ROOT/validate.sh" "$TMP" 2>&1)"
echo "$out2" | grep -q "orphan ext skill: frontend-flow" \
  && ng "state 등록된 스킬을 orphan 으로 오탐" \
  || ok "state 등록 스킬은 orphan 아님 (오탐 없음)"
echo "$out2" | grep -q "orphan ext skill: i18n-audit" \
  && ok "미등록 스킬은 여전히 orphan (탐지 유지)" \
  || ng "미등록 i18n-audit 을 놓침"

echo "=== downstream 폴백: extensions/ 부재 시 리터럴 whitelist 사용 (F-K04) ==="
# 소비자 프로젝트에는 core/·extensions/ 가 없다. 실측 enumerate 가 빈 결과를 내도
# EXT_SIGNATURES 가 빈 문자열로 무너져 탐지가 0 이 되면 안 된다(폴백 분기 고정).
DOWN="$TMP/downstream"; mkdir -p "$DOWN"
echo '{"extensions":{}}' > "$TMP/.claude/.vibe-flow.json"
out3="$(VIBE_FLOW_ROOT="$DOWN" bash "$REPO_ROOT/validate.sh" "$TMP" 2>&1)"
echo "$out3" | grep -q "orphan ext skill: frontend-flow" \
  && ok "downstream 폴백에서도 리터럴 시그니처 탐지 유지" \
  || ng "폴백 붕괴 — EXT_SIGNATURES 빈 문자열 추정"

echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 실패: $FAIL"
[ "$FAIL" -eq 0 ]
