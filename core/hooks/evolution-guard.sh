#!/bin/bash
set -u
# evolution-guard.sh — PreToolUse 안전 hook: 자율 모드에서 안전코어(denylist) 수정 차단.
#
# 설계 (harness-evolution 자율진화 PR-1 / 불변식):
#   자율 루프가 자기 자신의 안전장치(guard·게이트·denylist)를 수정하면 self-corruption
#   런어웨이가 된다. 본 hook 은 AUTO_BUILD_MODE=1 일 때만 활성화되어 .claude/evolution-protected
#   목록의 파일에 대한 Edit/Write/Bash-변경을 차단한다. **사람(비-자율)은 수정 가능** —
#   "안전코어는 사람만 수정".
#
# 규약 (auto-build-safety.sh 와 일관):
#   차단 = stderr 사유 + exit 2 (Claude Code PreToolUse block).
#   통과 = exit 0.
#   비-자율(AUTO_BUILD_MODE≠1) = silent exit 0 (영향 0).
#   denylist 부재 = fail-closed (안전코어 보호 불가 → 자율 변경 전면 차단).

# 자율 모드 아니면 즉시 통과 (사람은 안전코어 수정 허용)
[ "${AUTO_BUILD_MODE:-}" != "1" ] && exit 0

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DENYLIST="$ROOT/.claude/evolution-protected"

block() {
  echo "[evolution-guard] BLOCKED — $1" >&2
  echo "[evolution-guard] 안전코어(.claude/evolution-protected 등재)는 사람만 수정. 자율 사이클은 우회 불가 — finding 으로 surface 후 human review." >&2
  exit 2
}

# denylist 부재 → fail-closed (변경 도구만 차단, 조회는 통과)
if [ ! -f "$DENYLIST" ]; then
  case "$TOOL_NAME" in
    Edit|Write) block "denylist(.claude/evolution-protected) 부재 — 안전코어 보호 불가, 자율 수정 차단(fail-closed)" ;;
    *) exit 0 ;;
  esac
fi

# denylist 를 배열로 로드 (주석·빈 줄 제외)
ENTRIES=()
while IFS= read -r line; do
  line="${line%%[$'\r']}"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  ENTRIES+=("$line")
done < "$DENYLIST"

case "$TOOL_NAME" in
  Edit|Write)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    [ -z "$TARGET" ] && exit 0
    # repo-relative 정규화
    REL="${TARGET#"$ROOT"/}"
    REL="${REL#./}"
    TBASE=$(basename "$TARGET")
    for entry in "${ENTRIES[@]}"; do
      if [ "$REL" = "$entry" ] || [ "$TARGET" = "$entry" ] || [ "$TBASE" = "$(basename "$entry")" ]; then
        block "안전코어 파일 수정 금지: ${REL}"
      fi
    done
    exit 0
    ;;
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
    [ -z "$CMD" ] && exit 0
    # Bash 벡터: 보호 파일(basename)을 변경 동사로 겨냥하는 명령 차단.
    # 조회(cat/grep/read)는 통과 — 변경 연산이 basename 을 겨냥할 때만 차단.
    for entry in "${ENTRIES[@]}"; do
      B=$(basename "$entry")
      Bre=$(printf '%s' "$B" | sed 's/[.[\*^$]/\\&/g')  # regex 메타 이스케이프
      # sed -i B | redirect(>,>>) to B | tee B | rm B | cp/mv ..B | truncate/chmod B
      if echo "$CMD" | grep -qE "(sed[[:space:]].*-i.*${Bre}|>>?[[:space:]]*['\"]?[^[:space:];|&]*${Bre}|tee[[:space:]].*${Bre}|\brm\b.*${Bre}|\b(cp|mv)\b.*${Bre}|\b(truncate|chmod)\b.*${Bre})"; then
        block "Bash 로 안전코어 변경 시도: ${entry} (명령: ${CMD})"
      fi
    done
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
