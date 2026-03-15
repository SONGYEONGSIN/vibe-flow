#!/bin/bash
# Stop hook: 세션 종료 시 작업 기록 저장

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

cd "$PROJECT_ROOT" || exit 0

LOG_DIR="${PROJECT_ROOT}/.claude/session-logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
LOG_FILE="${LOG_DIR}/${TIMESTAMP}.md"

# 최근 커밋 기록
RECENT_COMMITS=$(git log --oneline -5 --since="today" 2>/dev/null)

# 변경된 파일
CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null)
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)

# 로그 파일에 비어있으면 생성 안 함
if [ -z "$RECENT_COMMITS" ] && [ -z "$CHANGED_FILES" ] && [ -z "$STAGED_FILES" ]; then
  exit 0
fi

cat > "$LOG_FILE" << EOF
# Session Log - ${TIMESTAMP}

## 오늘의 커밋
${RECENT_COMMITS:-없음}

## 미커밋 변경 파일
${CHANGED_FILES:-없음}

## 스테이징된 파일
${STAGED_FILES:-없음}
EOF
