#!/bin/bash
# cloud-init.sh — cloud remote agent session bootstrap (Phase 4 F16 fix)
#
# 목적:
#   cloud session은 fresh git clone이라 `.claude/hooks/` 와 `.claude/settings.json` 부재.
#   PreToolUse hook(auto-build-safety.sh) wire를 위해 본 script가 cloud-prompt-template
#   에서 run-cloud.sh 호출 직전 1회 실행되어 다음을 install:
#     - core/hooks/auto-build-safety.sh → .claude/hooks/auto-build-safety.sh
#     - settings/settings.template.json → .claude/settings.json
#
# local dev 환경은 setup.sh가 이미 처리하므로 본 script는 cloud session 전용.
# "skip if exists" 정책 (setup.sh와 일관) — 기존 user 설정 보존.
#
# 사용:
#   bash core/skills/auto-build/scripts/cloud-init.sh
#
# env:
#   CLOUD_INIT_DRYRUN=1 — 실 install 안 함, "would install: ..." stderr만 출력
#   CLOUD_INIT_FORCE=1  — 기존 파일 강제 overwrite (default skip)

set -u

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DRYRUN="${CLOUD_INIT_DRYRUN:-0}"

# ── source 경로 검증 ──────────────────────────────────────
SAFETY_HOOK_SRC="$PROJECT_ROOT/core/hooks/auto-build-safety.sh"
SETTINGS_SRC="$PROJECT_ROOT/settings/settings.template.json"

if [ ! -f "$SAFETY_HOOK_SRC" ]; then
  echo "[cloud-init] ERROR — source hook not found: $SAFETY_HOOK_SRC" >&2
  exit 1
fi

if [ ! -f "$SETTINGS_SRC" ]; then
  echo "[cloud-init] ERROR — source settings not found: $SETTINGS_SRC" >&2
  exit 1
fi

# ── target 경로 ───────────────────────────────────────────
HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"
SAFETY_HOOK_DST="$HOOKS_DIR/auto-build-safety.sh"
SETTINGS_DST="$PROJECT_ROOT/.claude/settings.json"

if [ "$DRYRUN" = "1" ]; then
  echo "[cloud-init] would install: $SAFETY_HOOK_SRC → $SAFETY_HOOK_DST" >&2
  echo "[cloud-init] would install: $SETTINGS_SRC → $SETTINGS_DST" >&2
  exit 0
fi

# ── 실 install (skip if exists, force option) ─────────────
FORCE="${CLOUD_INIT_FORCE:-0}"
mkdir -p "$HOOKS_DIR"

if [ -f "$SAFETY_HOOK_DST" ] && [ "$FORCE" != "1" ]; then
  echo "[cloud-init] skip — hook already exists: .claude/hooks/auto-build-safety.sh (CLOUD_INIT_FORCE=1 to overwrite)" >&2
else
  cp "$SAFETY_HOOK_SRC" "$SAFETY_HOOK_DST"
  chmod +x "$SAFETY_HOOK_DST"
  echo "[cloud-init] PreToolUse hook installed: .claude/hooks/auto-build-safety.sh" >&2
fi

# F-A12 (audit round 4): local dev 환경(setup.sh로 settings.local.json install된 머신)
# 에서 본 script 직접 실행 시 settings.json + settings.local.json hook 중복 등록
# → 모든 hook 2회 fire (F-A11). settings.local.json 에 hooks 가 이미 있으면
# settings.json 설치를 건너뛰어 중복을 회피한다. cloud session은 fresh clone
# 이라 settings.local.json 부재 → 정상 진행.
LOCAL_SETTINGS="$PROJECT_ROOT/.claude/settings.local.json"
LOCAL_HAS_HOOKS="false"
if [ -f "$LOCAL_SETTINGS" ] && command -v jq &>/dev/null; then
  LOCAL_HAS_HOOKS=$(jq 'has("hooks") and (.hooks != null) and (.hooks != {})' "$LOCAL_SETTINGS" 2>/dev/null || echo "false")
fi

if [ "$LOCAL_HAS_HOOKS" = "true" ] && [ "$FORCE" != "1" ]; then
  echo "[cloud-init] skip — local context detected (settings.local.json has hooks). settings.json bypass to avoid F-A11 duplicate fire. CLOUD_INIT_FORCE=1 to override." >&2
elif [ -f "$SETTINGS_DST" ] && [ "$FORCE" != "1" ]; then
  echo "[cloud-init] skip — settings already exists: .claude/settings.json (CLOUD_INIT_FORCE=1 to overwrite)" >&2
else
  cp "$SETTINGS_SRC" "$SETTINGS_DST"
  echo "[cloud-init] settings.json staged: .claude/settings.json" >&2
fi

exit 0
