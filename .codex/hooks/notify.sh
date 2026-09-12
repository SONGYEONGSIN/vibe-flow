#!/bin/bash
set -u
# F-K21: stdin drain — payload 미소비 종료 시 writer(Claude Code)가 EPIPE
# ('hook error: Failed to write to socket'). TTY(수동 실행)면 스킵.
[ -t 0 ] || cat >/dev/null 2>&1
# Notification hook: Claude가 사용자 입력을 기다릴 때 데스크톱 알림 전송
# idle_prompt 매처로 트리거된다.

# macOS 전용 알림 (다른 OS는 확장 가능)
if command -v osascript &>/dev/null; then
  osascript -e 'display notification "Claude Code가 입력을 기다리고 있습니다." with title "Claude Code" sound name "Glass"' 2>/dev/null || true
fi

exit 0
