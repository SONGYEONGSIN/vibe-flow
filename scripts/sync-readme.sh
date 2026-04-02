#!/bin/bash
# README.md + docs/architecture.html의 수치를 실제 파일 수와 자동 동기화
# 사용: bash scripts/sync-readme.sh [--with-screenshot]
#
# --with-screenshot: architecture.html → architecture.png 스크린샷도 재생성

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
README="$ROOT_DIR/README.md"
ARCH_HTML="$ROOT_DIR/docs/architecture.html"
ARCH_PNG="$ROOT_DIR/docs/architecture.png"

WITH_SCREENSHOT=false
for arg in "$@"; do
  case "$arg" in
    --with-screenshot) WITH_SCREENSHOT=true ;;
  esac
done

# 실제 파일 수 카운트
AGENT_COUNT=$(ls "$ROOT_DIR/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
HOOK_COUNT=$(ls "$ROOT_DIR/hooks/"*.sh 2>/dev/null | grep -v _common.sh | wc -l | tr -d ' ')
SKILL_COUNT=$(ls -d "$ROOT_DIR/skills/"*/ 2>/dev/null | wc -l | tr -d ' ')
RULE_COUNT=$(ls "$ROOT_DIR/rules/"*.md 2>/dev/null | wc -l | tr -d ' ')

echo "=== 실제 파일 수 ==="
echo "  Agents: ${AGENT_COUNT}개"
echo "  Hooks:  ${HOOK_COUNT}개"
echo "  Skills: ${SKILL_COUNT}개"
echo "  Rules:  ${RULE_COUNT}개"
echo ""

CHANGED=false

# ── README.md 수치 업데이트 ──
if [ -f "$README" ]; then
  # 텍스트 다이어그램 내 수치
  sed -i '' "s/Rules ([0-9]*개)/Rules (${RULE_COUNT}개)/g" "$README"
  sed -i '' "s/Hooks Pipeline ([0-9]*개)/Hooks Pipeline (${HOOK_COUNT}개)/g" "$README"
  sed -i '' "s/Skills ([0-9]*개)/Skills (${SKILL_COUNT}개)/g" "$README"
  sed -i '' "s/Agents ([0-9]*개)/Agents (${AGENT_COUNT}개)/g" "$README"

  # 구성 요소 헤딩
  sed -i '' "s/### Agents ([0-9]*개)/### Agents (${AGENT_COUNT}개)/g" "$README"
  sed -i '' "s/### Skills ([0-9]*개)/### Skills (${SKILL_COUNT}개)/g" "$README"
  sed -i '' "s/### Hooks ([0-9]*개)/### Hooks (${HOOK_COUNT}개)/g" "$README"

  # 디렉토리 구조 주석
  sed -i '' "s/# [0-9]*개 전문 에이전트/# ${AGENT_COUNT}개 전문 에이전트/g" "$README"
  sed -i '' "s/# [0-9]*개 자동화 훅/# ${HOOK_COUNT}개 자동화 훅/g" "$README"
  sed -i '' "s/# [0-9]*개 CLI 스킬/# ${SKILL_COUNT}개 CLI 스킬/g" "$README"
  sed -i '' "s/# [0-9]*개 공통 규칙/# ${RULE_COUNT}개 공통 규칙/g" "$README"

  echo "✓ README.md 수치 업데이트"
  CHANGED=true
fi

# ── architecture.html 수치 업데이트 ──
if [ -f "$ARCH_HTML" ]; then
  # Rules (N) — span 태그 안의 숫자
  sed -i '' "s/Rules <span[^>]*>([0-9]*)/Rules <span style=\"color:#00d4aa;font-size:24.0px;\">(${RULE_COUNT}/g" "$ARCH_HTML"

  # Skills (N), Hooks Pipeline (N), Agents (N) — span 태그 안
  sed -i '' "s/>Skills <span style=\"color:#00d4aa;\">([0-9]*)/>Skills <span style=\"color:#00d4aa;\">(${SKILL_COUNT})/g" "$ARCH_HTML"
  sed -i '' "s/>Hooks Pipeline <span style=\"color:#00d4aa;\">([0-9]*)/>Hooks Pipeline <span style=\"color:#00d4aa;\">(${HOOK_COUNT})/g" "$ARCH_HTML"
  sed -i '' "s/>Agents <span style=\"color:#00d4aa;\">([0-9]*)/>Agents <span style=\"color:#00d4aa;\">(${AGENT_COUNT})/g" "$ARCH_HTML"

  echo "✓ architecture.html 수치 업데이트"
  CHANGED=true
fi

# ── architecture.png 스크린샷 재생성 ──
if [ "$WITH_SCREENSHOT" = true ] && [ -f "$ARCH_HTML" ]; then
  if command -v npx &>/dev/null; then
    echo ""
    echo "스크린샷 재생성 중..."
    npx playwright screenshot --full-page --viewport-size="4000,800" \
      "file://${ARCH_HTML}" "${ARCH_PNG}" 2>/dev/null
    echo "✓ architecture.png 재생성 완료"
    CHANGED=true
  else
    echo "⚠ npx 없음 — 스크린샷 건너뜀"
  fi
fi

echo ""
if [ "$CHANGED" = true ]; then
  echo "=== 동기화 완료 ==="
  echo "변경사항 확인: git diff"
else
  echo "=== 변경 없음 ==="
fi
