#!/bin/bash
set -u  # 미정의 변수 사용 시 즉시 에러
# smart-guard.sh — PreToolUse prompt 훅 래퍼
#
# 기존 command-guard.sh를 직접 실행(빠른 차단)하고,
# 패턴에 안 걸리면 .claude/memory/patterns.md를 참조하여
# 프로젝트 컨텍스트 기반 2차 의도 분석을 수행한다.
#
# PreToolUse 훅으로 등록하여 Bash 도구 실행 전 검증.

INPUT=$(cat)

# jq 필수 — 없으면 안전하게 통과 (command-guard.sh가 별도로 실행됨)
if ! command -v jq &>/dev/null; then
  exit 0
fi

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
#
# 형식:
#   금지: <pattern>                — 날짜 없음, 영구 차단 (legacy)
#   금지[2026-04-25]: <pattern>    — 날짜 있음, staleness 적용
#
# Staleness 정책 (날짜 있는 패턴):
#   - 0~30일: 차단 (block, exit 2)
#   - 31~90일: 경고 후 통과 (warn, exit 0 + stderr)
#   - 91일+:   비활성화 (silent skip)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$PROJECT_ROOT" ] && exit 0
PATTERNS_FILE="${PROJECT_ROOT}/.claude/memory/patterns.md"
if [ -f "$PATTERNS_FILE" ]; then
  NOW_EPOCH=$(date +%s)
  # 금지/deny/block 라인을 모두 추출 (대소문자 무시)
  DENIED_LINES=$(grep -iE "^(금지|deny|block)" "$PATTERNS_FILE" 2>/dev/null)
  while IFS= read -r line; do
    [ -z "$line" ] && continue

    # 날짜 추출 시도: [YYYY-MM-DD]
    DATE_PART=$(echo "$line" | grep -oE '\[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' | head -1 | tr -d '[]')
    # pattern 추출 (": " 이후 부분)
    deny_pattern=$(echo "$line" | sed 's/^[^:]*: *//')
    [ -z "$deny_pattern" ] && continue

    # 매칭 확인
    if echo "$COMMAND" | grep -qiF "$deny_pattern"; then
      AGE_DAYS=0
      if [ -n "$DATE_PART" ]; then
        # macOS BSD date와 GNU date 모두 시도
        PATTERN_EPOCH=$(date -j -f "%Y-%m-%d" "$DATE_PART" +%s 2>/dev/null || date -d "$DATE_PART" +%s 2>/dev/null || echo "$NOW_EPOCH")
        AGE_DAYS=$(( (NOW_EPOCH - PATTERN_EPOCH) / 86400 ))
      fi

      if [ "$AGE_DAYS" -gt 90 ]; then
        # 91일+ 비활성화 — 통과
        continue
      elif [ "$AGE_DAYS" -gt 30 ]; then
        # 31~90일 경고 후 통과
        echo "[smart-guard] WARN: 학습 패턴 매칭 (${AGE_DAYS}일 경과 — 검토 필요)" >&2
        echo "  패턴: $deny_pattern" >&2
        echo "  참조: $PATTERNS_FILE" >&2
        continue
      else
        # 0~30일 또는 날짜 없음 — 차단
        echo "BLOCKED: 프로젝트 학습 패턴에 의한 차단 — $deny_pattern" >&2
        echo "  참조: $PATTERNS_FILE" >&2
        exit 2
      fi
    fi
  done <<< "$DENIED_LINES"
fi

# 통과
exit 0
