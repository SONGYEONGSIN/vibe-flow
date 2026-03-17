#!/bin/bash
# smart-guard.sh — PreToolUse prompt 훅 래퍼
#
# 기존 command-guard.sh를 직접 실행(빠른 차단)하고,
# 패턴에 안 걸리면 .claude/memory/patterns.md를 참조하여
# 프로젝트 컨텍스트 기반 2차 의도 분석을 수행한다.
#
# PreToolUse 훅으로 등록하여 Bash 도구 실행 전 검증.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Bash 도구만 검증
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# 1차: command-guard.sh 위임 (패턴 중복 없이 원본 실행)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/command-guard.sh" ]; then
  echo "$INPUT" | bash "$SCRIPT_DIR/command-guard.sh"
  GUARD_EXIT=$?
  if [ "$GUARD_EXIT" -ne 0 ]; then
    exit "$GUARD_EXIT"
  fi
fi

# 2차: 프로젝트 컨텍스트 기반 검증
# .claude/memory/patterns.md에서 프로젝트별 금지 패턴 로드
PATTERNS_FILE=".claude/memory/patterns.md"
if [ -f "$PATTERNS_FILE" ]; then
  # patterns.md에서 "금지:" 또는 "DENY:" 라인 추출
  DENIED=$(grep -iE "^(금지|deny|block):" "$PATTERNS_FILE" 2>/dev/null | sed 's/^[^:]*: *//')
  while IFS= read -r deny_pattern; do
    [ -z "$deny_pattern" ] && continue
    if echo "$COMMAND" | grep -qiF "$deny_pattern"; then
      echo "BLOCKED: 프로젝트 학습 패턴에 의한 차단 — $deny_pattern"
      echo "  참조: $PATTERNS_FILE"
      exit 2
    fi
  done <<< "$DENIED"
fi

# 통과
exit 0
