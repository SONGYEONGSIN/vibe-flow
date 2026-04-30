#!/bin/bash
set -u  # 미정의 변수 사용 시 즉시 에러
# PreToolUse hook — blocks dangerous Bash commands
# Exit 2 = block execution with error message to Claude
#
# 정책: defense-in-depth — 두 레이어로 위험 명령 차단
#
#   1차 방어 (settings.local.json permissions.deny):
#     Claude Code 레벨 차단 — 사용자가 프로젝트별로 override 가능
#     예: 라이브러리 메인테이너가 'npm publish' 허용하려면 deny 제거
#     적합한 패턴: 정당화 가능한 명령 (publish, force push, db reset 등)
#
#   2차 방어 (이 hook):
#     절대 정당화 불가능한 패턴 — 사용자도 못 풀어야 함
#     예: rm -rf /, dd if=/dev/zero, mkfs, fork bomb, curl|sh
#     fail-closed 원칙 — jq 미설치 시 모든 Bash 차단
#
#   중복 차단 (의도된 redundancy):
#     git push --force / -f 는 두 레이어 모두 명시
#     이유: settings deny는 LLM이 도구 호출 전에 보지만, 명령이 변형되거나
#           다른 도구로 우회될 수 있어 hook 레벨에서 grep 매칭으로 재검증

# jq 없으면 안전하게 차단 (fail-closed). 보안 가드는 silently 비활성화되면 안 됨.
if ! command -v jq >/dev/null 2>&1; then
  echo "[command-guard] FATAL: jq not installed — cannot validate command safety." >&2
  echo "[command-guard] Install jq (brew install jq | apt install jq) and retry." >&2
  exit 2
fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# 명백히 파괴적이고 dual-use 여지가 적은 명령만 차단.
# 사용자 워크플로우에 따라 정당할 수 있는 명령(git reset --hard 등)은
# settings.local.json permissions.deny에서 프로젝트별로 정의.
DANGEROUS_PATTERNS=(
  # === 파일 시스템 파괴 ===
  "rm -rf /"
  "rm -rf /*"
  "rm -rf ~"
  "rm -rf \$HOME"
  "rm -fr /"
  "rm --recursive --force /"
  "find / -delete"
  "find / -exec rm"
  # === 디스크 파괴 ===
  "dd if=/dev/zero of=/dev/"
  "dd if=/dev/random of=/dev/"
  "mkfs."
  "mkfs "
  "> /dev/sda"
  "> /dev/sdb"
  "> /dev/nvme"
  # === Fork bomb ===
  ":(){ :|:& };:"
  ":(){:|:&};:"
  # === DB 리셋 (복구 불가) ===
  "supabase db reset"
  "npx supabase db reset"
  # === Git 강제 푸시 ===
  # 단순 --force / -f만 차단. --force-with-lease는 안전한 변형이라 허용.
  "git push --force "
  "git push -f "
  # === 패키지 배포 ===
  # publish는 라이브러리 메인테이너의 일상 작업이라 hook이 아닌
  # settings.local.json permissions.deny에서 프로젝트별로 결정한다.
  # === 권한 무력화 ===
  "chmod -R 777 /"
  "chmod 777 /"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qF "$pattern"; then
    echo "[command-guard] BLOCKED: '$pattern' is not allowed." >&2
    echo "[command-guard] Command: $COMMAND" >&2
    exit 2
  fi
done

# 정규식 — fixed-string으로는 못 잡는 변형 차단
# --force-with-lease는 안전한 force push라 정규식에서도 의도적으로 제외
DANGEROUS_REGEX=(
  # git push -f / --force (단, --force-with-lease는 허용)
  'git push[[:space:]]+(-[a-zA-Z]*f([[:space:]]|$)|--force([[:space:]]|$))'
  # curl/wget pipe to shell (서명 검증 없는 원격 코드 실행)
  '(curl|wget)[[:space:]].*\|[[:space:]]*(sh|bash|zsh)([[:space:]]|$)'
  # git clean 강제 (-fd, -df 등)
  'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f[a-zA-Z]*d'
)

for regex in "${DANGEROUS_REGEX[@]}"; do
  if echo "$COMMAND" | grep -qE "$regex"; then
    echo "[command-guard] BLOCKED by regex: $regex" >&2
    echo "[command-guard] Command: $COMMAND" >&2
    exit 2
  fi
done

exit 0
