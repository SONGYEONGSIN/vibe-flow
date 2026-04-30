#!/bin/bash
# _common.sh — 크로스 플랫폼 공유 유틸리티
# 다른 훅에서 source "$(dirname "$0")/_common.sh" 로 로드
set -u  # 미정의 변수 사용 시 즉시 에러

# 크로스 플랫폼 임시 디렉토리
# Git Bash(Windows): TEMP, macOS: TMPDIR, Linux: /tmp
_HOOK_TMPDIR="${TMPDIR:-${TEMP:-/tmp}}"

# 표준 로그 파일 경로
PRETTIER_LOG="${_HOOK_TMPDIR}/prettier-hook.log"
ESLINT_LOG="${_HOOK_TMPDIR}/eslint-hook.log"
TYPECHECK_LOG="${_HOOK_TMPDIR}/typecheck-hook.log"
TEST_RUNNER_LOG="${_HOOK_TMPDIR}/test-runner-hook.log"

# 크로스 플랫폼 파일 수정 시간 (epoch seconds)
# macOS, Linux, Git Bash 모두 date -r 지원
get_file_mtime() {
  local file="$1"
  date -r "$file" +%s 2>/dev/null || echo "0"
}

# 크로스 플랫폼 랜덤 hex (4자)
# Git Bash/MSYS2에서는 /dev/urandom 존재, 없으면 $RANDOM 폴백
generate_random_hex() {
  if [ -r /dev/urandom ]; then
    head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 4
  else
    printf '%04x' "$RANDOM"
  fi
}

# 로그 파일이 max_bytes 초과 시 tail로 잘라 저장 (원자적 처리)
# 기본 제한: 1MB(1048576), 보관 라인 수: 100
truncate_log_file() {
  local log_file="$1"
  local max_bytes="${2:-1048576}"
  local tail_lines="${3:-100}"
  if [ -f "$log_file" ] && [ "$(wc -c < "$log_file" 2>/dev/null || echo 0)" -gt "$max_bytes" ]; then
    local tmplog
    tmplog=$(mktemp "${log_file}.XXXXXX") && tail -n "$tail_lines" "$log_file" > "$tmplog" && mv "$tmplog" "$log_file" || rm -f "$tmplog"
  fi
}
