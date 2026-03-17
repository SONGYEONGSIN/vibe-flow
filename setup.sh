#!/bin/bash
# claude-builds setup script
# 새 프로젝트에 Claude Code 설정을 적용한다
#
# 사용법:
#   cd /your/project
#   bash /path/to/claude-builds/setup.sh
#   bash /path/to/claude-builds/setup.sh --with-orchestrators

set -e

# 필수 의존 도구 확인
MISSING_DEPS=""
for dep in jq git node npx; do
  if ! command -v "$dep" &>/dev/null; then
    MISSING_DEPS="${MISSING_DEPS} $dep"
  fi
done
if [ -n "$MISSING_DEPS" ]; then
  echo "⚠ 필수 도구 미설치:${MISSING_DEPS}"
  echo "  hooks가 정상 동작하려면 위 도구들이 필요합니다."
  echo "  계속 진행합니다..."
  echo ""
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# 옵션 파싱
WITH_ORCHESTRATORS=false
for arg in "$@"; do
  case "$arg" in
    --with-orchestrators) WITH_ORCHESTRATORS=true ;;
  esac
done

if [ "$WITH_ORCHESTRATORS" = true ]; then
  TOTAL_STEPS=7
else
  TOTAL_STEPS=6
fi

echo "=== claude-builds setup ==="
echo "Project: $PROJECT_NAME"
echo "Target:  $PROJECT_DIR"
[ "$WITH_ORCHESTRATORS" = true ] && echo "Mode:    with orchestrators"
echo ""

# .claude 디렉토리 생성
mkdir -p "$PROJECT_DIR/.claude"/{agents,hooks,rules,skills,session-logs,memory,metrics}

# Agents 복사
echo "[1/$TOTAL_STEPS] Agents..."
cp "$SCRIPT_DIR/agents/"*.md "$PROJECT_DIR/.claude/agents/"

# Hooks 복사 + 실행 권한
echo "[2/$TOTAL_STEPS] Hooks..."
cp "$SCRIPT_DIR/hooks/"*.sh "$PROJECT_DIR/.claude/hooks/"
chmod +x "$PROJECT_DIR/.claude/hooks/"*.sh

# Skills 복사 (하위 디렉토리 포함)
echo "[3/$TOTAL_STEPS] Skills..."
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  mkdir -p "$PROJECT_DIR/.claude/skills/$skill_name"
  cp "$skill_dir/SKILL.md" "$PROJECT_DIR/.claude/skills/$skill_name/SKILL.md"
  # references/, scripts/, evals/ 등 하위 디렉토리 복사
  for sub_dir in "$skill_dir"*/; do
    [ -d "$sub_dir" ] || continue
    sub_name="$(basename "$sub_dir")"
    mkdir -p "$PROJECT_DIR/.claude/skills/$skill_name/$sub_name"
    cp "$sub_dir"* "$PROJECT_DIR/.claude/skills/$skill_name/$sub_name/" 2>/dev/null || true
  done
done

# Rules 복사
echo "[4/$TOTAL_STEPS] Rules..."
cp "$SCRIPT_DIR/rules/"*.md "$PROJECT_DIR/.claude/rules/"

# Settings 템플릿 복사 (기존 파일이 없을 때만)
echo "[5/$TOTAL_STEPS] Settings..."
if [ ! -f "$PROJECT_DIR/.claude/settings.local.json" ]; then
  # 훅 경로를 프로젝트 절대 경로로 치환
  ESCAPED_DIR=$(printf '%s\n' "$PROJECT_DIR" | sed 's/[&/\]/\\&/g')
  sed "s|\\.claude/hooks/|${ESCAPED_DIR}/.claude/hooks/|g" \
    "$SCRIPT_DIR/settings/settings.template.json" \
    > "$PROJECT_DIR/.claude/settings.local.json"
  echo "  Created settings.local.json (훅 경로를 절대 경로로 설정)"
  echo "  env 섹션에 프로젝트별 환경변수를 추가하세요"
else
  echo "  settings.local.json already exists, skipped"
fi

# CLAUDE.md 템플릿 복사 (기존 파일이 없을 때만)
echo "[6/$TOTAL_STEPS] CLAUDE.md + Playwright config..."
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
    "$SCRIPT_DIR/templates/CLAUDE.md.template" \
    > "$PROJECT_DIR/CLAUDE.md"
  echo "  Created CLAUDE.md ({{PROJECT_NAME}} → $PROJECT_NAME)"
  echo "  {{PROJECT_DESCRIPTION}} 플레이스홀더를 수동으로 채워주세요"
else
  echo "  CLAUDE.md already exists, skipped"
fi

# Playwright config 복사 (기존 파일이 없을 때만)
if [ ! -f "$PROJECT_DIR/playwright.config.ts" ]; then
  cp "$SCRIPT_DIR/templates/playwright.config.ts" "$PROJECT_DIR/playwright.config.ts"
  echo "  Created playwright.config.ts (HTML 리포트 활성화)"
else
  echo "  playwright.config.ts already exists, skipped"
fi

# Orchestrator 설정 (선택)
if [ "$WITH_ORCHESTRATORS" = true ]; then
  echo "[7/$TOTAL_STEPS] Orchestrators..."

  # Claude Squad config
  if command -v cs &>/dev/null; then
    mkdir -p "$HOME/.claude-squad"
    if [ ! -f "$HOME/.claude-squad/config.json" ]; then
      cp "$SCRIPT_DIR/orchestrators/claude-squad/config.template.json" \
         "$HOME/.claude-squad/config.json"
      echo "  Claude Squad: config.json 생성됨 (~/.claude-squad/)"
    else
      echo "  Claude Squad: config.json already exists, skipped"
    fi
  else
    echo "  Claude Squad: cs 명령 미발견 → brew install claude-squad"
  fi

  # Agent Orchestrator config
  if command -v ao &>/dev/null; then
    if [ ! -f "$PROJECT_DIR/agent-orchestrator.yaml" ]; then
      sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
          -e "s|{{PROJECT_PATH}}|$PROJECT_DIR|g" \
          -e "s/{{PROJECT_PREFIX}}/$(echo "$PROJECT_NAME" | cut -c1-3)/g" \
          -e "s/{{GITHUB_OWNER}}/YOUR_GITHUB_USERNAME/g" \
          "$SCRIPT_DIR/orchestrators/agent-orchestrator/agent-orchestrator.template.yaml" \
          > "$PROJECT_DIR/agent-orchestrator.yaml"
      echo "  Agent Orchestrator: agent-orchestrator.yaml 생성됨"
      echo "  {{GITHUB_OWNER}} 를 실제 GitHub 사용자명으로 수정하세요"
    else
      echo "  Agent Orchestrator: agent-orchestrator.yaml already exists, skipped"
    fi
  else
    echo "  Agent Orchestrator: ao 명령 미발견 → https://github.com/ComposioHQ/agent-orchestrator"
  fi
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "적용된 구성:"
echo "  - Agents:  $(ls "$PROJECT_DIR/.claude/agents/" | wc -l | tr -d ' ')개"
echo "  - Hooks:   $(ls "$PROJECT_DIR/.claude/hooks/" | wc -l | tr -d ' ')개"
echo "  - Skills:  $(ls "$PROJECT_DIR/.claude/skills/" | wc -l | tr -d ' ')개"
echo "  - Rules:   $(ls "$PROJECT_DIR/.claude/rules/" | wc -l | tr -d ' ')개"
echo "  - Memory:  .claude/memory/ (학습 패턴 저장)"
echo "  - Metrics: .claude/metrics/ (자동 메트릭 수집)"
[ -f "$PROJECT_DIR/playwright.config.ts" ] && echo "  - Playwright: playwright.config.ts (HTML 리포트)"
if [ "$WITH_ORCHESTRATORS" = true ]; then
  echo "  - Orchestrators:"
  [ -f "$HOME/.claude-squad/config.json" ] && echo "    - Claude Squad: ~/.claude-squad/config.json"
  [ -f "$PROJECT_DIR/agent-orchestrator.yaml" ] && echo "    - Agent Orchestrator: agent-orchestrator.yaml"
fi
echo ""
echo "다음 단계:"
echo "  1. .claude/settings.local.json 의 env 섹션에 프로젝트별 환경변수 추가"
echo "  2. CLAUDE.md 의 플레이스홀더({{...}}) 채우기"
echo "  3. 필요 시 .claude/rules/ 에 프로젝트별 규칙 추가 (예: supabase.md)"
echo "  4. deny 목록에 프로젝트별 위험 명령 추가"
echo "  5. 메트릭이 쌓이면 /metrics 로 대시보드 확인"
echo "  6. /retrospective 로 정기 회고 실행"
if [ "$WITH_ORCHESTRATORS" = true ]; then
  echo "  7. orchestrators/README.md 참고하여 오케스트레이터 설정 완료"
fi
