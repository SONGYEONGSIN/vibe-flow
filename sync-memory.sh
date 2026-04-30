#!/bin/bash
set -uo pipefail  # 미정의 변수 에러 + 파이프라인 실패 전파
# sync-memory.sh — Claude Code 학습 데이터 동기화 스크립트
# ~/.claude/ 의 메모리, 설정, 에이전트 학습 데이터를 orphan branch로 push/pull
#
# 사용법:
#   bash sync-memory.sh push [--dry-run] [--force]
#   bash sync-memory.sh pull [--dry-run] [--force]
#   bash sync-memory.sh status

set -e

# ──────────────────────────────────────────────
# 상수
# ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="$HOME/.claude"
SYNC_BRANCH="claude-memory"
SYNC_REMOTE="origin"
WORK_DIR=""

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ──────────────────────────────────────────────
# 유틸리티
# ──────────────────────────────────────────────
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

cleanup() {
  if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    git -C "$SCRIPT_DIR" worktree remove "$WORK_DIR" --force 2>/dev/null || rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

# ──────────────────────────────────────────────
# 인자 파싱
# ──────────────────────────────────────────────
COMMAND=""
DRY_RUN=false
FORCE=false

for arg in "$@"; do
  case "$arg" in
    push|pull|status) COMMAND="$arg" ;;
    --dry-run) DRY_RUN=true ;;
    --force)   FORCE=true ;;
    --help|-h)
      echo "사용법: bash sync-memory.sh <push|pull|status> [--dry-run] [--force]"
      echo ""
      echo "서브커맨드:"
      echo "  push     현재 PC의 학습 데이터를 remote branch에 업로드"
      echo "  pull     remote branch에서 학습 데이터를 다운로드"
      echo "  status   로컬과 remote의 차이점 요약"
      echo ""
      echo "옵션:"
      echo "  --dry-run  실제 변경 없이 미리보기만"
      echo "  --force    확인 프롬프트 건너뛰기"
      exit 0
      ;;
    *)
      err "알 수 없는 인자: $arg"
      echo "사용법: bash sync-memory.sh <push|pull|status> [--dry-run] [--force]"
      exit 1
      ;;
  esac
done

if [ -z "$COMMAND" ]; then
  err "서브커맨드를 지정하세요: push, pull, status"
  echo "사용법: bash sync-memory.sh <push|pull|status> [--dry-run] [--force]"
  exit 1
fi

# ──────────────────────────────────────────────
# 사용자 설정 로드 (선택)
# ──────────────────────────────────────────────
if [ -f "$SCRIPT_DIR/sync-memory.conf" ]; then
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/sync-memory.conf"
fi

# ──────────────────────────────────────────────
# 사전 검증
# ──────────────────────────────────────────────
if ! command -v git &>/dev/null; then
  err "git이 필요합니다"
  exit 1
fi

if [ ! -d "$CLAUDE_HOME" ]; then
  err "~/.claude 디렉토리가 없습니다"
  exit 1
fi

if ! git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
  err "vibe-flow가 git 저장소가 아닙니다"
  exit 1
fi

# ──────────────────────────────────────────────
# 동기화 대상 정의 (절대 동기화하지 않는 파일 제외)
# ──────────────────────────────────────────────
NEVER_SYNC=".credentials.json history.jsonl plugins cache backups file-history work-log sessions session-env shell-snapshots telemetry ide paste-cache plans tasks cc-chips cc-chips-custom"

# ──────────────────────────────────────────────
# 동기화 대상을 worktree로 복사
# ──────────────────────────────────────────────
copy_to_worktree() {
  local dest="$1"

  # settings.json
  if [ -f "$CLAUDE_HOME/settings.json" ]; then
    cp "$CLAUDE_HOME/settings.json" "$dest/settings.json"
  fi

  # 디렉토리 대상: rules, agents, hooks, skills, commands
  for dir_name in rules agents hooks skills commands; do
    if [ -d "$CLAUDE_HOME/$dir_name" ]; then
      mkdir -p "$dest/$dir_name"
      cp -r "$CLAUDE_HOME/$dir_name/"* "$dest/$dir_name/" 2>/dev/null || true
    fi
  done

  # homunculus/observations.jsonl
  if [ -f "$CLAUDE_HOME/homunculus/observations.jsonl" ]; then
    mkdir -p "$dest/homunculus"
    cp "$CLAUDE_HOME/homunculus/observations.jsonl" "$dest/homunculus/observations.jsonl"
  fi

  # 프로젝트별 memory
  mkdir -p "$dest/project-memory"
  for mem_dir in "$CLAUDE_HOME/projects"/*/memory; do
    [ -d "$mem_dir" ] || continue
    project_name="$(basename "$(dirname "$mem_dir")")"
    mkdir -p "$dest/project-memory/$project_name/memory"
    cp -r "$mem_dir/"* "$dest/project-memory/$project_name/memory/" 2>/dev/null || true
  done

  # 메타데이터
  cat > "$dest/.sync-meta.json" <<METAEOF
{
  "hostname": "$(hostname)",
  "username": "$(whoami)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "platform": "$(uname -s)"
}
METAEOF
}

# ──────────────────────────────────────────────
# worktree에서 로컬로 복사
# ──────────────────────────────────────────────
copy_from_worktree() {
  local src="$1"

  # settings.json
  if [ -f "$src/settings.json" ]; then
    cp "$src/settings.json" "$CLAUDE_HOME/settings.json"
  fi

  # 디렉토리 대상
  for dir_name in rules agents hooks skills commands; do
    if [ -d "$src/$dir_name" ]; then
      mkdir -p "$CLAUDE_HOME/$dir_name"
      cp -r "$src/$dir_name/"* "$CLAUDE_HOME/$dir_name/" 2>/dev/null || true
    fi
  done

  # hooks 실행 권한
  if [ -d "$CLAUDE_HOME/hooks" ]; then
    chmod +x "$CLAUDE_HOME/hooks/"*.sh 2>/dev/null || true
  fi

  # homunculus/observations.jsonl — 병합
  if [ -f "$src/homunculus/observations.jsonl" ]; then
    merge_observations "$src/homunculus/observations.jsonl"
  fi

  # 프로젝트별 memory
  if [ -d "$src/project-memory" ]; then
    for proj_dir in "$src/project-memory"/*/memory; do
      [ -d "$proj_dir" ] || continue
      project_name="$(basename "$(dirname "$proj_dir")")"
      target="$CLAUDE_HOME/projects/$project_name/memory"
      mkdir -p "$target"
      cp -r "$proj_dir/"* "$target/" 2>/dev/null || true
    done
  fi
}

# ──────────────────────────────────────────────
# observations.jsonl 병합 (union + dedup)
# ──────────────────────────────────────────────
merge_observations() {
  local remote_file="$1"
  local local_file="$CLAUDE_HOME/homunculus/observations.jsonl"
  mkdir -p "$CLAUDE_HOME/homunculus"

  if [ ! -f "$local_file" ]; then
    cp "$remote_file" "$local_file"
    return
  fi

  local merged_tmp
  merged_tmp="$(mktemp)"

  if command -v python3 &>/dev/null; then
    cat "$local_file" "$remote_file" | python3 -c "
import json, sys
seen = set()
lines = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        key = (obj.get('timestamp',''), obj.get('session',''), obj.get('tool',''))
        if key not in seen:
            seen.add(key)
            lines.append((obj.get('timestamp',''), line))
    except json.JSONDecodeError:
        lines.append(('', line))
lines.sort(key=lambda x: x[0])
for _, l in lines:
    print(l)
" > "$merged_tmp"
  else
    # python3 없으면 sort -u 폴백
    warn "python3 없음 — sort -u로 중복 제거"
    cat "$local_file" "$remote_file" | sort -u > "$merged_tmp"
  fi

  cp "$merged_tmp" "$local_file"
  rm -f "$merged_tmp"
}

# ──────────────────────────────────────────────
# 백업 생성
# ──────────────────────────────────────────────
create_backup() {
  local backup_dir="$CLAUDE_HOME/backups/sync-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"

  for item in settings.json rules agents hooks skills commands; do
    if [ -e "$CLAUDE_HOME/$item" ]; then
      cp -r "$CLAUDE_HOME/$item" "$backup_dir/" 2>/dev/null || true
    fi
  done

  if [ -f "$CLAUDE_HOME/homunculus/observations.jsonl" ]; then
    mkdir -p "$backup_dir/homunculus"
    cp "$CLAUDE_HOME/homunculus/observations.jsonl" "$backup_dir/homunculus/"
  fi

  echo "$backup_dir"
}

# ──────────────────────────────────────────────
# 민감정보 스캔
# ──────────────────────────────────────────────
scan_secrets() {
  local dir="$1"
  local found
  found=$(grep -rl -E "(sk-|api_key|apiKey|password|secret|token)" "$dir" --include="*.json" --include="*.jsonl" 2>/dev/null | grep -v ".sync-meta.json" || true)
  if [ -n "$found" ]; then
    warn "민감정보가 포함된 파일 감지:"
    echo "$found" | while read -r f; do
      echo "  - $f"
    done
    if [ "$FORCE" != true ]; then
      read -rp "계속 진행하시겠습니까? [y/N] " answer
      if [[ ! "$answer" =~ ^[yY]$ ]]; then
        info "취소됨"
        exit 0
      fi
    fi
  fi
}

# ──────────────────────────────────────────────
# worktree 준비 (orphan 브랜치 처리)
# ──────────────────────────────────────────────
prepare_worktree() {
  WORK_DIR="$(mktemp -d)"

  # remote에서 브랜치 fetch 시도
  local branch_exists=false
  if git -C "$SCRIPT_DIR" fetch "$SYNC_REMOTE" "$SYNC_BRANCH" 2>/dev/null; then
    branch_exists=true
  fi

  if [ "$branch_exists" = true ]; then
    # 로컬 브랜치가 있으면 업데이트, 없으면 생성
    if git -C "$SCRIPT_DIR" show-ref --verify --quiet "refs/heads/$SYNC_BRANCH" 2>/dev/null; then
      git -C "$SCRIPT_DIR" worktree add "$WORK_DIR" "$SYNC_BRANCH"
      git -C "$WORK_DIR" reset --hard "$SYNC_REMOTE/$SYNC_BRANCH"
    else
      git -C "$SCRIPT_DIR" worktree add "$WORK_DIR" -b "$SYNC_BRANCH" "$SYNC_REMOTE/$SYNC_BRANCH"
    fi
  else
    # orphan 브랜치 새로 생성
    git -C "$SCRIPT_DIR" worktree add --orphan -b "$SYNC_BRANCH" "$WORK_DIR"
    # orphan worktree는 main의 파일을 가져오므로 전부 제거
    git -C "$WORK_DIR" rm -rf . 2>/dev/null || true
  fi
}

# ══════════════════════════════════════════════
# 서브커맨드 구현
# ══════════════════════════════════════════════

# ──────────────────────────────────────────────
# PUSH
# ──────────────────────────────────────────────
do_push() {
  echo "=== sync-memory: push ==="
  echo ""

  info "[1/5] worktree 준비..."
  prepare_worktree

  info "[2/5] 학습 데이터 복사..."
  # worktree 기존 내용 정리 (.git 제외)
  find "$WORK_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null || true
  copy_to_worktree "$WORK_DIR"

  info "[3/5] 민감정보 스캔..."
  scan_secrets "$WORK_DIR"

  info "[4/5] 변경 확인..."
  cd "$WORK_DIR"
  git add -A

  if git diff --cached --quiet; then
    ok "변경 사항 없음 — 이미 최신 상태"
    return
  fi

  # 변경 요약
  echo ""
  git diff --cached --stat
  echo ""

  if [ "$DRY_RUN" = true ]; then
    warn "[DRY-RUN] 위 변경이 push 될 예정 (실제 push 안 함)"
    return
  fi

  if [ "$FORCE" != true ]; then
    read -rp "push 하시겠습니까? [Y/n] " answer
    if [[ "$answer" =~ ^[nN]$ ]]; then
      info "취소됨"
      return
    fi
  fi

  info "[5/5] push..."
  git commit -m "sync: push from $(hostname) at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  git push "$SYNC_REMOTE" "$SYNC_BRANCH"

  echo ""
  ok "push 완료!"
}

# ──────────────────────────────────────────────
# PULL
# ──────────────────────────────────────────────
do_pull() {
  echo "=== sync-memory: pull ==="
  echo ""

  info "[1/5] remote 확인..."
  if ! git -C "$SCRIPT_DIR" fetch "$SYNC_REMOTE" "$SYNC_BRANCH" 2>/dev/null; then
    err "remote에 $SYNC_BRANCH 브랜치가 없습니다. 먼저 다른 PC에서 push 하세요."
    exit 1
  fi

  info "[2/5] worktree 준비..."
  prepare_worktree

  # 마지막 push 정보 표시
  if [ -f "$WORK_DIR/.sync-meta.json" ]; then
    echo ""
    info "마지막 push 정보:"
    cat "$WORK_DIR/.sync-meta.json"
    echo ""
  fi

  info "[3/5] 변경 요약..."
  local changed=0
  local new_files=0

  # settings.json 비교
  if [ -f "$WORK_DIR/settings.json" ]; then
    if [ -f "$CLAUDE_HOME/settings.json" ]; then
      if ! diff -q "$CLAUDE_HOME/settings.json" "$WORK_DIR/settings.json" &>/dev/null; then
        echo "  변경: settings.json"
        changed=$((changed + 1))
      fi
    else
      echo "  신규: settings.json"
      new_files=$((new_files + 1))
    fi
  fi

  # 디렉토리 비교
  for dir_name in rules agents hooks skills commands; do
    if [ -d "$WORK_DIR/$dir_name" ]; then
      local dir_diff
      dir_diff=$(diff -rq "$CLAUDE_HOME/$dir_name" "$WORK_DIR/$dir_name" 2>/dev/null | wc -l || echo "0")
      if [ "$dir_diff" -gt 0 ]; then
        echo "  변경: $dir_name/ ($dir_diff개 파일 다름)"
        changed=$((changed + dir_diff))
      fi
    fi
  done

  # observations
  if [ -f "$WORK_DIR/homunculus/observations.jsonl" ]; then
    local local_lines=0 remote_lines=0
    [ -f "$CLAUDE_HOME/homunculus/observations.jsonl" ] && local_lines=$(wc -l < "$CLAUDE_HOME/homunculus/observations.jsonl")
    remote_lines=$(wc -l < "$WORK_DIR/homunculus/observations.jsonl")
    if [ "$local_lines" != "$remote_lines" ]; then
      echo "  병합: observations.jsonl (로컬: ${local_lines}줄, remote: ${remote_lines}줄)"
      changed=$((changed + 1))
    fi
  fi

  # 프로젝트 메모리
  if [ -d "$WORK_DIR/project-memory" ]; then
    local mem_count
    mem_count=$(find "$WORK_DIR/project-memory" -name "*.md" | wc -l)
    if [ "$mem_count" -gt 0 ]; then
      echo "  프로젝트 메모리: ${mem_count}개 파일"
    fi
  fi

  echo ""

  if [ "$changed" -eq 0 ] && [ "$new_files" -eq 0 ]; then
    ok "변경 사항 없음 — 이미 최신 상태"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    warn "[DRY-RUN] 위 변경이 적용될 예정 (실제 변경 안 함)"
    return
  fi

  if [ "$FORCE" != true ]; then
    read -rp "pull 하시겠습니까? (로컬 데이터가 덮어씌워집니다) [y/N] " answer
    if [[ ! "$answer" =~ ^[yY]$ ]]; then
      info "취소됨"
      return
    fi
  fi

  info "[4/5] 백업 생성..."
  local backup_path
  backup_path=$(create_backup)
  ok "백업: $backup_path"

  info "[5/5] 학습 데이터 적용..."
  copy_from_worktree "$WORK_DIR"

  echo ""
  ok "pull 완료!"
}

# ──────────────────────────────────────────────
# STATUS
# ──────────────────────────────────────────────
do_status() {
  echo "=== sync-memory: status ==="
  echo ""

  # remote 확인
  if ! git -C "$SCRIPT_DIR" fetch "$SYNC_REMOTE" "$SYNC_BRANCH" 2>/dev/null; then
    warn "remote에 $SYNC_BRANCH 브랜치가 없습니다."
    echo "  아직 push 한 적이 없습니다."
    echo ""
    info "로컬 데이터:"
    echo "  settings.json: $([ -f "$CLAUDE_HOME/settings.json" ] && echo "있음" || echo "없음")"
    for dir_name in rules agents hooks skills commands; do
      local count=0
      [ -d "$CLAUDE_HOME/$dir_name" ] && count=$(find "$CLAUDE_HOME/$dir_name" -type f | wc -l)
      echo "  $dir_name/: ${count}개 파일"
    done
    return
  fi

  prepare_worktree

  # 메타데이터
  if [ -f "$WORK_DIR/.sync-meta.json" ]; then
    info "마지막 push:"
    cat "$WORK_DIR/.sync-meta.json"
    echo ""
  fi

  # 비교
  info "비교 결과:"
  local total_diff=0

  if [ -f "$WORK_DIR/settings.json" ] && [ -f "$CLAUDE_HOME/settings.json" ]; then
    if diff -q "$CLAUDE_HOME/settings.json" "$WORK_DIR/settings.json" &>/dev/null; then
      echo "  settings.json: 동일"
    else
      echo -e "  settings.json: ${YELLOW}다름${NC}"
      total_diff=$((total_diff + 1))
    fi
  fi

  for dir_name in rules agents hooks skills commands; do
    local local_count=0 remote_count=0 diff_count=0
    [ -d "$CLAUDE_HOME/$dir_name" ] && local_count=$(find "$CLAUDE_HOME/$dir_name" -type f | wc -l)
    [ -d "$WORK_DIR/$dir_name" ] && remote_count=$(find "$WORK_DIR/$dir_name" -type f | wc -l)
    if [ -d "$CLAUDE_HOME/$dir_name" ] && [ -d "$WORK_DIR/$dir_name" ]; then
      diff_count=$(diff -rq "$CLAUDE_HOME/$dir_name" "$WORK_DIR/$dir_name" 2>/dev/null | wc -l || echo "0")
    fi
    if [ "$diff_count" -gt 0 ]; then
      echo -e "  $dir_name/: 로컬 ${local_count}, remote ${remote_count} — ${YELLOW}${diff_count}개 다름${NC}"
      total_diff=$((total_diff + diff_count))
    else
      echo "  $dir_name/: 로컬 ${local_count}, remote ${remote_count} — 동일"
    fi
  done

  # observations
  local local_obs=0 remote_obs=0
  [ -f "$CLAUDE_HOME/homunculus/observations.jsonl" ] && local_obs=$(wc -l < "$CLAUDE_HOME/homunculus/observations.jsonl")
  [ -f "$WORK_DIR/homunculus/observations.jsonl" ] && remote_obs=$(wc -l < "$WORK_DIR/homunculus/observations.jsonl")
  if [ "$local_obs" != "$remote_obs" ]; then
    echo -e "  observations: 로컬 ${local_obs}줄, remote ${remote_obs}줄 — ${YELLOW}다름${NC}"
    total_diff=$((total_diff + 1))
  else
    echo "  observations: ${local_obs}줄 — 동일"
  fi

  echo ""
  if [ "$total_diff" -eq 0 ]; then
    ok "모두 동기화됨"
  else
    warn "${total_diff}건 차이 발견 — push 또는 pull 필요"
  fi
}

# ══════════════════════════════════════════════
# 실행
# ══════════════════════════════════════════════
case "$COMMAND" in
  push)   do_push   ;;
  pull)   do_pull   ;;
  status) do_status ;;
esac
