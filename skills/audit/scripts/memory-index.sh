#!/bin/bash
# memory-index.sh — 감사 라운드 인덱스 갱신 (audit F-AD09)
#
# 밤 루프가 **4회 연속** `phase2-memory` 에서만 끊겼다(08-23 AB / 08-25 AC / 08-27 AD /
# 08-28 AD). 같은 사이클의 ledger append·브랜치 push 는 4회 전건 성공했고, 08-24 는 이
# 단계를 건너뛰어(phase2-skip) 1 사이클을 완주했다 — **이 단계만 통과하면 나머지는 돈다.**
#
# 유력 가설(인덱스 64KB 라 편집 실패)은 F-AC05 로 반증됐다 — 8KB 로 줄인 뒤에도 08-28 이
# 같은 지점에서 멈췄다. 남은 공통점은 크기가 아니라 **작업의 성격**: 이 단계만 유일하게
# "기존 산문을 읽고 문맥에 맞춰 자유 편집" 이고 나머지는 전부 스크립트 호출이다.
# 원인 규명을 기다리지 않고 실패 모드를 제거한다 — 실패해도 exit 코드로 드러난다.
#
# 사용:
#   memory-index.sh add-round <ROUND> <첫ID> <끝ID> <요약>
#
# 환경변수: MEMORY_DIR (기본 <repo>/.claude/memory)

set -u

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DIR="${MEMORY_DIR:-$PROJECT_ROOT/.claude/memory}"
INDEX="$DIR/MEMORY.md"
LEAF="$DIR/audit-rounds.md"
BYTE_CAP=32768

CMD="${1:-}"
case "$CMD" in
  add-round)
    ROUND="${2:-}"; FIRST="${3:-}"; LAST="${4:-}"; SUMMARY="${5:-}"
    { [ -z "$ROUND" ] || [ -z "$FIRST" ] || [ -z "$LAST" ] || [ -z "$SUMMARY" ]; } && {
      echo "usage: memory-index.sh add-round <ROUND> <첫ID> <끝ID> <요약>" >&2; exit 1; }
    [ -f "$INDEX" ] || { echo "error: $INDEX 없음" >&2; exit 1; }
    [ -f "$LEAF" ] || printf '# 감사 라운드 이력\n\n' > "$LEAF"

    NEWLINE="- **최근 = 라운드 ${ROUND} (${FIRST}~${LAST})** — ${SUMMARY}"

    # 이전 '최근 = 라운드' 줄은 leaf 로 이월한다 — 누적(자유 편집이 만들던 것)도
    # 소실(누적을 막으려다 지우는 것)도 만들지 않는다.
    TMP_I=$(mktemp); TMP_L=$(mktemp)
    grep '^- \*\*최근 = 라운드' "$INDEX" 2>/dev/null | sed 's/^- \*\*최근 = 라운드/- **라운드/' >> "$TMP_L" || true
    if [ -s "$TMP_L" ]; then cat "$LEAF" "$TMP_L" > "${TMP_L}.m" && mv "${TMP_L}.m" "$LEAF"; fi
    rm -f "$TMP_L"

    # 인덱스에서 기존 줄 전부 제거 후 서사 포인터 줄 뒤에 새 줄 1개 삽입.
    # 포인터 줄이 없으면 감사 섹션 헤더 뒤에 넣는다.
    awk -v newline="$NEWLINE" -v round="$ROUND" '
      /^- \*\*최근 = 라운드/ { next }
      { line = $0
        if (line ~ /^## 내부 감사 /) { sub(/최근 Round [^)]*/, "최근 Round " round, line) }
        print line
        if (!done && line ~ /audit-rounds\.md/) { print newline; done = 1 }
      }
      END { if (!done) print newline }
    ' "$INDEX" > "$TMP_I" && mv "$TMP_I" "$INDEX"

    BYTES=$(wc -c < "$INDEX" | tr -d ' ')
    if [ "$BYTES" -gt "$BYTE_CAP" ]; then
      echo "error: MEMORY.md ${BYTES}바이트 — ${BYTE_CAP} cap 초과 (서사는 leaf 로, F-AC05)" >&2
      exit 1
    fi
    echo "memory-index: 라운드 ${ROUND} (${FIRST}~${LAST}) 반영 — ${BYTES}바이트"
    ;;
  *)
    echo "usage: memory-index.sh add-round <ROUND> <첫ID> <끝ID> <요약>" >&2
    exit 2
    ;;
esac
