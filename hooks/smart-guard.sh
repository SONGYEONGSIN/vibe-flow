#!/bin/bash
# smart-guard.sh — PreToolUse prompt 훅 래퍼
#
# 기존 command-guard.sh의 패턴 매칭을 먼저 실행(빠른 차단)하고,
# 패턴에 안 걸리면 .claude/memory/patterns.md를 참조하여
# 프로젝트 컨텍스트 기반 2차 의도 분석을 수행한다.
#
# PreToolUse 훅으로 등록하여 Bash 도구 실행 전 검증.

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# Bash 도구만 검증
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# 1차: 기존 command-guard.sh 패턴 매칭 (빠른 차단)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/command-guard.sh" ]; then
  # command-guard.sh가 존재하면 동일한 패턴 체크 실행
  COMMAND=$(echo "$TOOL_INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"$//')

  # 위험 패턴 직접 체크 (command-guard.sh와 동일한 패턴)
  DANGEROUS_PATTERNS=(
    "rm -rf /"
    "rm -rf ~"
    "rm -rf \$HOME"
    "mkfs"
    "dd if="
    "> /dev/sd"
    ":(){ :|:& };:"
    "chmod -R 777 /"
    "curl.*| sh"
    "curl.*| bash"
    "wget.*| sh"
    "wget.*| bash"
  )

  for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qF "$pattern"; then
      echo "BLOCKED: 위험한 명령 패턴 감지 — $pattern"
      exit 2
    fi
  done
fi

# 2차: 프로젝트 컨텍스트 기반 검증
# .claude/memory/patterns.md에서 프로젝트별 금지 패턴 로드
PATTERNS_FILE=".claude/memory/patterns.md"
if [ -f "$PATTERNS_FILE" ]; then
  # patterns.md에서 "금지:" 또는 "DENY:" 라인 추출
  DENIED=$(grep -iE "^(금지|deny|block):" "$PATTERNS_FILE" 2>/dev/null | sed 's/^[^:]*: *//')
  while IFS= read -r deny_pattern; do
    [ -z "$deny_pattern" ] && continue
    if echo "$TOOL_INPUT" | grep -qiF "$deny_pattern"; then
      echo "BLOCKED: 프로젝트 학습 패턴에 의한 차단 — $deny_pattern"
      echo "  참조: $PATTERNS_FILE"
      exit 2
    fi
  done <<< "$DENIED"
fi

# 통과
exit 0
