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

# 3. 훅 파일 존재 + 실행 권한
echo ""
echo "[3/10] 훅 파일 검증"
if [ -d "$CLAUDE_DIR/hooks" ]; then
  # 필수 훅 파일 목록
  REQUIRED_HOOKS="_common command-guard smart-guard prettier-format eslint-fix typecheck test-runner metrics-collector pattern-check design-lint debate-trigger message-bus readme-sync session-log session-review uncommitted-warn tool-failure-handler notify pre-compact tdd-enforce context-prune model-suggest"
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

# 4. agents.json 일관성
echo ""
echo "[4/10] agents.json 일관성"
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

# 5. settings.local.json 훅 경로
echo ""
echo "[5/10] settings.local.json 훅 경로"
SETTINGS="$CLAUDE_DIR/settings.local.json"
if [ -f "$SETTINGS" ]; then
  if grep -q "\"command\".*\.claude/hooks/" "$SETTINGS" 2>/dev/null; then
    if grep -q "\"command\".*${TARGET_DIR}/.claude/hooks/" "$SETTINGS" 2>/dev/null; then
      ok "훅 경로가 절대 경로로 설정됨"
    else
      warn "훅 경로가 상대 경로 — Claude Code가 인식 못할 수 있음"
    fi
  else
    warn "settings.local.json에 훅 설정 없음"
  fi
else
  warn "settings.local.json 없음"
fi

# 6. 훅 bash 구문 검증
echo ""
echo "[6/10] 훅 bash 구문 검증"
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
echo "[7/10] frontmatter 검증"
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

# 8. settings.local.json JSON 유효성
echo ""
echo "[8/10] settings.local.json JSON 유효성"
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  if jq empty "$SETTINGS" 2>/dev/null; then
    ok "settings.local.json 유효한 JSON"
    # hook 경로가 실제 존재하는지
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

# 9. design-tokens.ts 검증 (선택적 — 파일이 있을 때만)
echo ""
echo "[9/10] design-tokens.ts 검증 (선택)"
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
