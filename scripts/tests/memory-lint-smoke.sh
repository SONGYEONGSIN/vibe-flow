#!/bin/bash
# memory-lint.sh 스모크 — fixture 기반 RED/GREEN (brainstorm 20260718 llm-wiki ingest/lint)
# FAIL 축(dead 링크/200줄 cap/hook 규칙 형식)은 exit 1, WARN 축([[미해결]]/고아 leaf)은 exit 0 유지.
# 실행: bash scripts/tests/memory-lint-smoke.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LINT="$REPO_ROOT/core/skills/learn/scripts/memory-lint.sh"
PASS=0; FAIL=0
assert_exit() {
  if [ "$3" = "$2" ]; then echo "  ✓ $1 (exit $2)"; PASS=$((PASS+1));
  else echo "  ✗ $1 (expected $2, got $3)"; FAIL=$((FAIL+1)); fi
}
assert_out() { # label, pattern, output
  if echo "$3" | grep -qF "$2"; then echo "  ✓ $1"; PASS=$((PASS+1));
  else echo "  ✗ $1 ('$2' 미출현)"; FAIL=$((FAIL+1)); fi
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

make_clean() { # 정상 fixture: 인덱스 + 등재된 leaf + 유효 hook 규칙
  local d="$1"; mkdir -p "$d"
  printf '# Index\n- [leaf](leaf.md) — hook\n- patterns.md 참조\n' > "$d/MEMORY.md"
  printf '# leaf\n' > "$d/leaf.md"
  printf '# patterns\n\n## Hook 규칙\n\n금지[2026-07-01]: yarn install\n체크: console.log(\n' > "$d/patterns.md"
}

echo "Test L1: clean fixture → exit 0"
make_clean "$TMP/ok"
bash "$LINT" "$TMP/ok" >/dev/null 2>&1; assert_exit "clean-exit0" "0" "$?"

echo "Test L2: 인덱스 dead markdown 링크 → exit 1"
make_clean "$TMP/dead"
printf -- '- [ghost](ghost.md) — 없는 파일\n' >> "$TMP/dead/MEMORY.md"
bash "$LINT" "$TMP/dead" >/dev/null 2>&1; assert_exit "dead-link-exit1" "1" "$?"

echo "Test L3: MEMORY.md 200줄 cap 초과 → exit 1"
make_clean "$TMP/cap"
for i in $(seq 1 205); do echo "- line $i"; done >> "$TMP/cap/MEMORY.md"
bash "$LINT" "$TMP/cap" >/dev/null 2>&1; assert_exit "cap-exit1" "1" "$?"

echo "Test L4: hook 규칙 형식 위반(금지 bracket 날짜 malformed) → exit 1"
make_clean "$TMP/badrule"
printf '금지[26-7]: rm -rf\n' >> "$TMP/badrule/patterns.md"
bash "$LINT" "$TMP/badrule" >/dev/null 2>&1; assert_exit "bad-rule-exit1" "1" "$?"

echo "Test L4b: legacy 무날짜 '금지: ' 는 유효 형식 → exit 0 (patterns.md 문서화된 형식)"
make_clean "$TMP/legacyrule"
printf '금지: process.env.SECRET\n' >> "$TMP/legacyrule/patterns.md"
bash "$LINT" "$TMP/legacyrule" >/dev/null 2>&1; assert_exit "legacy-rule-exit0" "0" "$?"

echo "Test L4c: 코드 펜스 내부의 형식 예시는 lint 제외 → exit 0"
make_clean "$TMP/fenced"
printf '\n## 형식\n\n```\n금지[bad]: <pattern> 예시\n```\n' >> "$TMP/fenced/patterns.md"
bash "$LINT" "$TMP/fenced" >/dev/null 2>&1; assert_exit "fenced-doc-exit0" "0" "$?"

echo "Test L5: [[미해결]] 링크 → WARN 만 (exit 0 + 메시지)"
make_clean "$TMP/wiki"
printf '[[future-topic]] 관련\n' >> "$TMP/wiki/leaf.md"
OUT5="$(bash "$LINT" "$TMP/wiki" 2>&1)"; assert_exit "unresolved-wikilink-exit0" "0" "$?"
assert_out "unresolved-wikilink-warn" "future-topic" "$OUT5"

echo "Test L6: 고아 leaf(인덱스 미등재) → WARN 만 (exit 0 + 메시지)"
make_clean "$TMP/orphan"
printf '# stray\n' > "$TMP/orphan/stray-note.md"
OUT6="$(bash "$LINT" "$TMP/orphan" 2>&1)"; assert_exit "orphan-leaf-exit0" "0" "$?"
assert_out "orphan-leaf-warn" "stray-note.md" "$OUT6"

echo "Test L7: 디렉토리 없음 → exit 2"
bash "$LINT" "$TMP/nodir" >/dev/null 2>&1; assert_exit "missing-dir-exit2" "2" "$?"

echo "Test L8: 실 repo .claude/memory — FAIL 축 clean (live 게이트)"
bash "$LINT" "$REPO_ROOT/.claude/memory" >/dev/null 2>&1; assert_exit "live-repo-exit0" "0" "$?"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
