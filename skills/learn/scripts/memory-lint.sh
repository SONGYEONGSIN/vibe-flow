#!/bin/bash
# memory-lint.sh [MEMORY_DIR] — 메모리 위생 기계 검사 (Karpathy llm-wiki 'Lint' 축 이식)
# brainstorm: .claude/memory/brainstorms/20260718-llm-wiki-ingest-lint-transplant.md
#
# FAIL(exit 1): dead markdown 링크 / MEMORY.md 200줄 cap / patterns.md hook 규칙 형식 위반
# WARN(exit 0): [[name]] 미해결(설계상 '작성 후보' 표시 — MEMORY 규칙) / 고아 leaf(인덱스 미등재)
# 모순 감지는 기계화 불가 — /learn ingest 절차(LLM)와 audit D1 dimension 책임.
#
# 기본 대상은 project 메모리(.claude/memory). user-level 메모리도 인자로 lint 가능:
#   bash memory-lint.sh ~/.claude/projects/<slug>/memory
# Exit: 0 clean(WARN 허용) / 1 FAIL / 2 디렉토리 없음
set -u
DIR="${1:-.claude/memory}"
[ -d "$DIR" ] || { echo "✗ 메모리 디렉토리 없음: $DIR"; exit 2; }
INDEX="$DIR/MEMORY.md"
FAIL=0; WARN=0
err()  { echo "✗ $1"; FAIL=$((FAIL+1)); }
warn() { echo "⚠ $1"; WARN=$((WARN+1)); }

if [ -f "$INDEX" ]; then
  # 1. FAIL — 인덱스의 상대 markdown 링크(](x.md)) 대상 실존. http/절대경로는 제외.
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    case "$link" in http*|/*) continue ;; esac
    [ -e "$DIR/$link" ] || err "dead 링크: MEMORY.md → $link"
  done < <(grep -oE '\]\([^)]+\.md\)' "$INDEX" 2>/dev/null | sed 's/^](//; s/)$//')

  # 2. FAIL — 200줄 cap (인덱스 비대 = 컨텍스트 윈도우 손실, karpathy-principles §5)
  LINES=$(wc -l < "$INDEX" | tr -d ' ')
  [ "$LINES" -le 200 ] || err "MEMORY.md ${LINES}줄 — 200줄 cap 초과 (leaf 분리 필요)"

  # 5. WARN — 고아 leaf: 디렉토리 직하 *.md 중 인덱스가 파일명을 언급하지 않는 것.
  #    brainstorms/ 등 하위 디렉토리는 제외 (개별 미등재가 정책 — F-I08 카운트 drift 방지).
  for f in "$DIR"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [ "$base" = "MEMORY.md" ] && continue
    grep -qF "$base" "$INDEX" || warn "고아 leaf: $base — MEMORY.md 인덱스 미등재"
  done
else
  warn "인덱스 없음: $INDEX"
fi

# 3. FAIL — patterns.md hook 규칙 형식: '금지' 라인은 '금지: <p>'(legacy 영구) 또는
#    '금지[YYYY-MM-DD]: <p>'(staleness 적용) 둘 중 하나여야 smart-guard.sh 파싱이 동작한다.
#    bracket 이 있는데 날짜가 malformed 면 silent 비활성 — 그 경우만 FAIL.
#    코드 펜스(```) 내부는 형식 문서/예시라 제외.
if [ -f "$DIR/patterns.md" ]; then
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "$line" | grep -qE '^금지(\[[0-9]{4}-[0-9]{2}-[0-9]{2}\])?: ' \
      || err "hook 규칙 형식 위반: '$line' — '금지: <패턴>' 또는 '금지[YYYY-MM-DD]: <패턴>' 필요"
  done < <(awk '/^```/{fence=!fence; next} !fence && /^금지/' "$DIR/patterns.md" 2>/dev/null)
fi

# 4. WARN — [[name]] 위키링크 미해결 (같은 디렉토리에 name.md 부재).
#    미해결은 오류가 아니라 '나중에 쓸 것' 표시 — 작성 후보로만 보고.
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  [ -e "$DIR/$ref.md" ] || warn "[[${ref}]] 미해결 — ${ref}.md 부재 (작성 후보)"
done < <(grep -rhoE '\[\[[a-zA-Z0-9_-]+\]\]' "$DIR" --include='*.md' 2>/dev/null | sed 's/^\[\[//; s/\]\]$//' | LC_ALL=C sort -u)

echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "❌ memory-lint FAIL ${FAIL}건 / WARN ${WARN}건 ($DIR)"
  exit 1
fi
echo "✓ memory-lint clean — FAIL 0 / WARN ${WARN}건 ($DIR)"
exit 0
