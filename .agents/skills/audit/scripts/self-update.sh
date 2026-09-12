#!/bin/bash
set -u
# self-update.sh — 자율 버전 bump 판정 + drift 검증 (T5/PR-4).
#
# 자율 루프가 main 에 변경을 누적한 뒤, 마지막 태그 이후 커밋에서 semver 를 계산해
# 릴리즈(버전 bump + 태그)를 준비한다. /release 는 사용자 확인이 필수(interactive)라
# 자율 경로엔 못 쓴다 → 본 스크립트가 비대화 판정을 담당한다.
#
# **default-safe 불변식**: AUTO_RELEASE 기본 "off" → HOLD_DISABLED(계산·보고만, 태그 X).
#   실제 릴리즈(태그 생성)는 운영자가 graduation(T6) 후 AUTO_RELEASE=on 설정 시에만.
#   push 는 하지 않는다(로컬 태그까지; 원격 push·마켓플레이스 publish 는 별도 gated).
#
# **한계(honest)**: cloud 루프는 ephemeral checkout 이라 사용자 **로컬 설치 플러그인**을
#   재동기 못 한다. 로컬 재동기는 `claude plugin update vibe-flow`(마켓플레이스 pull) 몫.
#   본 스크립트는 released 버전(plugin.json + 태그)이 main 을 반영하도록만 보장한다.
#
# env:
#   AUTO_RELEASE=on           릴리즈 적용(기본 off=report-only)
#   SELF_UPDATE_DRIFT_CHECK   drift 명령 override(테스트; 기본 sync-drift --check)
# 출력: DECISION=<NO_CHANGES|DRIFT_FAIL|HOLD_DISABLED|RELEASE_APPLIED> BUMP=.. NEXT_VERSION=..
# exit: 0(정상/report) / 3(drift fail).

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT" || exit 1

emit() { echo "DECISION=$1"; echo "BUMP=${2:-}"; echo "NEXT_VERSION=${3:-}"; }

# ── 마지막 태그 + 이후 커밋 ──
LAST_TAG=$(git tag -l 'v*' | sort -V | tail -1)
[ -z "$LAST_TAG" ] && LAST_TAG="v0.0.0"
CUR="${LAST_TAG#v}"
SUBJECTS=$(git log "${LAST_TAG}..HEAD" --format='%s' 2>/dev/null)

if [ -z "${SUBJECTS// /}" ]; then
  emit "NO_CHANGES" "" "$CUR"
  echo "[self-update] $LAST_TAG 이후 커밋 없음 — 릴리즈 불필요" >&2
  exit 0
fi

# ── semver bump 판정 ──
BUMP="patch"
if echo "$SUBJECTS" | grep -qE 'BREAKING CHANGE|^[a-z]+(\(.+\))?!:'; then
  BUMP="major"
elif echo "$SUBJECTS" | grep -qE '^feat(\(.+\))?:'; then
  BUMP="minor"
fi
IFS=. read -r MAJ MIN PAT <<EOF
$CUR
EOF
MAJ=${MAJ:-0}; MIN=${MIN:-0}; PAT=${PAT:-0}
case "$BUMP" in
  major) NEXT="$((MAJ+1)).0.0" ;;
  minor) NEXT="${MAJ}.$((MIN+1)).0" ;;
  patch) NEXT="${MAJ}.${MIN}.$((PAT+1))" ;;
esac

# ── drift 검증 ──
DRIFT_CMD="${SELF_UPDATE_DRIFT_CHECK:-bash '$ROOT/core/scripts/sync-drift.sh' --check}"
if ! eval "$DRIFT_CMD" >/dev/null 2>&1; then
  emit "DRIFT_FAIL" "$BUMP" "$NEXT"
  echo "[self-update] ⚠ drift 검증 실패 — 릴리즈 보류(core↔.claude 불일치)" >&2
  exit 3
fi

# ── default-safe: AUTO_RELEASE off → report-only ──
# release 개방 소스: AUTO_RELEASE env(테스트/수동) 우선, 없으면 graduation tier(structural 이상, T6).
AR="${AUTO_RELEASE:-}"
if [ -z "$AR" ]; then
  GRADSH="$ROOT/core/skills/audit/scripts/graduation.sh"
  if [ -f "$GRADSH" ]; then
    case "$(bash "$GRADSH" tier 2>/dev/null)" in structural|generative) AR="on" ;; *) AR="off" ;; esac
  fi
  AR="${AR:-off}"
fi
if [ "$AR" != "on" ]; then
  emit "HOLD_DISABLED" "$BUMP" "$NEXT"
  echo "[self-update] report-only(release 미개방) — 준비됨: $CUR → $NEXT ($BUMP). 개방은 AUTO_RELEASE=on 또는 graduation structural+." >&2
  exit 0
fi

# ── 릴리즈 적용 (AUTO_RELEASE=on) ──
tmp=$(mktemp)
jq --arg v "$NEXT" '.version=$v' .claude-plugin/plugin.json > "$tmp" && mv "$tmp" .claude-plugin/plugin.json
if [ -f .claude-plugin/marketplace.json ] && jq -e '.plugins[0].version // .version' .claude-plugin/marketplace.json >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq --arg v "$NEXT" '(.plugins[0].version // empty) as $_ | if .plugins then (.plugins[0].version=$v) else (.version=$v) end' \
    .claude-plugin/marketplace.json > "$tmp" 2>/dev/null && mv "$tmp" .claude-plugin/marketplace.json
fi
[ -f CHANGELOG.md ] && printf '\n## v%s\n\n(self-update auto-release)\n' "$NEXT" >> CHANGELOG.md
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md >/dev/null 2>&1
git commit -qm "chore: release v${NEXT}" >/dev/null 2>&1
git tag "v${NEXT}" >/dev/null 2>&1
emit "RELEASE_APPLIED" "$BUMP" "$NEXT"
echo "[self-update] ✓ 릴리즈 적용 v$NEXT (로컬 태그·커밋만; push·마켓플레이스는 별도 gated). 로컬 설치 재동기는 claude plugin update." >&2
exit 0
