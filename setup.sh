#!/bin/bash
# vibe-flow setup script
# 새 프로젝트에 Claude Code 설정을 적용한다
#
# 사용법:
#   cd /your/project
#   bash /path/to/vibe-flow/setup.sh
#   bash /path/to/vibe-flow/setup.sh --with-orchestrators

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

# design-sync 선택적 의존성 확인
OPTIONAL_MISSING=""
for dep in playwright sharp pixelmatch; do
  if ! node -e "require('$dep')" 2>/dev/null; then
    OPTIONAL_MISSING="${OPTIONAL_MISSING} $dep"
  fi
done
if [ -n "$OPTIONAL_MISSING" ]; then
  echo "ℹ design-sync 선택적 의존성 미설치:${OPTIONAL_MISSING}"
  echo "  /design-sync 스킬 사용 시 필요합니다: npm i -D${OPTIONAL_MISSING}"
  echo ""
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# 경로 안전성 검증 — 개행/탭 등 sed 치환을 깨뜨리는 문자 차단
case "$PROJECT_DIR" in
  *$'\n'*|*$'\t'*)
    echo "ERROR: PROJECT_DIR contains whitespace control characters: $PROJECT_DIR" >&2
    echo "  setup.sh의 sed 기반 경로 치환이 깨질 수 있습니다." >&2
    exit 1
    ;;
esac

# 옵션 파싱
WITH_ORCHESTRATORS=false
FORCE=false
for arg in "$@"; do
  case "$arg" in
    --with-orchestrators) WITH_ORCHESTRATORS=true ;;
    --force) FORCE=true ;;
  esac
done

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# 사용자 수정본 보존: 대상 파일이 소스와 다르면 .bak.<timestamp>로 백업 후 덮어씀
# --force: 백업 없이 그냥 덮어씀 (CI 등 깨끗한 업데이트 시 사용)
safe_copy() {
  local src="$1" dst="$2"
  if [ -f "$dst" ] && [ "$FORCE" != true ] && ! cmp -s "$src" "$dst"; then
    cp "$dst" "${dst}.bak.${TIMESTAMP}"
    echo "  ↻ backup: ${dst#$PROJECT_DIR/}.bak.${TIMESTAMP}"
  fi
  cp "$src" "$dst"
}

if [ "$WITH_ORCHESTRATORS" = true ]; then
  TOTAL_STEPS=8
else
  TOTAL_STEPS=7
fi

echo "=== vibe-flow setup ==="
echo "Project: $PROJECT_NAME"
echo "Target:  $PROJECT_DIR"
[ "$WITH_ORCHESTRATORS" = true ] && echo "Mode:    with orchestrators"
echo ""

# .claude 디렉토리 생성
mkdir -p "$PROJECT_DIR/.claude"/{agents,hooks,rules,skills,session-logs,memory,metrics,plans}
mkdir -p "$PROJECT_DIR/.claude/memory/brainstorms"
mkdir -p "$PROJECT_DIR/.claude/memory/reviews"

# 빈 디렉토리도 git에서 추적되도록 .gitkeep (워크플로우 시작 전 디렉토리 부재로 인한 silent fail 방지)
for d in plans memory/brainstorms memory/reviews messages/debates; do
  mkdir -p "$PROJECT_DIR/.claude/$d"
  [ -f "$PROJECT_DIR/.claude/$d/.gitkeep" ] || touch "$PROJECT_DIR/.claude/$d/.gitkeep"
done

# 디자인 레퍼런스 폴더 생성
mkdir -p "$PROJECT_DIR/design-ref"
# 에이전트 목록 단일 소스 배포 (agents.json)
safe_copy "$SCRIPT_DIR/core/agents.json" "$PROJECT_DIR/.claude/agents.json"
# 메시지 버스 디렉토리
AGENTS_LIST=$(jq -r '.agents[]' "$SCRIPT_DIR/core/agents.json" | tr '\n' ' ')
mkdir -p "$PROJECT_DIR/.claude/messages"/{archive,debates,broadcast}
for agent in $AGENTS_LIST; do
  mkdir -p "$PROJECT_DIR/.claude/messages/inbox/$agent"
done

# Agents 복사
echo "[1/$TOTAL_STEPS] Agents..."
for src in "$SCRIPT_DIR/core/agents/"*.md; do
  safe_copy "$src" "$PROJECT_DIR/.claude/agents/$(basename "$src")"
done

# Hooks 복사 + 실행 권한
echo "[2/$TOTAL_STEPS] Hooks..."
for src in "$SCRIPT_DIR/core/hooks/"*.sh; do
  safe_copy "$src" "$PROJECT_DIR/.claude/hooks/$(basename "$src")"
done
chmod +x "$PROJECT_DIR/.claude/hooks/"*.sh

# Skills 복사 (하위 디렉토리 포함)
echo "[3/$TOTAL_STEPS] Skills..."
for skill_dir in "$SCRIPT_DIR/core/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  mkdir -p "$PROJECT_DIR/.claude/skills/$skill_name"
  safe_copy "$skill_dir/SKILL.md" "$PROJECT_DIR/.claude/skills/$skill_name/SKILL.md"
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
for src in "$SCRIPT_DIR/core/rules/"*.md; do
  safe_copy "$src" "$PROJECT_DIR/.claude/rules/$(basename "$src")"
done

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

# Scripts 복사 (instinct store + observability)
echo "[6/$TOTAL_STEPS] Scripts (instinct store + observability)..."
mkdir -p "$PROJECT_DIR/.claude/scripts"
cp "$SCRIPT_DIR/scripts/"*.js   "$PROJECT_DIR/.claude/scripts/" 2>/dev/null || true
cp "$SCRIPT_DIR/scripts/"*.sh   "$PROJECT_DIR/.claude/scripts/" 2>/dev/null || true
cp "$SCRIPT_DIR/scripts/"*.json "$PROJECT_DIR/.claude/scripts/" 2>/dev/null || true
chmod +x "$PROJECT_DIR/.claude/scripts/"*.sh 2>/dev/null || true

# better-sqlite3 설치 시도 (실패해도 JSON 폴백으로 동작)
if [ -f "$PROJECT_DIR/.claude/scripts/package.json" ] && command -v npm &>/dev/null; then
  echo "  Installing better-sqlite3..."
  if (cd "$PROJECT_DIR/.claude/scripts" && npm install --silent >/dev/null 2>&1); then
    echo "  ✓ better-sqlite3 installed → SQLite 메트릭 활성화"
    # DB 스키마 초기화
    (cd "$PROJECT_DIR" && node "$PROJECT_DIR/.claude/scripts/store.js" init >/dev/null 2>&1) && \
      echo "  ✓ store.db 초기화됨" || \
      echo "  ⚠ store.db 초기화 실패 (첫 훅 실행 시 자동 생성됨)"
  else
    echo "  ⚠ better-sqlite3 설치 실패 — JSON 폴백 모드로 동작"
  fi
else
  echo "  ⚠ npm 미설치 — JSON 폴백 모드로 동작"
fi

# CLAUDE.md 템플릿 복사 (기존 파일이 없을 때만)
echo "[7/$TOTAL_STEPS] CLAUDE.md + Playwright config..."
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

# .worktreeinclude 복사 (worktree에서 gitignored 파일 자동 복사 설정)
if [ ! -f "$PROJECT_DIR/.worktreeinclude" ]; then
  cp "$SCRIPT_DIR/templates/.worktreeinclude" "$PROJECT_DIR/.worktreeinclude"
  echo "  Created .worktreeinclude (worktree용 .env 자동 복사)"
else
  echo "  .worktreeinclude already exists, skipped"
fi

# validate.sh 복사 (post-setup 검증 스크립트)
cp "$SCRIPT_DIR/validate.sh" "$PROJECT_DIR/.claude/validate.sh"
chmod +x "$PROJECT_DIR/.claude/validate.sh"

# Orchestrator 설정 (선택)
if [ "$WITH_ORCHESTRATORS" = true ]; then
  echo "[8/$TOTAL_STEPS] Orchestrators..."

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
echo "  - Scripts: .claude/scripts/ (instinct store + watch-events.sh 실시간 관측)"
echo "  - Memory:  .claude/memory/ (학습 패턴 저장)"
echo "  - Metrics: .claude/metrics/ (JSON) + .claude/store.db (SQLite)"
echo "  - Messages: .claude/messages/ (에이전트 간 통신)"
[ -f "$PROJECT_DIR/playwright.config.ts" ] && echo "  - Playwright: playwright.config.ts (HTML 리포트)"
[ -f "$PROJECT_DIR/.worktreeinclude" ] && echo "  - Worktree:   .worktreeinclude (.env 자동 복사)"
if [ "$WITH_ORCHESTRATORS" = true ]; then
  echo "  - Orchestrators:"
  [ -f "$HOME/.claude-squad/config.json" ] && echo "    - Claude Squad: ~/.claude-squad/config.json"
  [ -f "$PROJECT_DIR/agent-orchestrator.yaml" ] && echo "    - Agent Orchestrator: agent-orchestrator.yaml"
fi
echo ""
echo "다음 단계:"
echo "  1. bash .claude/validate.sh 로 설치 상태 검증"
echo "  2. .claude/settings.local.json 의 env 섹션에 프로젝트별 환경변수 추가"
echo "  3. CLAUDE.md 의 플레이스홀더({{...}}) 채우기"
echo "  4. 필요 시 .claude/rules/ 에 프로젝트별 규칙 추가 (예: supabase.md)"
echo "  5. deny 목록에 프로젝트별 위험 명령 추가"
echo "  6. 메트릭이 쌓이면 /metrics 로 대시보드 확인"
echo "  7. /retrospective 로 정기 회고 실행"
if [ "$WITH_ORCHESTRATORS" = true ]; then
  echo "  8. orchestrators/README.md 참고하여 오케스트레이터 설정 완료"
else
  echo ""
  echo "병렬 오케스트레이션이 필요하면:"
  echo "  bash setup.sh --with-orchestrators"
  echo "  - Claude Squad: 로컬 병렬 (tmux 필요)"
  echo "  - Agent Orchestrator: CI/CD 자동화 (tmux 불필요)"
  echo "  - tmux 없는 환경: CCManager, cmux(Manaflow) 등 대안 — orchestrators/README.md 참고"
  echo "  비용 예산 프레임워크 미구현 — 소규모 프로젝트는 코어(훅+스킬)만으로 충분합니다."
fi
