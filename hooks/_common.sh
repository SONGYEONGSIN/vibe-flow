#!/bin/bash
# _common.sh — 크로스 플랫폼 공유 유틸리티
# 다른 훅에서 source "$(dirname "$0")/_common.sh" 로 로드

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
