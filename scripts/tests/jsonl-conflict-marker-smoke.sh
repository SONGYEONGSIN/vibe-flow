#!/bin/bash
# eval-regression-check.sh section H (memory JSONL conflict-marker 무결성) 스모크
# — fixture 기반 RED/GREEN. F-AV07: .gitattributes merge=union(F-AN07)은 향후 병합의
# 충돌 발생만 막고, 과거에 이미 커밋된 <<<<<<< / ======= / >>>>>>> 마커는 소급 제거
# 하지 않는다 — 이 검사가 없으면 그 상태로 main 에 영구 고정된다.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK="$REPO_ROOT/scripts/eval-regression-check.sh"
PASS=0; FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS+1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM

# 원본 트리를 git fixture 로 복제 — H 섹션은 git ls-files 로 추적 파일만 스캔하므로
# 실제 git repo 여야 재현된다 (비-git fallback 경로는 find 사용, 여기선 git 경로만 검증).
(cd "$REPO_ROOT" && git ls-files -z) | (cd "$TMP" && mkdir -p repo && cd repo && \
  xargs -0 -I{} bash -c 'mkdir -p "$(dirname "{}")" && cp "'"$REPO_ROOT"'/{}" "{}"' \
) 2>/dev/null
(cd "$TMP/repo" && git init -q && git add -A && git commit -qm fixture)

echo "=== 양성 대조: 마커 없는 정상 fixture ==="
out="$(cd "$TMP/repo" && bash scripts/eval-regression-check.sh 2>&1)"
rc=$?
if echo "$out" | grep -q "memory JSONL conflict-marker 무결성"; then
  ok "정상 fixture — H 섹션 ok 라인 출력"
else
  ng "정상 fixture 인데 H 섹션 ok 라인 없음 — 대조군 무효"
  echo "$out" | tail -20
  exit 1
fi

echo "=== RED: queue.jsonl 에 미해결 conflict marker 주입 ==="
printf '{"op":"status_update","id":"x","new_status":"done","ts":"2026-01-01T00:00:00Z"}\n<<<<<<< HEAD\n=======\n>>>>>>> origin/main\n{"op":"status_update","id":"y","new_status":"done","ts":"2026-01-01T00:00:01Z"}\n' \
  >> "$TMP/repo/.claude/memory/auto-build-queue.jsonl"
(cd "$TMP/repo" && git add .claude/memory/auto-build-queue.jsonl && git commit -qm "inject marker")

out="$(cd "$TMP/repo" && bash scripts/eval-regression-check.sh 2>&1)"
rc=$?
if [ "$rc" -ne 0 ] && echo "$out" | grep -q "미해결 git merge conflict marker"; then
  ok "마커 주입 fixture — exit 비0 + 전용 에러 메시지로 검출"
else
  ng "마커 주입에도 검출 실패(exit=$rc) — RED 안 됨"
  echo "$out" | tail -20
fi

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
