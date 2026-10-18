#!/bin/bash
# scripts/audit.sh — 웹 디자인 가이드라인 통합 감사 스크립트
# 사용법: bash scripts/audit.sh [프로젝트_루트]
#
# 종료 코드: FAIL 수 (0 = 모든 검사 통과)

set -eu

# ─── 설정 ──────────────────────────────────────────
PROJECT_DIR="${1:-$(git rev-parse --show-toplevel 2>/dev/null || echo '.')}"
REPORT_FILE="${REPORT_FILE:-audit-report.md}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# 카테고리별 카운터
A_FAIL=0; A_WARN=0
F_FAIL=0; F_WARN=0
M_FAIL=0; M_WARN=0
C_FAIL=0; C_WARN=0
P_FAIL=0; P_WARN=0
R_FAIL=0; R_WARN=0
TW_FAIL=0; TW_WARN=0
X_FAIL=0; X_WARN=0

TOTAL_FAIL=0
TOTAL_WARN=0

# ─── 유틸리티 ──────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_fail() {
  local rule="$1"
  local msg="$2"
  echo -e "${RED}[FAIL]${NC} [$rule] $msg"
  echo "[FAIL] [$rule] $msg" >> "$REPORT_FILE"
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
}

log_warn() {
  local rule="$1"
  local msg="$2"
  echo -e "${YELLOW}[WARN]${NC} [$rule] $msg"
  echo "[WARN] [$rule] $msg" >> "$REPORT_FILE"
  TOTAL_WARN=$((TOTAL_WARN + 1))
}

log_pass() {
  local rule="$1"
  local msg="$2"
  echo -e "${GREEN}[PASS]${NC} [$rule] $msg"
  echo "[PASS] [$rule] $msg" >> "$REPORT_FILE"
}

log_section() {
  local title="$1"
  echo ""
  echo -e "${BLUE}── $title ─────────────────────────────${NC}"
  echo "" >> "$REPORT_FILE"
  echo "## $title" >> "$REPORT_FILE"
}

count_grep() {
  # 안전한 grep 카운트 (파일 없어도 0 반환, pipefail 우회)
  { grep -rn "$@" 2>/dev/null || true; } | { grep -v 'node_modules' 2>/dev/null || true; } | wc -l | tr -d ' '
}

# ─── 초기화 ────────────────────────────────────────
echo "# Web Design Guidelines Audit Report" > "$REPORT_FILE"
echo "Date: $TIMESTAMP" >> "$REPORT_FILE"
echo "Project: $PROJECT_DIR" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo ""
echo "Web Design Guidelines Audit"
echo "Project: $PROJECT_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── 1. 접근성 검사 ────────────────────────────────
log_section "1. 접근성 (Accessibility)"

# A01: div onClick
count=$(count_grep '<div.*onClick' --include="*.tsx" "$PROJECT_DIR")
if [ "$count" -gt 0 ]; then
  log_fail "A01" "${count}개의 클릭 가능한 div → <button> 또는 <a> 사용"
  A_FAIL=$((A_FAIL + 1))
else
  log_pass "A01" "클릭 가능한 div 없음"
fi

# A20: outline 제거 (대체 포커스 없음)
count=$({ grep -rn 'outline-none\|outline:\s*none\|outline:\s*0' \
  --include="*.tsx" --include="*.css" "$PROJECT_DIR" 2>/dev/null || true; } \
  | { grep -v 'node_modules\|focus-visible\|ring-\|focus:ring' || true; } | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
  log_fail "A20" "${count}개의 outline 제거 (대체 포커스 스타일 없음)"
  A_FAIL=$((A_FAIL + 1))
else
  log_pass "A20" "outline 제거 없음 또는 대체 포커스 있음"
fi

# A25: sticky/fixed 요소 + scroll-padding 확인
sticky_count=$(count_grep 'sticky\|position:\s*sticky\|position:\s*fixed' \
  --include="*.tsx" --include="*.css" "$PROJECT_DIR")
scroll_pad_count=$(count_grep 'scroll-padding' \
  --include="*.css" --include="*.tsx" "$PROJECT_DIR")
if [ "$sticky_count" -gt 0 ] && [ "$scroll_pad_count" -eq 0 ]; then
  log_warn "A25" "sticky/fixed 요소 있지만 scroll-padding-top 미설정 → 포커스 가려짐 위험 (WCAG 2.4.11)"
  A_WARN=$((A_WARN + 1))
else
  log_pass "A25" "포커스 가려짐 방지 확인됨"
fi

# A35: img alt 누락
count=$(grep -rn '<img\b' --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
  | grep -v 'node_modules\|alt=' | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
  log_fail "A35" "${count}개의 <img>에 alt 속성 누락"
  A_FAIL=$((A_FAIL + 1))
else
  log_pass "A35" "모든 <img>에 alt 있음"
fi

# A38: 자동재생 미디어
count=$(count_grep '<video\b.*autoPlay\b' --include="*.tsx" "$PROJECT_DIR")
muted_count=$(count_grep '<video\b.*autoPlay\b.*muted' --include="*.tsx" "$PROJECT_DIR")
auto_no_muted=$((count - muted_count))
if [ "$auto_no_muted" -gt 0 ]; then
  log_fail "A38" "${auto_no_muted}개의 autoPlay 비디오에 muted 없음"
  A_FAIL=$((A_FAIL + 1))
else
  log_pass "A38" "자동재생 미디어 없음 또는 muted 처리됨"
fi

# ─── 2. 폼 검사 ────────────────────────────────────
log_section "2. 폼 (Forms)"

# F01: input에 label 연결
input_without_id=$(grep -rn '<input\b' --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
  | grep -v 'node_modules\|id=\|aria-label\|aria-labelledby' | wc -l | tr -d ' ')
if [ "$input_without_id" -gt 0 ]; then
  log_warn "F01" "${input_without_id}개의 input에 id/aria-label 없음 → label 연결 확인"
  F_WARN=$((F_WARN + 1))
else
  log_pass "F01" "input label 연결 양호"
fi

# F02: placeholder 전용 input
placeholder_count=$(count_grep 'placeholder=' --include="*.tsx" "$PROJECT_DIR")
label_count=$(count_grep 'htmlFor=\|aria-label=' --include="*.tsx" "$PROJECT_DIR")
if [ "$placeholder_count" -gt 0 ] && [ "$label_count" -eq 0 ]; then
  log_fail "F02" "placeholder만 있고 label/aria-label 없음 → 접근성 위반"
  F_FAIL=$((F_FAIL + 1))
else
  log_pass "F02" "label 또는 aria-label 사용 확인"
fi

# F10-F15: autocomplete 설정
input_count=$(count_grep '<input' --include="*.tsx" "$PROJECT_DIR")
auto_count=$(count_grep 'autoComplete=\|autocomplete=' --include="*.tsx" "$PROJECT_DIR")
if [ "$input_count" -gt 5 ] && [ "$auto_count" -eq 0 ]; then
  log_warn "F13" "${input_count}개의 input에 autocomplete 미설정"
  F_WARN=$((F_WARN + 1))
else
  log_pass "F10-F15" "autocomplete 사용 (${auto_count}개)"
fi

# F22: aria-invalid 연결
error_inputs=$(count_grep 'aria-invalid' --include="*.tsx" "$PROJECT_DIR")
if [ "$input_count" -gt 5 ] && [ "$error_inputs" -eq 0 ]; then
  log_warn "F22" "aria-invalid 미사용 → 폼 에러 접근성 개선 필요"
  F_WARN=$((F_WARN + 1))
else
  log_pass "F22" "aria-invalid 사용 확인"
fi

# ─── 3. 애니메이션 검사 ────────────────────────────
log_section "3. 애니메이션 & 모션"

# M01: prefers-reduced-motion
anim_count=$(count_grep 'transition\|animation\|@keyframes' \
  --include="*.css" --include="*.tsx" "$PROJECT_DIR")
motion_count=$(count_grep 'prefers-reduced-motion' \
  --include="*.css" --include="*.tsx" "$PROJECT_DIR")
if [ "$anim_count" -gt 0 ] && [ "$motion_count" -eq 0 ]; then
  log_fail "M01" "애니메이션 ${anim_count}개 있지만 prefers-reduced-motion 미지원"
  M_FAIL=$((M_FAIL + 1))
else
  log_pass "M01" "prefers-reduced-motion 지원 (${motion_count}개)"
fi

# M02: transition: all
count=$(count_grep 'transition:\s*all\|transition-property:\s*all\|transition-\[all\]' \
  --include="*.css" --include="*.tsx" "$PROJECT_DIR")
if [ "$count" -gt 0 ]; then
  log_warn "M02" "${count}개의 transition: all → 명시적 속성 지정 권장"
  M_WARN=$((M_WARN + 1))
else
  log_pass "M02" "transition: all 없음"
fi

# ─── 4. 색상 & 테마 검사 ───────────────────────────
log_section "4. 색상 & 테마 (다크모드 포함)"

# C06/C11: prefers-color-scheme + Tailwind dark:
darkmode_count=$(count_grep 'prefers-color-scheme\|dark:' \
  --include="*.css" --include="*.tsx" "$PROJECT_DIR")
if [ "$darkmode_count" -eq 0 ]; then
  log_fail "C11" "다크모드 지원 없음 → prefers-color-scheme 또는 Tailwind dark: 추가"
  C_FAIL=$((C_FAIL + 1))
else
  log_pass "C11" "다크모드 지원 (${darkmode_count}개 선언)"
fi

# C08: color-scheme CSS 속성
cs_count=$(count_grep 'color-scheme' --include="*.css" --include="*.tsx" "$PROJECT_DIR")
if [ "$cs_count" -eq 0 ]; then
  log_warn "C08" ":root { color-scheme: light dark } 미선언"
  C_WARN=$((C_WARN + 1))
else
  log_pass "C08" "color-scheme 선언 확인"
fi

# C10: 밝은 로고 다크모드 처리 (SVG/PNG 이미지에 dark: 여부)
logo_count=$(count_grep 'logo\|Logo' --include="*.tsx" "$PROJECT_DIR")
logo_dark_count=$(count_grep 'logo.*dark:\|dark:.*logo\|Logo.*dark:\|dark:.*Logo' \
  --include="*.tsx" "$PROJECT_DIR")
if [ "$logo_count" -gt 0 ] && [ "$logo_dark_count" -eq 0 ]; then
  log_warn "C10" "로고 이미지의 다크모드 대응 확인 필요 (밝은 로고 + 어두운 배경)"
  C_WARN=$((C_WARN + 1))
fi

# ─── 5. 성능 검사 ──────────────────────────────────
log_section "5. 성능 (Performance + Core Web Vitals)"

# P12: 이미지 width/height 없음 (CLS)
img_count=$(count_grep '<img\b\|<Image\b' --include="*.tsx" "$PROJECT_DIR")
img_wh=$(count_grep '<img\b.*width=\|<Image\b.*width=' --include="*.tsx" "$PROJECT_DIR")
if [ "$img_count" -gt 0 ] && [ "$img_wh" -eq 0 ]; then
  log_warn "P12" "이미지에 width/height 없음 → CLS(레이아웃 이동) 발생 위험"
  P_WARN=$((P_WARN + 1))
else
  log_pass "P12" "이미지 width/height 설정 확인"
fi

# P14: next/image sizes 속성
next_img=$(count_grep 'next/image\|from.*next/image' --include="*.tsx" "$PROJECT_DIR")
next_img_sizes=$(count_grep '<Image.*sizes=' --include="*.tsx" "$PROJECT_DIR")
if [ "$next_img" -gt 0 ] && [ "$next_img_sizes" -eq 0 ]; then
  log_warn "P14" "next/image 사용 중이지만 sizes 속성 미설정"
  P_WARN=$((P_WARN + 1))
else
  log_pass "P14" "next/image sizes 설정 확인"
fi

# P24: barrel file 감지
barrel_count=$(grep -rn "export.*from './" \
  --include="index.ts" --include="index.tsx" "$PROJECT_DIR" 2>/dev/null \
  | grep -v 'node_modules' | wc -l | tr -d ' ')
if [ "$barrel_count" -gt 3 ]; then
  log_warn "P24" "barrel file(index.ts) ${barrel_count}개 재수출 → 직접 임포트로 번들 최적화"
  P_WARN=$((P_WARN + 1))
else
  log_pass "P24" "barrel file 사용 적정"
fi

# P10: font-display 설정
font_face=$(count_grep '@font-face' --include="*.css" --include="*.tsx" "$PROJECT_DIR")
font_display=$(count_grep 'font-display' --include="*.css" "$PROJECT_DIR")
if [ "$font_face" -gt 0 ] && [ "$font_display" -eq 0 ]; then
  log_warn "P10" "@font-face에 font-display: swap 미설정 → FOUT 발생 가능"
  P_WARN=$((P_WARN + 1))
else
  log_pass "P10" "font-display 설정 확인"
fi

# ─── 6. React/Next.js 및 RSC 검사 ─────────────────
log_section "6. React/Next.js & RSC"

# R10: key prop index 사용
key_index=$(count_grep 'key={index}\|key={i}\|key={idx}' --include="*.tsx" "$PROJECT_DIR")
if [ "$key_index" -gt 0 ]; then
  log_warn "R10" "${key_index}개의 key={index} 사용 → 고유 ID 사용 권장"
  R_WARN=$((R_WARN + 1))
else
  log_pass "R10" "key prop 패턴 양호"
fi

# R14: 불필요한 use client (상태/이벤트 없는 파일)
use_client_files=$(grep -rln '"use client"' --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
  | grep -v 'node_modules' || true)
unnecessary_use_client=0
for f in $use_client_files; do
  if ! grep -qE 'useState|useEffect|useCallback|useRef|onClick|onChange|onSubmit|onFocus|onBlur' "$f" 2>/dev/null; then
    echo -e "  ${YELLOW}→${NC} $f (상태/이벤트 없음)"
    unnecessary_use_client=$((unnecessary_use_client + 1))
  fi
done
if [ "$unnecessary_use_client" -gt 0 ]; then
  log_warn "R14" "${unnecessary_use_client}개 파일에 불필요한 'use client' 선언"
  R_WARN=$((R_WARN + 1))
else
  log_pass "R14" "use client 선언 적절"
fi

# R15: Server Component 내 브라우저 API
browser_api_in_server=0
tsx_files=$(find "$PROJECT_DIR" -name "*.tsx" -not -path "*/node_modules/*" 2>/dev/null || true)
for f in $tsx_files; do
  if ! grep -q '"use client"' "$f" 2>/dev/null; then
    if grep -qE 'window\.|document\.|localStorage\.|sessionStorage\.' "$f" 2>/dev/null; then
      echo -e "  ${RED}→${NC} $f"
      browser_api_in_server=$((browser_api_in_server + 1))
    fi
  fi
done
if [ "$browser_api_in_server" -gt 0 ]; then
  log_fail "R15" "${browser_api_in_server}개 Server Component에서 브라우저 API 접근"
  R_FAIL=$((R_FAIL + 1))
else
  log_pass "R15" "Server Component 내 브라우저 API 없음"
fi

# ─── 7. Tailwind CSS 검사 ──────────────────────────
log_section "7. Tailwind CSS"

# TW01: arbitrary px value
count=$(grep -rn '\-\[[0-9]*px\]\|\-\[[0-9.]*rem\]' \
  --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
  | grep -v 'node_modules' | wc -l | tr -d ' ')
if [ "$count" -gt 5 ]; then
  log_warn "TW01" "arbitrary value ${count}개 → 테마 토큰 사용 권장"
  TW_WARN=$((TW_WARN + 1))
else
  log_pass "TW01" "arbitrary value 사용 적정 (${count}개)"
fi

# TW03: 하드코딩 hex 색상
count=$(grep -rn 'bg-\[#\|text-\[#\|border-\[#\|fill-\[#' \
  --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
  | grep -v 'node_modules' | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
  log_warn "TW03" "하드코딩 hex 색상 ${count}개 → CSS 변수/의미론적 토큰 사용"
  TW_WARN=$((TW_WARN + 1))
else
  log_pass "TW03" "하드코딩 색상 없음"
fi

# TW04: 색상 클래스에 dark: 대응 누락
color_no_dark=$(grep -rn 'className=' --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
  | grep -E 'bg-(white|gray|black|slate|zinc|neutral|stone)' \
  | grep -v 'dark:' | grep -v 'node_modules' | wc -l | tr -d ' ')
if [ "$color_no_dark" -gt 3 ]; then
  log_warn "TW04" "색상 클래스 ${color_no_dark}개에 dark: variant 없음"
  TW_WARN=$((TW_WARN + 1))
else
  log_pass "TW04" "dark: variant 사용 확인"
fi

# TW05: outline-none 단독 사용
count=$(grep -rn 'outline-none\|focus:outline-none' --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
  | grep -v 'node_modules\|focus-visible\|ring' | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
  log_fail "TW05" "${count}개의 outline-none에 focus-visible/ring 대체 없음"
  TW_FAIL=$((TW_FAIL + 1))
else
  log_pass "TW05" "outline-none 대체 포커스 확인"
fi

# ─── 8. 안티패턴 검사 ──────────────────────────────
log_section "8. 안티패턴"

# X01: user-scalable=no
count=$(count_grep 'user-scalable.*no\|user-scalable=no' \
  --include="*.tsx" --include="*.html" "$PROJECT_DIR")
if [ "$count" -gt 0 ]; then
  log_fail "X01" "user-scalable=no 발견 → 접근성 위반"
  X_FAIL=$((X_FAIL + 1))
else
  log_pass "X01" "user-scalable=no 없음"
fi

# X02: maximum-scale=1
count=$(count_grep 'maximum-scale.*1\b' --include="*.tsx" --include="*.html" "$PROJECT_DIR")
if [ "$count" -gt 0 ]; then
  log_fail "X02" "maximum-scale=1 발견 → 접근성 위반"
  X_FAIL=$((X_FAIL + 1))
else
  log_pass "X02" "maximum-scale 제한 없음"
fi

# X06: !important 과용
count=$(count_grep '!important' --include="*.css" --include="*.tsx" "$PROJECT_DIR")
if [ "$count" -gt 5 ]; then
  log_warn "X06" "!important ${count}회 사용 → 5회 이하 권장"
  X_WARN=$((X_WARN + 1))
else
  log_pass "X06" "!important 사용 적정 (${count}회)"
fi

# X07: z-index 과용
count=$(grep -rn 'z-index:\s*[0-9]\{4,\}\|z-\[9[0-9]\{2,\}\]' \
  --include="*.css" --include="*.tsx" "$PROJECT_DIR" 2>/dev/null \
  | grep -v 'node_modules' | wc -l | tr -d ' ')
if [ "$count" -gt 0 ]; then
  log_warn "X07" "z-index 9999+ ${count}개 → z-index 관리 체계 필요"
  X_WARN=$((X_WARN + 1))
fi

# ─── 요약 대시보드 ─────────────────────────────────
calc_score() {
  local fail=$1
  local warn=$2
  local total=${3:-10}
  if [ "$total" -eq 0 ]; then echo "N/A"; return; fi
  local score=$(( (total * 100 - fail * 100 - warn * 50) / total ))
  [ "$score" -lt 0 ] && score=0
  echo "${score}%"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "감사 완료 보고서"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DASHBOARD="
## 감사 결과 요약

| 카테고리 | FAIL | WARN | 점수 |
|----------|:----:|:----:|:----:|
| 접근성 (A) | $A_FAIL | $A_WARN | $(calc_score $A_FAIL $A_WARN 5) |
| 폼 (F) | $F_FAIL | $F_WARN | $(calc_score $F_FAIL $F_WARN 4) |
| 애니메이션 (M) | $M_FAIL | $M_WARN | $(calc_score $M_FAIL $M_WARN 2) |
| 색상/테마 (C) | $C_FAIL | $C_WARN | $(calc_score $C_FAIL $C_WARN 3) |
| 성능 (P) | $P_FAIL | $P_WARN | $(calc_score $P_FAIL $P_WARN 4) |
| React/RSC (R) | $R_FAIL | $R_WARN | $(calc_score $R_FAIL $R_WARN 3) |
| Tailwind (TW) | $TW_FAIL | $TW_WARN | $(calc_score $TW_FAIL $TW_WARN 4) |
| 안티패턴 (X) | $X_FAIL | $X_WARN | $(calc_score $X_FAIL $X_WARN 3) |
| **총합** | **$TOTAL_FAIL** | **$TOTAL_WARN** | |

점수 = (PASS + WARN×0.5) / 총 검사 항목 × 100
"

echo "$DASHBOARD"
echo "$DASHBOARD" >> "$REPORT_FILE"

# 상태 판정
if [ "$TOTAL_FAIL" -eq 0 ] && [ "$TOTAL_WARN" -eq 0 ]; then
  echo -e "${GREEN}✓ 모든 검사 통과${NC}"
  echo "Status: PASS" >> "$REPORT_FILE"
elif [ "$TOTAL_FAIL" -eq 0 ]; then
  echo -e "${YELLOW}⚠ FAIL 없음, WARN ${TOTAL_WARN}건 확인 권장${NC}"
  echo "Status: WARN ($TOTAL_WARN warnings)" >> "$REPORT_FILE"
else
  echo -e "${RED}✗ FAIL ${TOTAL_FAIL}건 즉시 수정 필요${NC}"
  echo "Status: FAIL ($TOTAL_FAIL errors, $TOTAL_WARN warnings)" >> "$REPORT_FILE"
fi

echo ""
echo "보고서: $REPORT_FILE"
echo ""

# CI 연동: FAIL 수를 종료 코드로 반환 (0 = 성공)
exit $TOTAL_FAIL
