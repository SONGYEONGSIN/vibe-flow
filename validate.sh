#!/bin/bash
# vibe-flow validate.sh — setup 후 프로젝트 .claude/ 구조 검증
#
# 사용법:
#   cd /your/project
#   bash .claude/validate.sh
#   (또는 vibe-flow 레포에서 직접: bash /path/to/vibe-flow/validate.sh <project-dir>)

set -u

TARGET_DIR="${1:-$(pwd)}"
CLAUDE_DIR="${TARGET_DIR}/.claude"

PASS=0
FAIL=0
WARN=0

ok()   { echo "  ✓ $1";   PASS=$((PASS+1)); }
err()  { echo "  ✗ $1";   FAIL=$((FAIL+1)); }
warn() { echo "  ⚠ $1";   WARN=$((WARN+1)); }

echo "=== vibe-flow validate ==="
echo "Target: $TARGET_DIR"
echo ""

# 1. .claude 디렉토리 구조
echo "[1/10] .claude 디렉토리 구조"
[ -d "$CLAUDE_DIR" ] && ok ".claude/ 존재" || { err ".claude/ 없음 — setup.sh 실행 필요"; exit 1; }
for sub in agents hooks rules skills messages scripts plans memory; do
  [ -d "$CLAUDE_DIR/$sub" ] && ok "$sub/ 존재" || err "$sub/ 없음"
done
# 새 워크플로우 디렉토리 (brainstorm/receive-review가 사용)
for sub in memory/brainstorms memory/reviews; do
  [ -d "$CLAUDE_DIR/$sub" ] && ok "$sub/ 존재" || warn "$sub/ 없음 — 첫 사용 시 자동 생성됨"
done
# state 파일 존재 확인
if [ -f "$CLAUDE_DIR/.vibe-flow.json" ]; then
  ok ".vibe-flow.json 존재"
else
  warn ".vibe-flow.json 없음 — 평면 .claude/ 출신이거나 초기 설치 미완료"
fi
# Instinct store 확인 (선택적)
if [ -f "$CLAUDE_DIR/scripts/store.js" ]; then
  if [ -d "$CLAUDE_DIR/scripts/node_modules/better-sqlite3" ]; then
    ok "scripts/store.js + better-sqlite3 설치됨 (SQLite 메트릭 활성)"
  else
    warn "scripts/store.js 있으나 better-sqlite3 미설치 — JSON 폴백 모드"
  fi
fi

# 2. 필수 의존 도구
echo ""
echo "[2/10] 필수 도구"
for cmd in jq git node npx; do
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd 설치됨 ($(command -v "$cmd"))"
  else
    err "$cmd 미설치 (훅 동작 불가)"
  fi
done

# 3. State file 무결성
echo ""
echo "[3/10] State file (.vibe-flow.json)"
STATE="$CLAUDE_DIR/.vibe-flow.json"
if [ -f "$STATE" ]; then
  if jq empty "$STATE" 2>/dev/null; then
    ok ".vibe-flow.json 유효 JSON"

    SCHEMA_FAIL=0
    for field in vibe_flow_version installed_at extensions; do
      if ! jq -e --arg f "$field" 'has($f)' "$STATE" >/dev/null 2>&1; then
        err "필수 필드 누락: $field"
        SCHEMA_FAIL=$((SCHEMA_FAIL+1))
      fi
    done
    [ "$SCHEMA_FAIL" = 0 ] && ok "필수 필드 (vibe_flow_version, installed_at, extensions) 존재"

    EXT_FAIL=0
    while IFS= read -r line; do
      ext=$(echo "$line" | cut -d'|' -f1)
      file=$(echo "$line" | cut -d'|' -f2)
      full="$TARGET_DIR/$file"
      if [ ! -e "$full" ]; then
        err "ext '$ext' 파일 누락: $file"
        EXT_FAIL=$((EXT_FAIL+1))
      fi
    done < <(jq -r '.extensions | to_entries[] | .key as $k | .value.files[] | "\($k)|\(.)"' "$STATE" 2>/dev/null)
    [ "$EXT_FAIL" = 0 ] && ok "모든 extension 파일 존재"

    EXT_COUNT=$(jq '.extensions | length' "$STATE")
    ok "설치된 extensions: ${EXT_COUNT}개"
  else
    err ".vibe-flow.json JSON 파싱 실패"
  fi
else
  warn ".vibe-flow.json 없음 — 마이그레이션 또는 첫 setup 필요"
fi

# 4. 훅 파일 존재 + 실행 권한
echo ""
echo "[4/10] 훅 파일 검증"
if [ -d "$CLAUDE_DIR/hooks" ]; then
  # 필수 훅 파일 목록
  # F-B8 (audit round 2): 누락 6개 hook 추가 — auto-build-safety, budget-warn,
  # security-lint, session-memory-sync, skill-tracker, tool-invocation-tracker
  REQUIRED_HOOKS="_common command-guard smart-guard prettier-format eslint-fix typecheck test-runner metrics-collector pattern-check design-lint debate-trigger message-bus readme-sync session-log session-review uncommitted-warn tool-failure-handler notify pre-compact tdd-enforce context-prune model-suggest auto-build-safety budget-warn security-lint session-memory-sync skill-tracker tool-invocation-tracker"
  HOOK_MISSING=0
  for hook in $REQUIRED_HOOKS; do
    if [ ! -f "$CLAUDE_DIR/hooks/${hook}.sh" ]; then
      err "${hook}.sh 누락"
      HOOK_MISSING=$((HOOK_MISSING+1))
    fi
  done
  [ "$HOOK_MISSING" = 0 ] && ok "필수 훅 $(echo "$REQUIRED_HOOKS" | wc -w | tr -d ' ')개 모두 존재"

  # 실행 권한 확인
  NON_EXEC=0
  for hook in "$CLAUDE_DIR/hooks/"*.sh; do
    [ -f "$hook" ] || continue
    if [ ! -x "$hook" ]; then
      warn "$(basename "$hook") 실행 권한 없음 (chmod +x 필요)"
      NON_EXEC=$((NON_EXEC+1))
    fi
  done
  [ "$NON_EXEC" = 0 ] && ok "모든 훅 실행 가능"
fi

# F-C1 (audit round 3): core/ ↔ .claude/ sync drift 검증
# PR이 core/ 만 수정하고 .claude/ 미 update할 때 runtime에 적용 안 됨
echo ""
echo "[4.5/10] core/ ↔ .claude/ sync drift 검증 (F-C1)"
# F-F1 (audit round 6): dirname "$0" 는 `bash .claude/validate.sh` 실행 시 ".claude" 를
# 반환해 core/ 경로가 ".claude/core/" 로 잘못 잡혀 drift 블록 전체가 silent skip 됨.
# git repo root 로 해석 (cycles-report.sh / sync-drift.sh 와 동일 idiom).
VIBE_FLOW_ROOT="${VIBE_FLOW_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
if [ -d "$VIBE_FLOW_ROOT/core/agents" ] && [ -d "$CLAUDE_DIR/agents" ]; then
  DRIFT_COUNT=0
  for src in "$VIBE_FLOW_ROOT/core/agents/"*.md; do
    [ -f "$src" ] || continue
    name=$(basename "$src")
    dst="$CLAUDE_DIR/agents/$name"
    if [ ! -f "$dst" ]; then
      warn "agent missing in .claude/: $name"
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      warn "agent drift: $name (core 와 .claude 불일치)"
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
    fi
  done
  # F-G03 (audit R7): agents.json (message-bus 레지스트리) 도 drift 검증 — *.md 루프 밖 파일
  if [ -f "$VIBE_FLOW_ROOT/core/agents.json" ]; then
    if [ ! -f "$CLAUDE_DIR/agents.json" ]; then
      warn "agents.json missing in .claude/"
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
    elif ! diff -q "$VIBE_FLOW_ROOT/core/agents.json" "$CLAUDE_DIR/agents.json" >/dev/null 2>&1; then
      warn "agents.json drift (core 와 .claude 불일치)"
      DRIFT_COUNT=$((DRIFT_COUNT + 1))
    fi
  fi
  [ "$DRIFT_COUNT" = 0 ] && ok "core/agents ↔ .claude/agents 동기화"
fi

if [ -d "$VIBE_FLOW_ROOT/core/skills" ] && [ -d "$CLAUDE_DIR/skills" ]; then
  SKILL_DRIFT=0
  for src in "$VIBE_FLOW_ROOT/core/skills"/*/SKILL.md; do
    [ -f "$src" ] || continue
    skill=$(basename "$(dirname "$src")")
    dst="$CLAUDE_DIR/skills/$skill/SKILL.md"
    if [ ! -f "$dst" ]; then
      warn "skill missing in .claude/: $skill/SKILL.md"
      SKILL_DRIFT=$((SKILL_DRIFT + 1))
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      warn "skill drift: $skill/SKILL.md (core 와 .claude 불일치)"
      SKILL_DRIFT=$((SKILL_DRIFT + 1))
    fi
  done
  [ "$SKILL_DRIFT" = 0 ] && ok "core/skills ↔ .claude/skills SKILL.md 동기화"
fi

# F-D1-R4-1 (audit round 4): rules/ 디렉토리도 동일 sync 검증
# runtime이 .claude/rules/ 를 읽으므로 core/rules/ 만 수정하면 룰 자체가 적용 안 됨
if [ -d "$VIBE_FLOW_ROOT/core/rules" ] && [ -d "$CLAUDE_DIR/rules" ]; then
  RULES_DRIFT=0
  for src in "$VIBE_FLOW_ROOT/core/rules/"*.md; do
    [ -f "$src" ] || continue
    name=$(basename "$src")
    dst="$CLAUDE_DIR/rules/$name"
    if [ ! -f "$dst" ]; then
      warn "rule missing in .claude/: $name"
      RULES_DRIFT=$((RULES_DRIFT + 1))
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      warn "rule drift: $name (core 와 .claude 불일치)"
      RULES_DRIFT=$((RULES_DRIFT + 1))
    fi
  done
  [ "$RULES_DRIFT" = 0 ] && ok "core/rules ↔ .claude/rules 동기화"
fi

# F-D1-R4-2 (audit round 4): skills 내부 scripts + hooks 도 sync 검증
# SKILL.md 만으로는 부족 — runtime이 실제 호출하는 .sh 가 drift 시 silent 버그
if [ -d "$VIBE_FLOW_ROOT/core/skills" ] && [ -d "$CLAUDE_DIR/skills" ]; then
  SCRIPT_DRIFT=0
  while IFS= read -r src; do
    [ -f "$src" ] || continue
    rel="${src#$VIBE_FLOW_ROOT/core/}"
    dst="$CLAUDE_DIR/$rel"
    if [ ! -f "$dst" ]; then
      warn "skill-script missing in .claude/: $rel"
      SCRIPT_DRIFT=$((SCRIPT_DRIFT + 1))
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      warn "skill-script drift: $rel (core 와 .claude 불일치)"
      SCRIPT_DRIFT=$((SCRIPT_DRIFT + 1))
    fi
  done < <(find "$VIBE_FLOW_ROOT/core/skills" -name '*.sh' -type f 2>/dev/null)
  [ "$SCRIPT_DRIFT" = 0 ] && ok "core/skills/*/scripts ↔ .claude/skills/*/scripts 동기화"
fi

# F-E2 (audit round 5): skill 디렉토리 내 비-SKILL.md 문서 sync 검증.
# orchestrator.md / references/*.md / data/*.md / assets/*.md / jurisdictions/*.md 등
# runtime 이 참조하는 모든 markdown. SKILL.md 만 보면 F-E1 같은 drift 미탐지.
if [ -d "$VIBE_FLOW_ROOT/core/skills" ] && [ -d "$CLAUDE_DIR/skills" ]; then
  DOC_DRIFT=0
  while IFS= read -r src; do
    [ -f "$src" ] || continue
    rel="${src#$VIBE_FLOW_ROOT/core/}"
    dst="$CLAUDE_DIR/$rel"
    if [ ! -f "$dst" ]; then
      warn "skill-doc missing in .claude/: $rel"
      DOC_DRIFT=$((DOC_DRIFT + 1))
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      warn "skill-doc drift: $rel (core 와 .claude 불일치)"
      DOC_DRIFT=$((DOC_DRIFT + 1))
    fi
  done < <(find "$VIBE_FLOW_ROOT/core/skills" -name '*.md' ! -name 'SKILL.md' -type f 2>/dev/null)
  [ "$DOC_DRIFT" = 0 ] && ok "core/skills/*/*.md (non-SKILL) ↔ .claude/ 동기화"
fi

# F-D8 (audit round 5): hook drift loop missing 케이스 비대칭 fix.
# 기존 loop 는 `[ -f "$dst" ]` 조건이라 dst 부재 시 silent skip — script loop 와 비대칭.
# git-post-commit.sh 처럼 .git/hooks 로 install 되는 hook 은 명시 skip 리스트로 처리.
if [ -d "$VIBE_FLOW_ROOT/core/hooks" ] && [ -d "$CLAUDE_DIR/hooks" ]; then
  HOOK_DRIFT=0
  # .claude/hooks/ 에 install 되지 않는 hook (다른 target 으로 install)
  HOOK_SKIP_LIST=" git-post-commit.sh "
  for src in "$VIBE_FLOW_ROOT/core/hooks/"*.sh; do
    [ -f "$src" ] || continue
    name=$(basename "$src")
    # .git/hooks 등 다른 target 으로 install 되는 hook 은 skip
    case "$HOOK_SKIP_LIST" in
      *" $name "*) continue ;;
    esac
    dst="$CLAUDE_DIR/hooks/$name"
    if [ ! -f "$dst" ]; then
      warn "hook missing in .claude/: $name"
      HOOK_DRIFT=$((HOOK_DRIFT + 1))
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      warn "hook drift: $name (core 와 .claude 불일치)"
      HOOK_DRIFT=$((HOOK_DRIFT + 1))
    fi
  done
  [ "$HOOK_DRIFT" = 0 ] && ok "core/hooks ↔ .claude/hooks 동기화"
fi

[ "${DRIFT_COUNT:-0}" -gt 0 ] || [ "${SKILL_DRIFT:-0}" -gt 0 ] || \
[ "${RULES_DRIFT:-0}" -gt 0 ] || [ "${SCRIPT_DRIFT:-0}" -gt 0 ] || \
[ "${HOOK_DRIFT:-0}" -gt 0 ] && \
  warn "drift 발견 — bash core/scripts/sync-drift.sh (--check 사전 확인) 또는 setup.sh --upgrade" || true

# 4. agents.json 일관성
echo ""
echo "[5/10] agents.json 일관성"
AGENTS_JSON="$CLAUDE_DIR/agents.json"
if [ -f "$AGENTS_JSON" ]; then
  EXPECTED=$(jq -r '.agents[]' "$AGENTS_JSON" 2>/dev/null | tr -d '\r')
  if [ -z "$EXPECTED" ]; then
    err "agents.json 파싱 실패"
  else
    MISSING=""
    for agent in $EXPECTED; do
      [ -f "$CLAUDE_DIR/agents/${agent}.md" ] || MISSING="${MISSING} ${agent}"
    done
    if [ -z "$MISSING" ]; then
      ok "$(echo "$EXPECTED" | wc -l | tr -d ' ')개 에이전트 파일 모두 존재"
    else
      err "agents.json에 있으나 파일 없음:${MISSING}"
    fi
  fi
else
  warn "agents.json 없음 (하위 호환 모드로 동작)"
fi

# 5. settings.local.json 훅 경로 + JSON 유효성
echo ""
echo "[6/10] settings.local.json 훅 경로 + JSON 유효성"
SETTINGS="$CLAUDE_DIR/settings.local.json"
SETTINGS_MAIN="$CLAUDE_DIR/settings.json"

# F-A11 (audit round 4): settings.json + settings.local.json hook 중복 등록 탐지
# Claude Code는 두 파일의 hooks를 merge 하므로 동일 hook이 양 파일에 있으면 2회 fire
if [ -f "$SETTINGS_MAIN" ] && [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  MAIN_HAS_HOOKS=$(jq 'has("hooks") and (.hooks != null) and (.hooks != {})' "$SETTINGS_MAIN" 2>/dev/null)
  LOCAL_HAS_HOOKS=$(jq 'has("hooks") and (.hooks != null) and (.hooks != {})' "$SETTINGS" 2>/dev/null)
  if [ "$MAIN_HAS_HOOKS" = "true" ] && [ "$LOCAL_HAS_HOOKS" = "true" ]; then
    warn "F-A11: settings.json + settings.local.json 양쪽에 hooks 등록 — 동일 hook 2회 fire"
    warn "  → settings.local.json의 hooks 블록 제거 권장 (settings.json이 canonical)"
  else
    ok "settings.json/settings.local.json hook 중복 없음 (F-A11)"
  fi
fi

if [ -f "$SETTINGS" ]; then
  if grep -q "\"command\".*\.claude/hooks/" "$SETTINGS" 2>/dev/null; then
    if grep -q "\"command\".*${TARGET_DIR}/.claude/hooks/" "$SETTINGS" 2>/dev/null; then
      ok "훅 경로가 절대 경로로 설정됨"
    else
      warn "훅 경로가 상대 경로 — Claude Code가 인식 못할 수 있음"
    fi
  else
    ok "settings.local.json에 훅 설정 없음 (F-A11 fix: settings.json이 canonical)"
  fi

  # JSON 유효성 + hook 경로 실행 가능성 (이전 stage 8 → 통합)
  if command -v jq &>/dev/null; then
    if jq empty "$SETTINGS" 2>/dev/null; then
      ok "settings.local.json 유효한 JSON"
      BROKEN_PATHS=0
      for cmd in $(jq -r '.. | .command? // empty' "$SETTINGS" 2>/dev/null); do
        case "$cmd" in
          */hooks/*.sh)
            [ -x "$cmd" ] || { err "hook 경로 무효: $cmd"; BROKEN_PATHS=$((BROKEN_PATHS+1)); }
            ;;
        esac
      done
      [ "$BROKEN_PATHS" = 0 ] && ok "settings.local.json의 모든 hook 경로 실행 가능"
    else
      err "settings.local.json JSON 파싱 실패"
    fi
  fi
else
  warn "settings.local.json 없음"
fi

# 6. 훅 bash 구문 검증
echo ""
echo "[7/10] 훅 bash 구문 검증"
if [ -d "$CLAUDE_DIR/hooks" ]; then
  SYNTAX_FAIL=0
  for hook in "$CLAUDE_DIR/hooks/"*.sh; do
    [ -f "$hook" ] || continue
    if ! bash -n "$hook" 2>/dev/null; then
      err "$(basename "$hook") bash 구문 에러"
      SYNTAX_FAIL=$((SYNTAX_FAIL+1))
    fi
  done
  [ "$SYNTAX_FAIL" = 0 ] && ok "모든 훅 bash 구문 정상"
fi

# 7. agent / rule / skill frontmatter
echo ""
echo "[8/10] frontmatter 검증"
FRONTMATTER_FAIL=0

# Agents: name + description + model 필수
if [ -d "$CLAUDE_DIR/agents" ]; then
  for f in "$CLAUDE_DIR/agents/"*.md; do
    [ -f "$f" ] || continue
    head -10 "$f" | grep -q "^name:" || { err "$(basename "$f"): name 누락"; FRONTMATTER_FAIL=$((FRONTMATTER_FAIL+1)); }
    head -10 "$f" | grep -q "^description:" || { err "$(basename "$f"): description 누락"; FRONTMATTER_FAIL=$((FRONTMATTER_FAIL+1)); }
    head -10 "$f" | grep -q "^model:" || { err "$(basename "$f"): model 누락"; FRONTMATTER_FAIL=$((FRONTMATTER_FAIL+1)); }
  done
fi

# Skills: 디렉토리당 SKILL.md 존재 + name/description 필수
if [ -d "$CLAUDE_DIR/skills" ]; then
  for skill_dir in "$CLAUDE_DIR/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    if [ ! -f "$skill_dir/SKILL.md" ]; then
      err "skills/$skill_name/SKILL.md 누락"
      FRONTMATTER_FAIL=$((FRONTMATTER_FAIL+1))
      continue
    fi
    head -10 "$skill_dir/SKILL.md" | grep -q "^name:" || { err "skills/$skill_name/SKILL.md: name 누락"; FRONTMATTER_FAIL=$((FRONTMATTER_FAIL+1)); }
    head -10 "$skill_dir/SKILL.md" | grep -q "^description:" || { err "skills/$skill_name/SKILL.md: description 누락"; FRONTMATTER_FAIL=$((FRONTMATTER_FAIL+1)); }
  done
fi

[ "$FRONTMATTER_FAIL" = 0 ] && ok "agent/skill frontmatter 정상"

# 9. State ↔ Filesystem reconciliation
echo ""
echo "[9/10] State ↔ Filesystem reconciliation"
if [ -f "$STATE" ]; then
  ok "state 명시 파일 존재 (stage 3 결과)"

  # orphan 검출 — extension 시그니처 디렉토리가 .claude/skills/에 있는데 state에는 없음
  CORE_SKILLS="brainstorm plan finish release scaffold test worktree verify security commit review-pr receive-review status learn audit"
  EXT_SIGNATURES="eval-skill evolve design-sync design-audit pair discuss metrics retrospective feedback"

  ORPHAN_COUNT=0
  for skill_dir in "$CLAUDE_DIR/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill="$(basename "$skill_dir")"

    # Core skill?
    if echo "$CORE_SKILLS" | grep -qw "$skill"; then continue; fi

    # state.extensions에 매칭?
    if jq -r '.extensions | to_entries[] | .value.files[]' "$STATE" 2>/dev/null \
        | grep -q "skills/$skill/"; then
      continue
    fi

    # Orphan — Extension signature 일치하는데 state에 없음
    if echo "$EXT_SIGNATURES" | grep -qw "$skill"; then
      warn "orphan ext skill: $skill (state에 없음)"
      ORPHAN_COUNT=$((ORPHAN_COUNT+1))
    fi
  done
  [ "$ORPHAN_COUNT" = 0 ] && ok "orphan 파일 없음"
else
  warn "state 없음 — reconciliation 건너뜀"
fi

# 9. design-tokens.ts 검증 (선택적 — 파일이 있을 때만)
echo ""
echo "[10/10] design-tokens.ts 검증 (선택)"
TOKENS_FILE=""
for cand in "$TARGET_DIR/src/lib/design-tokens.ts" "$TARGET_DIR/src/lib/design-tokens.tsx" "$TARGET_DIR/lib/design-tokens.ts"; do
  [ -f "$cand" ] && TOKENS_FILE="$cand" && break
done
if [ -z "$TOKENS_FILE" ]; then
  warn "design-tokens.ts 없음 (rules/design.md 권장 위치: src/lib/design-tokens.ts)"
else
  TOKEN_FAIL=0
  # as const 강제 (타입 안전)
  grep -q "as const" "$TOKENS_FILE" || { err "design-tokens.ts: 'as const' 미사용 (타입 안전성 손실)"; TOKEN_FAIL=$((TOKEN_FAIL+1)); }
  # export 최소 1개
  grep -q "^export " "$TOKENS_FILE" || { err "design-tokens.ts: export 없음"; TOKEN_FAIL=$((TOKEN_FAIL+1)); }
  # colors 객체 존재
  grep -qE "(^| )colors\s*[=:]" "$TOKENS_FILE" || warn "design-tokens.ts: colors 객체 미정의"
  [ "$TOKEN_FAIL" = 0 ] && ok "design-tokens.ts 구조 정상 ($(basename "$TOKENS_FILE"))"
fi

# Extension dependencies (state에 design-system 있으면 playwright 등 검증)
if [ -f "$STATE" ] && jq -e '.extensions["design-system"]' "$STATE" >/dev/null 2>&1; then
  echo ""
  echo "  design-system 의존성:"
  for dep in playwright sharp pixelmatch pngjs; do
    if (cd "$TARGET_DIR" && node -e "require('$dep')" 2>/dev/null); then
      ok "  $dep 설치됨"
    else
      warn "  $dep 미설치 (npm i -D $dep)"
    fi
  done
fi

# 결과 요약
echo ""
echo "=== 결과 ==="
echo "  통과: $PASS / 경고: $WARN / 실패: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ 실패 항목이 있습니다. setup.sh 재실행 또는 수동 수정이 필요합니다."
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo ""
  echo "⚠ 경고가 있으나 동작에는 지장 없습니다."
  exit 0
else
  echo ""
  echo "✅ 모든 검증 통과"
  exit 0
fi
