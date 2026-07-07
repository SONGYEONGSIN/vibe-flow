#!/bin/bash
# anti-slop-check.js smoke
# 실행: bash scripts/tests/frontend-flow-antislop-smoke.sh
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
JS="$REPO_ROOT/extensions/design-system/skills/frontend-flow/scripts/anti-slop-check.js"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

assert_exit() {
  if [ "$3" = "$2" ]; then echo "  ✓ $1 (exit $2)"; PASS=$((PASS+1));
  else echo "  ✗ $1 (expected $2, got $3)"; FAIL=$((FAIL+1)); fi
}
# jq -e 로 stdout JSON 필드를 검증 (여러 줄 grep 불가 → jq 사용)
assert_jq() {
  if echo "$3" | jq -e "$2" >/dev/null 2>&1; then echo "  ✓ $1"; PASS=$((PASS+1));
  else echo "  ✗ $1"; echo "    filter: '$2'"; echo "    actual:  '$3'"; FAIL=$((FAIL+1)); fi
}
status_of() { echo "$1" | jq -r --arg id "$2" '.checks[] | select(.id==$id) | .status'; }

# clean fixture — 위반 없음
printf 'export const H = () => <h1 className="font-geist text-zinc-900">Hi</h1>\n' > "$TMP/clean.tsx"
# dirty fixture — em-dash, Inter, #000
printf 'export const B = () => <p className="font-inter text-[#000000]">A \xe2\x80\x94 B</p>\n' > "$TMP/dirty.tsx"
# DESIGN.md — Inter/black 브랜드 승인
printf '# DESIGN\n- Body font: Inter\n- Text: #000000 (black)\n' > "$TMP/DESIGN.md"

echo "Test A1: clean → exit 0, failed=0"
OUT=$(node "$JS" "$TMP/clean.tsx" 2>/dev/null); EC=$?
assert_exit "clean-exit" "0" "$EC"
assert_jq "clean-failed0" '.failed == 0' "$OUT"

echo "Test A2: dirty (DESIGN.md 없음) → exit 1, em-dash·font 위반"
OUT=$(node "$JS" "$TMP/dirty.tsx" 2>/dev/null); EC=$?
assert_exit "dirty-exit" "1" "$EC"
[ "$(status_of "$OUT" em-dash-ban)" = "fail" ] && { echo "  ✓ dirty-emdash-fail"; PASS=$((PASS+1)); } || { echo "  ✗ dirty-emdash-fail"; FAIL=$((FAIL+1)); }
[ "$(status_of "$OUT" forbidden-font)" = "fail" ] && { echo "  ✓ dirty-font-fail"; PASS=$((PASS+1)); } || { echo "  ✗ dirty-font-fail"; FAIL=$((FAIL+1)); }

echo "Test A3: dirty + DESIGN.md(Inter/black 승인) → font·black 양보, em-dash만 실패 → exit 1"
OUT=$(node "$JS" "$TMP/dirty.tsx" "$TMP/DESIGN.md" 2>/dev/null); EC=$?
assert_exit "override-exit" "1" "$EC"
[ "$(status_of "$OUT" forbidden-font)" = "pass" ] && { echo "  ✓ override-font-pass"; PASS=$((PASS+1)); } || { echo "  ✗ override-font-pass"; FAIL=$((FAIL+1)); }
[ "$(status_of "$OUT" pure-black-ban)" = "pass" ] && { echo "  ✓ override-black-pass"; PASS=$((PASS+1)); } || { echo "  ✗ override-black-pass"; FAIL=$((FAIL+1)); }
[ "$(status_of "$OUT" em-dash-ban)" = "fail" ] && { echo "  ✓ override-emdash-still-fail"; PASS=$((PASS+1)); } || { echo "  ✗ override-emdash-still-fail"; FAIL=$((FAIL+1)); }

echo "Test A4: 인자 없음 → exit 2"
node "$JS" >/dev/null 2>&1; assert_exit "noarg-exit" "2" "$?"

echo "Test A5: 존재하지 않는 경로 → exit 2 (스택트레이스 아님)"
node "$JS" "$TMP/__nope__" >/dev/null 2>&1; assert_exit "missing-path-exit" "2" "$?"

# F-J02 (audit R10): 스캔 대상 0개(비대상 확장자만) → 커버리지 0을 clean 으로 오인하면 안 됨.
echo "Test A6: 비대상 corpus(.ts/.html 만) → exit 2 (빈 corpus 거짓PASS 아님)"
mkdir -p "$TMP/nocov"
printf 'export const x = 1\n' > "$TMP/nocov/util.ts"
printf '<!doctype html><body>hi</body>\n' > "$TMP/nocov/index.html"
node "$JS" "$TMP/nocov" >/dev/null 2>&1; assert_exit "empty-corpus-exit" "2" "$?"

# F-J05 (audit R10): DESIGN.md 산문 "black"(금지 문장)이 순수검정 승인으로 오인되면 안 됨.
echo "Test A7: DESIGN.md 'never use black'(hex 없음) + #000000 컴포넌트 → pure-black FAIL (거짓승인 아님)"
printf '# DESIGN\n- Rule: Never use pure black. Avoid black backgrounds.\n' > "$TMP/prose.md"
printf 'export const K = () => <div className="text-[#000000]">x</div>\n' > "$TMP/black.tsx"
OUT=$(node "$JS" "$TMP/black.tsx" "$TMP/prose.md" 2>/dev/null); EC=$?
assert_exit "prose-black-exit" "1" "$EC"
[ "$(status_of "$OUT" pure-black-ban)" = "fail" ] && { echo "  ✓ prose-black-not-approved"; PASS=$((PASS+1)); } || { echo "  ✗ prose-black-not-approved"; FAIL=$((FAIL+1)); }

# F-J06 (audit R10): tailwind 순수검정 유틸 클래스(hex 아님)도 탐지해야 함.
echo "Test A8: tailwind bg-black/text-black (hex 없음) → pure-black FAIL"
printf 'export const T = () => <div className="bg-black text-black">x</div>\n' > "$TMP/util.tsx"
OUT=$(node "$JS" "$TMP/util.tsx" 2>/dev/null); EC=$?
assert_exit "tw-black-exit" "1" "$EC"
[ "$(status_of "$OUT" pure-black-ban)" = "fail" ] && { echo "  ✓ tw-black-detected"; PASS=$((PASS+1)); } || { echo "  ✗ tw-black-detected"; FAIL=$((FAIL+1)); }

# ── 구조적 WARN 체크 (radius-system, eyebrow-density) — 비게이팅: exit 0 유지 ──
echo "Test A9: 반경 고유값 3개(sm/lg/xl) → radius-system WARN, exit 0(불변)"
printf 'export const R = () => <div className="rounded-sm"><span className="rounded-lg"><b className="rounded-xl">x</b></span></div>\n' > "$TMP/radius3.tsx"
OUT=$(node "$JS" "$TMP/radius3.tsx" 2>/dev/null); EC=$?
assert_exit "radius3-exit0" "0" "$EC"
[ "$(status_of "$OUT" radius-system)" = "warn" ] && { echo "  ✓ radius3-warn"; PASS=$((PASS+1)); } || { echo "  ✗ radius3-warn (got '$(status_of "$OUT" radius-system)')"; FAIL=$((FAIL+1)); }
assert_jq "radius3-failed0" '.failed == 0' "$OUT"
assert_jq "radius3-warned1" '.warned >= 1' "$OUT"

echo "Test A10: SaaS 카드 조합(rounded-xl + border-l) → radius-system WARN, exit 0"
printf 'export const C = () => <div className="rounded-xl border-l-4 border-zinc-200">card</div>\n' > "$TMP/saas.tsx"
OUT=$(node "$JS" "$TMP/saas.tsx" 2>/dev/null); EC=$?
assert_exit "saas-exit0" "0" "$EC"
[ "$(status_of "$OUT" radius-system)" = "warn" ] && { echo "  ✓ saas-combo-warn"; PASS=$((PASS+1)); } || { echo "  ✗ saas-combo-warn (got '$(status_of "$OUT" radius-system)')"; FAIL=$((FAIL+1)); }

echo "Test A11: eyebrow 2개 / section 1개(budget=1) → eyebrow-density WARN, exit 0"
printf 'export const E = () => <section><p className="uppercase tracking-wide text-xs">A</p><p className="uppercase tracking-widest">B</p></section>\n' > "$TMP/eyebrow.tsx"
OUT=$(node "$JS" "$TMP/eyebrow.tsx" 2>/dev/null); EC=$?
assert_exit "eyebrow-exit0" "0" "$EC"
[ "$(status_of "$OUT" eyebrow-density)" = "warn" ] && { echo "  ✓ eyebrow-warn"; PASS=$((PASS+1)); } || { echo "  ✗ eyebrow-warn (got '$(status_of "$OUT" eyebrow-density)')"; FAIL=$((FAIL+1)); }

echo "Test A12: no-FP(반경 md+full 1종, eyebrow 1/section 3) → 둘 다 pass, warned=0, exit 0"
printf 'export const G = () => (<div><div className="rounded-md rounded-full"/><section><span className="uppercase tracking-wide">E</span></section><section>b</section><section>c</section></div>)\n' > "$TMP/nofp.tsx"
OUT=$(node "$JS" "$TMP/nofp.tsx" 2>/dev/null); EC=$?
assert_exit "nofp-exit0" "0" "$EC"
[ "$(status_of "$OUT" radius-system)" = "pass" ] && { echo "  ✓ nofp-radius-pass"; PASS=$((PASS+1)); } || { echo "  ✗ nofp-radius-pass (got '$(status_of "$OUT" radius-system)')"; FAIL=$((FAIL+1)); }
[ "$(status_of "$OUT" eyebrow-density)" = "pass" ] && { echo "  ✓ nofp-eyebrow-pass"; PASS=$((PASS+1)); } || { echo "  ✗ nofp-eyebrow-pass (got '$(status_of "$OUT" eyebrow-density)')"; FAIL=$((FAIL+1)); }
assert_jq "nofp-warned0" '.warned == 0' "$OUT"

# ── v2.3.1 결함 회귀 (엣지테스트 발견분) ──
echo "Test A13: eyebrow uppercase/tracking 분리(cn 패턴) → eyebrow-density WARN (FN 수정)"
printf 'export const S = () => <section><span className="uppercase">A</span><span className="tracking-wide">B</span><span className="uppercase">C</span></section>\n' > "$TMP/split.tsx"
OUT=$(node "$JS" "$TMP/split.tsx" 2>/dev/null)
[ "$(status_of "$OUT" eyebrow-density)" = "warn" ] && { echo "  ✓ eyebrow-split-warn"; PASS=$((PASS+1)); } || { echo "  ✗ eyebrow-split-warn (got '$(status_of "$OUT" eyebrow-density)')"; FAIL=$((FAIL+1)); }

echo "Test A14: border-l 색상 유틸(border-l-zinc-200)+rounded-xl → SaaS combo 아님 → pass (FP 수정)"
printf 'export const C = () => <div className="rounded-xl border-l-zinc-200">x</div>\n' > "$TMP/blcolor.tsx"
OUT=$(node "$JS" "$TMP/blcolor.tsx" 2>/dev/null)
[ "$(status_of "$OUT" radius-system)" = "pass" ] && { echo "  ✓ border-l-color-pass"; PASS=$((PASS+1)); } || { echo "  ✗ border-l-color-pass (got '$(status_of "$OUT" radius-system)')"; FAIL=$((FAIL+1)); }
echo "Test A14b: border-l-4 폭 유틸+rounded-xl → 실제 SaaS combo → warn (TP 유지)"
printf 'export const W = () => <div className="rounded-xl border-l-4">x</div>\n' > "$TMP/blwidth.tsx"
OUT=$(node "$JS" "$TMP/blwidth.tsx" 2>/dev/null)
[ "$(status_of "$OUT" radius-system)" = "warn" ] && { echo "  ✓ border-l-width-warn"; PASS=$((PASS+1)); } || { echo "  ✗ border-l-width-warn (got '$(status_of "$OUT" radius-system)')"; FAIL=$((FAIL+1)); }

echo "Test A15: 주석 속 em-dash → em-dash-ban pass (주석 스트립). JSX 텍스트 em-dash는 계속 fail"
printf '// note \xe2\x80\x94 comment\nexport const M = () => <p>clean text</p>\n' > "$TMP/emcomment.tsx"
OUT=$(node "$JS" "$TMP/emcomment.tsx" 2>/dev/null); EC=$?
assert_exit "emcomment-exit0" "0" "$EC"
[ "$(status_of "$OUT" em-dash-ban)" = "pass" ] && { echo "  ✓ emdash-comment-pass"; PASS=$((PASS+1)); } || { echo "  ✗ emdash-comment-pass (got '$(status_of "$OUT" em-dash-ban)')"; FAIL=$((FAIL+1)); }

echo "Test A16: 주석 처리된 font-inter → forbidden-font pass (주석 스트립)"
printf 'export const F = () => <p className="font-geist">{/* use font-inter later */}x</p>\n' > "$TMP/fontcomment.tsx"
OUT=$(node "$JS" "$TMP/fontcomment.tsx" 2>/dev/null)
[ "$(status_of "$OUT" forbidden-font)" = "pass" ] && { echo "  ✓ font-comment-pass"; PASS=$((PASS+1)); } || { echo "  ✗ font-comment-pass (got '$(status_of "$OUT" forbidden-font)')"; FAIL=$((FAIL+1)); }

echo "Test A17: 주석 처리된 //-URL 미오손상 (https://) → 스캔 유지"
printf 'export const U = () => <a href="https://ex.com/rounded-xl">x</a>\n' > "$TMP/url.tsx"
node "$JS" "$TMP/url.tsx" >/dev/null 2>&1; assert_exit "url-noharm-exit0" "0" "$?"

# ── v2.3.2 색상 WARN 2종 (single-accent / low-saturation) ──
echo "Test A18: hue sprawl 4버킷(red/green/blue/yellow) → single-accent WARN, exit 0"
printf 'export const S = () => <div className="text-[#ff0000] text-[#00ff00] text-[#0000ff] text-[#ffff00]">x</div>\n' > "$TMP/sprawl.tsx"
OUT=$(node "$JS" "$TMP/sprawl.tsx" 2>/dev/null); EC=$?
assert_exit "sprawl-exit0" "0" "$EC"
[ "$(status_of "$OUT" single-accent)" = "warn" ] && { echo "  ✓ sprawl-warn"; PASS=$((PASS+1)); } || { echo "  ✗ sprawl-warn (got '$(status_of "$OUT" single-accent)')"; FAIL=$((FAIL+1)); }

echo "Test A19: 같은 버킷 파랑 4종(near-dup 토큰 미추출) → single-accent WARN"
printf 'export const B = () => <div className="text-[#2563eb] text-[#3b82f6] text-[#1d4ed8] text-[#1e40af]">x</div>\n' > "$TMP/neardup.tsx"
OUT=$(node "$JS" "$TMP/neardup.tsx" 2>/dev/null)
[ "$(status_of "$OUT" single-accent)" = "warn" ] && { echo "  ✓ neardup-warn"; PASS=$((PASS+1)); } || { echo "  ✗ neardup-warn (got '$(status_of "$OUT" single-accent)')"; FAIL=$((FAIL+1)); }

echo "Test A20: 액센트 2버킷(tailwind blue+emerald) → single-accent pass"
printf 'export const C = () => <div className="text-blue-600 text-emerald-500">x</div>\n' > "$TMP/twoaccent.tsx"
OUT=$(node "$JS" "$TMP/twoaccent.tsx" 2>/dev/null)
[ "$(status_of "$OUT" single-accent)" = "pass" ] && { echo "  ✓ two-accent-pass"; PASS=$((PASS+1)); } || { echo "  ✗ two-accent-pass (got '$(status_of "$OUT" single-accent)')"; FAIL=$((FAIL+1)); }

echo "Test A21: 네온 hex(#00ff00 S=100) → low-saturation WARN, exit 0"
printf 'export const N = () => <div className="text-[#00ff00]">x</div>\n' > "$TMP/neon.tsx"
OUT=$(node "$JS" "$TMP/neon.tsx" 2>/dev/null); EC=$?
assert_exit "neon-exit0" "0" "$EC"
[ "$(status_of "$OUT" low-saturation)" = "warn" ] && { echo "  ✓ neon-warn"; PASS=$((PASS+1)); } || { echo "  ✗ neon-warn (got '$(status_of "$OUT" low-saturation)')"; FAIL=$((FAIL+1)); }

echo "Test A22: 정상 브랜드 블루(#2563eb S=83<90) → low-saturation pass (FP 방지)"
printf 'export const V = () => <div className="text-[#2563eb]">x</div>\n' > "$TMP/brandblue.tsx"
OUT=$(node "$JS" "$TMP/brandblue.tsx" 2>/dev/null)
[ "$(status_of "$OUT" low-saturation)" = "pass" ] && { echo "  ✓ brand-blue-pass"; PASS=$((PASS+1)); } || { echo "  ✗ brand-blue-pass (got '$(status_of "$OUT" low-saturation)')"; FAIL=$((FAIL+1)); }

echo "Test A23: oklch 네온(chroma 0.28≥0.25) → low-saturation WARN"
printf 'export const O = () => <div style={{color:"oklch(0.7 0.28 25)"}}>x</div>\n' > "$TMP/oklch.tsx"
OUT=$(node "$JS" "$TMP/oklch.tsx" 2>/dev/null)
[ "$(status_of "$OUT" low-saturation)" = "warn" ] && { echo "  ✓ oklch-neon-warn"; PASS=$((PASS+1)); } || { echo "  ✗ oklch-neon-warn (got '$(status_of "$OUT" low-saturation)')"; FAIL=$((FAIL+1)); }

echo "Test A24: tailwind 유틸은 채도 검사 면제 → text-blue-600 low-saturation pass"
printf 'export const T = () => <div className="text-blue-600">x</div>\n' > "$TMP/twaccent.tsx"
OUT=$(node "$JS" "$TMP/twaccent.tsx" 2>/dev/null)
[ "$(status_of "$OUT" low-saturation)" = "pass" ] && { echo "  ✓ tw-exempt-pass"; PASS=$((PASS+1)); } || { echo "  ✗ tw-exempt-pass (got '$(status_of "$OUT" low-saturation)')"; FAIL=$((FAIL+1)); }

echo "Test A25: 브랜드 override — DESIGN.md에 4-hue 팔레트 명시 → 같은 색 sprawl pass"
printf '# DESIGN\n- Palette: #ff0000 #00ff00 #0000ff #ffff00\n' > "$TMP/palette.md"
OUT=$(node "$JS" "$TMP/sprawl.tsx" "$TMP/palette.md" 2>/dev/null)
[ "$(status_of "$OUT" single-accent)" = "pass" ] && { echo "  ✓ brand-palette-pass"; PASS=$((PASS+1)); } || { echo "  ✗ brand-palette-pass (got '$(status_of "$OUT" single-accent)')"; FAIL=$((FAIL+1)); }

echo "Test A26: 브랜드 override — DESIGN.md가 네온(#00ff00) 명시 → low-saturation pass"
printf '# DESIGN\n- Accent: #00ff00 (brand neon)\n' > "$TMP/neonbrand.md"
OUT=$(node "$JS" "$TMP/neon.tsx" "$TMP/neonbrand.md" 2>/dev/null)
[ "$(status_of "$OUT" low-saturation)" = "pass" ] && { echo "  ✓ brand-neon-pass"; PASS=$((PASS+1)); } || { echo "  ✗ brand-neon-pass (got '$(status_of "$OUT" low-saturation)')"; FAIL=$((FAIL+1)); }

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
