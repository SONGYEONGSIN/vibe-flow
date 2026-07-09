#!/bin/bash
# core/scripts/sync-drift.sh — core/ ↔ .claude/ drift 일괄 sync
#
# validate.sh F-C1 가 발견하는 drift (agents/skills/rules/scripts/hooks/docs)
# 를 일괄 cp 로 정합. setup.sh --upgrade 대비 lightweight — settings 재생성 X.
#
# 사용법:
#   bash core/scripts/sync-drift.sh             # 실 sync 적용
#   bash core/scripts/sync-drift.sh --check     # drift 카운트만 출력 (dry-run, exit 1 if drift)
#   bash core/scripts/sync-drift.sh --verbose   # 각 파일 sync 내역 출력
#
# 정책:
#   - core → .claude 단방향 (.claude/ 는 install target, 사용자 직접 편집 비권장)
#   - 사용자 .claude/ 수동 편집은 backup 없이 overwrite — 우려 시 --check 로 사전 확인
#   - .claude/hooks/_common.sh 등 helper 도 sync 대상
#
# 종료 코드:
#   0 = drift 0 (--check) 또는 sync 완료 (default)
#   1 = drift 발견 (--check 모드)
#   2 = 환경 오류 (PROJECT_ROOT 못 찾음 등)

set -u

MODE="apply"
VERBOSE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --verbose) VERBOSE=1 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
[ -d "$PROJECT_ROOT/core" ] && [ -d "$PROJECT_ROOT/.claude" ] || {
  echo "error: core/ + .claude/ both required at $PROJECT_ROOT" >&2
  exit 2
}

cd "$PROJECT_ROOT" || exit 2

DRIFT_COUNT=0
SYNC_COUNT=0
# F-K12 (audit R11): 열거된 core/ 소스 파일 수. drift 를 core/ 측 순회로 계산하므로
# 소스 0건이면 비교 0건이고, 이를 "clean" 으로 렌더하면 깨진 설치가 통과한다.
SRC_COUNT=0

log_verbose() { [ "$VERBOSE" = 1 ] && echo "  $1"; }

# ── 1. agents/ (단일 디렉토리) ────────────────────────────
sync_dir_flat() {
  local subpath="$1"
  for src in "core/$subpath"/*.md "core/$subpath"/*.sh; do
    [ -f "$src" ] || continue
    SRC_COUNT=$((SRC_COUNT + 1))
    local name=$(basename "$src")
    local dst=".claude/$subpath/$name"
    if [ ! -f "$dst" ] || ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
      if [ "$MODE" = "apply" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        [ "${src##*.}" = "sh" ] && chmod +x "$dst"
        SYNC_COUNT=$((SYNC_COUNT + 1))
        log_verbose "synced: $subpath/$name"
      fi
    fi
  done
}

# ── 2. skills/ (재귀 — SKILL.md + 하위 scripts/data/references/assets/jurisdictions) ─
sync_skills_recursive() {
  while IFS= read -r src; do
    [ -f "$src" ] || continue
    SRC_COUNT=$((SRC_COUNT + 1))
    local rel="${src#core/}"
    local dst=".claude/$rel"
    if [ ! -f "$dst" ] || ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
      if [ "$MODE" = "apply" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        [ "${src##*.}" = "sh" ] && chmod +x "$dst"
        SYNC_COUNT=$((SYNC_COUNT + 1))
        log_verbose "synced: $rel"
      fi
    fi
  done < <(find core/skills -type f \( -name '*.md' -o -name '*.sh' -o -name '*.json' \) 2>/dev/null)
}

# ── 3. hooks/ — git-post-commit.sh 는 .git/hooks 로 install 되므로 skip ────
sync_hooks() {
  local skip_list=" git-post-commit.sh "
  for src in core/hooks/*.sh; do
    [ -f "$src" ] || continue
    SRC_COUNT=$((SRC_COUNT + 1))
    local name=$(basename "$src")
    case "$skip_list" in
      *" $name "*) continue ;;
    esac
    local dst=".claude/hooks/$name"
    if [ ! -f "$dst" ] || ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
      if [ "$MODE" = "apply" ]; then
        mkdir -p ".claude/hooks"
        cp "$src" "$dst"
        chmod +x "$dst"
        SYNC_COUNT=$((SYNC_COUNT + 1))
        log_verbose "synced: hooks/$name"
      fi
    fi
  done
}

# ── 실행 ──────────────────────────────────────────────────
echo "[sync-drift] scanning core/ ↔ .claude/ ..."

sync_dir_flat "agents"
sync_dir_flat "rules"
sync_skills_recursive
sync_hooks

# validate.sh 자체도 sync (root validate.sh → .claude/validate.sh)
if [ -f "validate.sh" ] && [ -f ".claude/validate.sh" ]; then
  if ! diff -q "validate.sh" ".claude/validate.sh" >/dev/null 2>&1; then
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    if [ "$MODE" = "apply" ]; then
      cp "validate.sh" ".claude/validate.sh"
      SYNC_COUNT=$((SYNC_COUNT + 1))
      log_verbose "synced: validate.sh"
    fi
  fi
fi

# F-G03 (audit R7): agents.json (message-bus 레지스트리) — sync_dir_flat 글롭(core/agents/*) 밖 파일
if [ -f "core/agents.json" ]; then
  if [ ! -f ".claude/agents.json" ] || ! diff -q "core/agents.json" ".claude/agents.json" >/dev/null 2>&1; then
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    if [ "$MODE" = "apply" ]; then
      cp "core/agents.json" ".claude/agents.json"
      SYNC_COUNT=$((SYNC_COUNT + 1))
      log_verbose "synced: agents.json"
    fi
  fi
fi

# ── 결과 ──────────────────────────────────────────────────
if [ "$MODE" = "check" ]; then
  # F-K12 (audit R11): 소스 0건이면 비교도 0건이라 DRIFT_COUNT=0 이 되고, 이를 "clean" 으로
  # 렌더하면 깨진 설치(core/ 소실)가 통과한다. --check 의 계약은 그것을 *탐지*하는 것이다.
  # apply 모드는 "동기화할 소스 없음"이 방어 가능하므로 --check 한정으로 fail-closed.
  if [ "$SRC_COUNT" -eq 0 ]; then
    echo "[sync-drift] core/ 소스 0건 — 환경 오류 (커버리지 0 ≠ drift 0)" >&2
    exit 2
  fi
  if [ "$DRIFT_COUNT" -eq 0 ]; then
    echo "[sync-drift] no drift detected ✓"
    exit 0
  else
    echo "[sync-drift] $DRIFT_COUNT drift entries detected"
    echo "  → bash core/scripts/sync-drift.sh   # apply sync"
    exit 1
  fi
fi

if [ "$DRIFT_COUNT" -eq 0 ]; then
  echo "[sync-drift] no drift to sync ✓"
else
  echo "[sync-drift] $SYNC_COUNT files synced (of $DRIFT_COUNT drift entries)"
fi

exit 0
