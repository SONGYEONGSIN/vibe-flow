#!/bin/bash
# memory-index.sh add-round smoke (audit F-AD09)
# 실행: bash scripts/tests/memory-index-smoke.sh
#
# 왜 스크립트인가: 밤 루프가 **4회 연속**(08-23 AB / 08-25 AC / 08-27 AD / 08-28 AD)
# `phase2-memory` 에서만 끊겼다. 같은 사이클의 ledger append·브랜치 push 는 4회 전건
# 성공했고, 08-24 는 이 단계를 건너뛰어(phase2-skip) 1 사이클을 완주했다 — 이 단계만
# 통과하면 나머지는 돈다는 대조군이 있다.
#
# 유력 가설(인덱스 64KB 라 편집 실패)은 F-AC05 로 **반증**됐다 — 8KB 로 줄인 뒤에도
# 08-28 이 같은 지점에서 멈췄다. 남은 공통점은 크기가 아니라 **작업의 성격**: 이 단계만
# 유일하게 "기존 산문을 읽고 문맥에 맞춰 자유 편집" 이고 나머지는 전부 스크립트 호출이다.
# 원인 규명을 기다리지 않고 실패 모드를 제거한다.
#
# 계약: add-round 는 (1) 헤더의 최근 라운드 갱신 (2) `최근 = 라운드` 줄을 **정확히 1개**로
# 유지(이전 것은 leaf 로 이월 — 누적도 소실도 없다) (3) leaf 에 서사 append
# (4) 결과가 32KB cap 을 넘으면 실패(F-AC05).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MI="$REPO_ROOT/core/skills/audit/scripts/memory-index.sh"

PASS=0
FAIL=0
ok() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
ng() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkfix() {  # 인덱스 + leaf fixture ($1 = 디렉토리)
  mkdir -p "$1"
  cat > "$1/MEMORY.md" <<'EOF'
# Index

## 내부 감사 (Active — `/audit` 스킬로 운영, 최근 Round AD)

- 라운드별 상세 서사 → **[audit-rounds.md](audit-rounds.md)**.
- **최근 = 라운드 AD (2026-08-28, F-AD01~F-AD08)** — 이전 라운드 서사.

## 기타
EOF
  printf '# 감사 라운드 이력\n\n- **라운드 AC** — 옛 서사.\n' > "$1/audit-rounds.md"
}

[ -x "$MI" ] || { echo "  ✗ MI0 memory-index.sh 부재/비실행 — 자유 편집이 그대로 남는다"; echo "PASS: 0   FAIL: 1"; exit 1; }

echo "Test MI1: 새 라운드가 인덱스에 반영"
D="$TMP/a"; mkfix "$D"
MEMORY_DIR="$D" bash "$MI" add-round AE F-AE01 F-AE05 "테스트 라운드 요약" >/dev/null 2>&1
grep -q 'F-AE01' "$D/MEMORY.md" && grep -q 'F-AE05' "$D/MEMORY.md" \
  && ok "MI1.1 양끝 ID 가 인덱스에 등장 (check-doc-counts 요구)" \
  || ng "MI1.2 양끝 ID 미등장 — check-doc-counts 가 RED 가 된다"

echo "Test MI2: '최근 = 라운드' 줄은 정확히 1개 (누적 방지)"
n=$(grep -c '최근 = 라운드' "$D/MEMORY.md")
[ "$n" = "1" ] && ok "MI2.1 1개 유지" \
  || ng "MI2.2 ${n}개 — 자유 편집이 만들던 누적이 그대로다"

echo "Test MI3: 헤더의 최근 라운드 갱신"
grep -q '최근 Round AE' "$D/MEMORY.md" && ok "MI3.1 헤더 갱신 (F-AD01 재발 차단)" \
  || ng "MI3.2 헤더가 stale — F-AD01 과 동일 결함"

echo "Test MI4: 이전 라운드는 leaf 로 이월 (소실 없음)"
grep -q 'F-AD01~F-AD08' "$D/audit-rounds.md" && ok "MI4.1 직전 라운드 서사가 leaf 에 보존" \
  || ng "MI4.2 직전 라운드 서사 소실 — 누적을 막으려다 기록을 지웠다"

echo "Test MI5: 인자 누락은 거부"
MEMORY_DIR="$D" bash "$MI" add-round AF F-AF01 >/dev/null 2>&1
[ "$?" != "0" ] && ok "MI5.1 불완전 호출 거부" || ng "MI5.2 인자 누락인데 통과 — 반쪽 인덱스가 쓰인다"

echo "Test MI6: 32KB cap 초과는 실패 (F-AC05 게이트 승계)"
D2="$TMP/b"; mkfix "$D2"
python3 -c "
import sys
open(sys.argv[1],'a').write('- ' + 'x'*40000 + '\n')" "$D2/MEMORY.md"
MEMORY_DIR="$D2" bash "$MI" add-round AE F-AE01 F-AE05 "요약" >/dev/null 2>&1
[ "$?" != "0" ] && ok "MI6.1 cap 초과 시 실패" || ng "MI6.2 cap 초과인데 통과 — 인덱스 비대가 다시 샌다"

echo ""
echo "─────────────────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[ "$FAIL" -eq 0 ] && { echo "✓ ALL TESTS PASSED"; exit 0; } || { echo "✗ SOME TESTS FAILED"; exit 1; }
