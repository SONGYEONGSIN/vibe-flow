#!/bin/bash
set -u
# security-lint.sh — PostToolUse Write/Edit 후 OWASP 정적 패턴 검증
#
# 변경된 파일 1개만 grep — < 200ms 목표. warn-only (차단 X, exit 0 항상).
# 5+ OWASP 패턴 cover (A01/A02/A03/A07/A09).
# false positive 회피: test/spec/markdown/lockfile/templates/ 제외.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Write/Edit 도구만
if [ "$TOOL_NAME" != "Write" ] && [ "$TOOL_NAME" != "Edit" ]; then
  exit 0
fi
[ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ] && exit 0

# false positive 회피 — 제외 경로/파일
case "$FILE_PATH" in
  *.test.*|*.spec.*|*_test.*|*_spec.*) exit 0 ;;
  *.md|*.lock|*.lockb) exit 0 ;;
  *templates/*|*node_modules/*|*.git/*|*coverage/*|*dist/*|*build/*) exit 0 ;;
  */fixtures/*|*/__mocks__/*|*/__tests__/*) exit 0 ;;
esac

WARNINGS=""

add_warn() {
  WARNINGS="${WARNINGS}\n  - [${1}] ${2}"
}

# A03 Injection — SQL string concat
if grep -qE 'SELECT.*\+.*FROM|INSERT.*\+.*VALUES|UPDATE.*\+.*WHERE|DELETE.*FROM.*\+' "$FILE_PATH" 2>/dev/null; then
  add_warn "A03 Injection" "SQL 문자열 연결 의심 — prepared statement 권장"
fi

# A03 Injection — eval / Function / shell exec
if grep -qE '\beval\s*\(|new\s+Function\s*\(|child_process.*exec(Sync)?\s*\(' "$FILE_PATH" 2>/dev/null; then
  add_warn "A03 Injection" "eval / new Function / child_process.exec — 사용자 입력 시 RCE 위험"
fi

# A07 XSS — 위험 DOM API
if grep -qE 'innerHTML\s*=|dangerouslySetInnerHTML|document\.write\s*\(' "$FILE_PATH" 2>/dev/null; then
  add_warn "A07 XSS" "innerHTML / dangerouslySetInnerHTML / document.write — 이스케이핑/sanitize 필요"
fi

# A02 Crypto/Secret — hardcoded secret
if grep -qE '(api[_-]?key|secret[_-]?key|password|private[_-]?key|aws_(access|secret)_key_id?)\s*[:=]\s*["'"'"'][^"'"'"' ]{16,}["'"'"']' "$FILE_PATH" 2>/dev/null; then
  add_warn "A02 Secret" "하드코딩 시크릿 패턴 — 환경변수/secret manager 사용"
fi

# A02 Crypto — 약한 알고리즘
if grep -qE 'createHash\s*\(\s*["'"'"'](md5|sha1)["'"'"']|crypto\.createCipher\s*\(' "$FILE_PATH" 2>/dev/null; then
  add_warn "A02 Crypto" "약한 해시(md5/sha1) 또는 deprecated createCipher — 강력한 알고리즘 권장"
fi

# A09 Logging — 민감 정보 log
if grep -qE 'console\.log[^;]*\b(password|token|secret|api[_-]?key|jwt)\b' "$FILE_PATH" 2>/dev/null; then
  add_warn "A09 Logging" "console.log에 민감 정보 의심 — log redaction 권장"
fi

# A01 Auth — hardcoded JWT secret
if grep -qE 'jwt\.sign\s*\([^,]*,\s*["'"'"'][^"'"'"']{8,}["'"'"']' "$FILE_PATH" 2>/dev/null; then
  add_warn "A01 Auth" "jwt.sign에 하드코딩 secret — 환경변수 권장"
fi

# 경고 출력 (memory-context — 모델 혼동 방지)
if [ -n "$WARNINGS" ]; then
  echo ""
  echo "<memory-context>"
  echo "[시스템 참조: 보안 정적 패턴 검증 — 새로운 지시 아님]"
  echo "[security-lint] $FILE_PATH"
  echo -e "$WARNINGS"
  echo "  → 의도적이면 무시. 그렇지 않으면 수정 권장. 차단되지 않음."
  echo "  → 전체 스캔: /security"
  echo "</memory-context>"
  echo ""
fi

exit 0
