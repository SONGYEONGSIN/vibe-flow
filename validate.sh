#!/bin/bash
# claude-builds validate.sh — setup 후 프로젝트 .claude/ 구조 검증
#
# 사용법:
#   cd /your/project
#   bash .claude/validate.sh
#   (또는 claude-builds 레포에서 직접: bash /path/to/claude-builds/validate.sh <project-dir>)

set -u

TARGET_DIR="${1:-$(pwd)}"
CLAUDE_DIR="${TARGET_DIR}/.claude"

PASS=0
FAIL=0
WARN=0

ok()   { echo "  ✓ $1";   PASS=$((PASS+1)); }
err()  { echo "  ✗ $1";   FAIL=$((FAIL+1)); }
warn() { echo "  ⚠ $1";   WARN=$((WARN+1)); }

echo "=== claude-builds validate ==="
echo "Target: $TARGET_DIR"
echo ""

# 1. .claude 디렉토리 구조
echo "[1/5] .claude 디렉토리 구조"
[ -d "$CLAUDE_DIR" ] && ok ".claude/ 존재" || { err ".claude/ 없음 — setup.sh 실행 필요"; exit 1; }
for sub in agents hooks rules skills messages; do
  [ -d "$CLAUDE_DIR/$sub" ] && ok "$sub/ 존재" || err "$sub/ 없음"
done

# 2. 필수 의존 도구
echo ""
echo "[2/5] 필수 도구"
for cmd in jq git node npx; do
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd 설치됨 ($(command -v "$cmd"))"
  else
    err "$cmd 미설치 (훅 동작 불가)"
  fi
done

# 3. 훅 실행 권한
echo ""
echo "[3/5] 훅 실행 권한"
if [ -d "$CLAUDE_DIR/hooks" ]; then
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
echo "[4/5] agents.json 일관성"
AGENTS_JSON="$CLAUDE_DIR/agents.json"
if [ -f "$AGENTS_JSON" ]; then
  EXPECTED=$(jq -r '.agents[]' "$AGENTS_JSON" 2>/dev/null)
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
echo "[5/5] settings.local.json 훅 경로"
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
