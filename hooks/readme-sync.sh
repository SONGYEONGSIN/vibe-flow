#!/bin/bash
# PostToolUse hook: README/아키텍처 수치 자동 동기화
# agents/, hooks/, skills/, rules/ 파일이 변경되면 수치를 갱신한다
# 비차단 — 실패해도 exit 0

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# 대상 경로가 아니면 무시
case "$FILE_PATH" in
  */agents/*.md|*/hooks/*.sh|*/skills/*/SKILL.md|*/rules/*.md) ;;
  *) exit 0 ;;
esac

# 프로젝트 루트 탐색
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

SYNC_SCRIPT="${PROJECT_ROOT}/scripts/sync-readme.sh"
if [ ! -f "$SYNC_SCRIPT" ]; then
  exit 0
fi

# 동기화 실행 (백그라운드, 비차단)
bash "$SYNC_SCRIPT" > /dev/null 2>&1 || true

exit 0
