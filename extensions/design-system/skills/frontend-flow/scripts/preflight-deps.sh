#!/bin/bash
# P0 fail-closed dependency gate for /frontend-flow.
# 모든 필수 커맨드가 PATH에 있으면 exit 0, 없으면 exit 1 + 설치 안내(stderr).
set -u

REQUIRED="${FRONTEND_FLOW_DEPS:-node npx jq}"

missing=""
for cmd in $REQUIRED; do
  command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done

if [ -n "$missing" ]; then
  echo "[frontend-flow] 의존성 누락:$missing" >&2
  echo "[frontend-flow] 설치 후 재시도하세요:" >&2
  for cmd in $missing; do
    case "$cmd" in
      node|npx) echo "  - $cmd: https://nodejs.org 에서 Node.js 설치" >&2 ;;
      jq)       echo "  - jq: https://jqlang.github.io/jq/download 참고" >&2 ;;
      *)        echo "  - $cmd: PATH 에서 찾을 수 없음" >&2 ;;
    esac
  done
  exit 1
fi

echo "[frontend-flow] 의존성 OK:$(for c in $REQUIRED; do printf ' %s' "$c"; done)"
exit 0
