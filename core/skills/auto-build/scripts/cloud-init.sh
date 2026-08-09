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
EVOLUTION_HOOK_SRC="$PROJECT_ROOT/core/hooks/evolution-guard.sh"
SETTINGS_SRC="$PROJECT_ROOT/settings/settings.template.json"

if [ ! -f "$SAFETY_HOOK_SRC" ]; then
  echo "[cloud-init] ERROR — source hook not found: $SAFETY_HOOK_SRC" >&2
  exit 1
fi

if [ ! -f "$EVOLUTION_HOOK_SRC" ]; then
  echo "[cloud-init] ERROR — source hook not found: $EVOLUTION_HOOK_SRC" >&2
  exit 1
fi

# F-P03: 폐루프 관찰성 telemetry hook — settings.json 이 참조하나 미배포면
# skill_invoked/tool 계측이 death → Phase 2 AUDIT 의 telemetry evaluate 입력 소실.
TELEMETRY_HOOKS="skill-tracker tool-invocation-tracker"
for _h in $TELEMETRY_HOOKS; do
  [ -f "$PROJECT_ROOT/core/hooks/$_h.sh" ] || {
    echo "[cloud-init] ERROR — source hook not found: $PROJECT_ROOT/core/hooks/$_h.sh" >&2
    exit 1
  }
done

if [ ! -f "$SETTINGS_SRC" ]; then
  echo "[cloud-init] ERROR — source settings not found: $SETTINGS_SRC" >&2
  exit 1
fi

# ── target 경로 ───────────────────────────────────────────
HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"
SAFETY_HOOK_DST="$HOOKS_DIR/auto-build-safety.sh"
EVOLUTION_HOOK_DST="$HOOKS_DIR/evolution-guard.sh"
SETTINGS_DST="$PROJECT_ROOT/.claude/settings.json"

if [ "$DRYRUN" = "1" ]; then
  echo "[cloud-init] would install: $SAFETY_HOOK_SRC → $SAFETY_HOOK_DST" >&2
  echo "[cloud-init] would install: $EVOLUTION_HOOK_SRC → $EVOLUTION_HOOK_DST" >&2
  for _h in $TELEMETRY_HOOKS; do
    echo "[cloud-init] would install: $PROJECT_ROOT/core/hooks/$_h.sh → $HOOKS_DIR/$_h.sh" >&2
  done
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

# 안전코어 guard (PR-1): 자율 모드에서 denylist(.claude/evolution-protected) 수정 차단
if [ -f "$EVOLUTION_HOOK_DST" ] && [ "$FORCE" != "1" ]; then
  echo "[cloud-init] skip — hook already exists: .claude/hooks/evolution-guard.sh (CLOUD_INIT_FORCE=1 to overwrite)" >&2
else
  cp "$EVOLUTION_HOOK_SRC" "$EVOLUTION_HOOK_DST"
  chmod +x "$EVOLUTION_HOOK_DST"
  echo "[cloud-init] PreToolUse hook installed: .claude/hooks/evolution-guard.sh" >&2
fi

# F-P03: 폐루프 관찰성 telemetry hook 배포 (skill-tracker / tool-invocation-tracker)
for _h in $TELEMETRY_HOOKS; do
  _dst="$HOOKS_DIR/$_h.sh"
  if [ -f "$_dst" ] && [ "$FORCE" != "1" ]; then
    echo "[cloud-init] skip — hook already exists: .claude/hooks/$_h.sh (CLOUD_INIT_FORCE=1 to overwrite)" >&2
  else
    cp "$PROJECT_ROOT/core/hooks/$_h.sh" "$_dst"
    chmod +x "$_dst"
    echo "[cloud-init] telemetry hook installed: .claude/hooks/$_h.sh" >&2
  fi
done

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
  # F-R01 (audit R17, P0): 프롬프트의 `export AUTO_BUILD_MODE=1` 은 Bash 도구 자식 셸에만
  # 살아 hook 프로세스(Claude Code 가 spawn)에 도달할 수 없다 — 그래서 evolution-guard 와
  # auto-build-safety 가 자율 세션에서 첫 줄 exit 0 으로 죽어 있었다(T4~T7 이 그 미검증
  # 가정 위에 축적됨). settings.json 의 .env 가 hook 에 전파되는 유일한 통로다.
  # 병합(치환 아님)이라 템플릿의 기존 env 키와 hooks wiring 은 보존된다.
  if command -v jq &>/dev/null; then
    jq '.env.AUTO_BUILD_MODE = "1"' "$SETTINGS_SRC" > "$SETTINGS_DST"
    echo "[cloud-init] settings.json staged + AUTO_BUILD_MODE=1 (안전 hook 활성): .claude/settings.json" >&2
  else
    # jq 부재는 cloud 환경에서 발생한 적 없으나, 조용히 가드 없는 설정을 깔지는 않는다.
    cp "$SETTINGS_SRC" "$SETTINGS_DST"
    echo "[cloud-init] WARN — jq 부재로 AUTO_BUILD_MODE 미주입. evolution-guard/auto-build-safety 가 비활성 상태로 남는다(F-R01)." >&2
  fi
fi

exit 0
