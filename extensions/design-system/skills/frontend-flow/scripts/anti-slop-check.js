#!/usr/bin/env node
// P4 기계적 anti-slop 단언. DESIGN.md 브랜드 토큰이 일반 금지 규칙을 무효화한다.
// Usage: node anti-slop-check.js <targetRoot> [designMdPath]
const fs = require('fs');
const path = require('path');
const { extractAccents, bucketOf } = require(path.join(__dirname, 'color-utils.js'));

const [, , targetRoot, designMdPath] = process.argv;
if (!targetRoot) {
  console.error('usage: node anti-slop-check.js <targetRoot> [designMdPath]');
  process.exit(2);
}
if (!fs.existsSync(targetRoot)) {
  console.error(`target not found: ${targetRoot}`);
  process.exit(2);
}

// 브랜드 승인 신호 (금지 규칙 양보 근거)
const FORBIDDEN_FONTS = ['Inter', 'Fraunces', 'Instrument Serif'];
let brandFonts = [];
let brandAllowsBlack = false;
let brandBuckets = new Set(); // 브랜드 팔레트 hue 버킷 — sprawl 카운트에서 제외
let brandRaws = new Set();    // 브랜드 raw 색값 — 과포화 검사에서 제외
if (designMdPath && fs.existsSync(designMdPath)) {
  const dmRaw = fs.readFileSync(designMdPath, 'utf8');
  const dm = dmRaw.toLowerCase();
  brandFonts = FORBIDDEN_FONTS.filter((f) => dm.includes(f.toLowerCase()));
  // F-J05 (audit R10): 승인 신호는 순수검정 hex 명시로 한정. 산문 "black"(예: "never
  // use black" 같은 금지 문장)까지 승인으로 오인하던 경로 제거 — brand-override 거짓승인 차단.
  brandAllowsBlack = /#000000|#000\b/.test(dm);
  // 브랜드 우선: DESIGN.md에 명시된 색은 색상 WARN(single-accent/low-saturation)에서 양보.
  for (const a of extractAccents(dmRaw)) { brandBuckets.add(bucketOf(a.hue)); brandRaws.add(a.raw); }
}

// 대상 소스 수집
function walk(dir, acc) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { if (e.name !== 'node_modules') walk(p, acc); }
    else if (/\.(tsx|jsx|css|scss)$/.test(e.name)) acc.push(p);
  }
  return acc;
}
const files = fs.statSync(targetRoot).isDirectory() ? walk(targetRoot, []) : [targetRoot];
// F-J02 (audit R10): 스캔 대상 0개(비대상 확장자만)를 'clean'으로 오인 금지 — 커버리지 0과 통과 구분.
if (files.length === 0) {
  console.error(`no scannable source files under ${targetRoot}`);
  process.exit(2);
}
const corpus = files.map((f) => fs.readFileSync(f, 'utf8')).join('\n');

// v2.3.1: 주석 스트립 후 스캔 — 주석 속 패턴(em-dash·<section>·주석처리된 font 등) 오탐 방지.
// 블록 주석(JSX {/* */}, CSS /* */) 제거 + 라인 주석(//) 제거. 단 `://`·문자열 내 `//`(URL)은 보존.
const scan = corpus
  .replace(/\/\*[\s\S]*?\*\//g, ' ')
  .replace(/(^|[^:'"`])\/\/[^\n]*/gm, '$1');

const checks = [];
const record = (id, ok, detail) => checks.push({ id, status: ok ? 'pass' : 'fail', detail });

// 1. em-dash 금지 (—) — 브랜드 무관 항상 적용 (주석 제외)
const emDashes = (scan.match(/—/g) || []).length;
record('em-dash-ban', emDashes === 0, `em-dash count = ${emDashes}`);

// 2. 금지 폰트 — 브랜드 승인분 양보
const foundFonts = FORBIDDEN_FONTS
  .filter((f) => new RegExp(`\\b${f.replace(/ /g, '[ _-]?')}\\b`, 'i').test(scan))
  .filter((f) => !brandFonts.includes(f));
record('forbidden-font', foundFonts.length === 0,
  foundFonts.length ? `not-brand-approved: ${foundFonts.join(', ')}` : 'none');

// 3. 순수 검정 금지 — 브랜드 승인 시 양보
// F-J06 (audit R10): hex 뿐 아니라 tailwind 순수검정 유틸 클래스도 탐지 (고정 스택에서 더 흔함).
const pureBlack = /#000000|#000\b/i.test(scan)
  || /\b(?:bg|text|border|ring|fill|stroke)-black\b/.test(scan);
record('pure-black-ban', !pureBlack || brandAllowsBlack,
  pureBlack ? (brandAllowsBlack ? 'present-but-brand-approved' : 'pure black #000 present') : 'none');

// ── 구조적 WARN 체크 (비게이팅) — 결정론적 카운팅만. exit code 불변(WARN은 exit 0 유지).
// 판단·문맥(single-accent/low-saturation/editorial-warm)은 에이전트 리뷰로 위임(references/anti-slop-preflight.md).
const warn = (id, clean, detail) => checks.push({ id, status: clean ? 'pass' : 'warn', detail });

// 4. radius-system (규칙3): 반경 체계 일관 + SaaS 카드 조합. WARN.
//    브랜드 반경 스케일 파싱은 v1 범위 밖 — 비게이팅이라 FP 비용 낮음.
const radii = new Set();
for (const m of scan.matchAll(/\brounded(?:-(sm|md|lg|xl|2xl|3xl))?\b/g)) {
  radii.add(m[1] || 'DEFAULT'); // full/none은 열거 목록 밖 → 자동 제외(스케일 아님)
}
for (const m of scan.matchAll(/\brounded-\[[^\]]+\]/g)) radii.add(m[0]);
for (const m of scan.matchAll(/border-radius:\s*([^;{}]+)/gi)) radii.add(m[1].trim());
const hasXl = /\brounded-xl\b/.test(scan) || /border-radius:\s*12px/i.test(scan);
// v2.3.1: 좌측 보더 '폭' 유틸(border-l, border-l-0/2/4/8)만 매칭. 색상 유틸(border-l-zinc-200 등)은
// 실제 보더 폭이 0이라 제외 — R9 FP 수정. 뒤에 -<영문/추가하이픈>이 오면(=색상) 매칭 안 함.
const hasLeftBorder = /\bborder-l(?:-(?:0|2|4|8))?(?![\w-])/.test(scan) || /border-left:\s*\d+px\s+solid/i.test(scan);
const saasCombo = hasXl && hasLeftBorder;
const radiusClean = radii.size <= 2 && !saasCombo;
warn('radius-system', radiusClean, radiusClean
  ? `radius scale=${radii.size}, no SaaS-card combo`
  : [radii.size > 2 ? `distinct radius=${radii.size} (>2)` : null, saasCombo ? 'rounded-xl+border-left combo' : null].filter(Boolean).join('; '));

// 5. eyebrow-density (규칙8 스케일 감각): eyebrow ≤ ceil(sectionCount/3). WARN.
//    section 0개면 밀도 정의 불가 → N/A(pass)로 FP 방지.
// v2.3.1: eyebrow 신호를 파일 단위로 판정 — `uppercase`가 있는 className 개수를,
//    파일에 `tracking-wid*`가 존재할 때 eyebrow로 카운트. uppercase/tracking이 별도
//    className으로 쪼개진 cn() 패턴(E7 FN)도 포착.
const hasTracking = /\btracking-wid(?:e|er|est)\b/.test(scan);
let eyebrows = 0;
if (hasTracking) {
  for (const m of scan.matchAll(/class(?:Name)?\s*=\s*(?:"([^"]*)"|'([^']*)'|\{\s*`([^`]*)`)/g)) {
    const cls = m[1] || m[2] || m[3] || '';
    if (/\buppercase\b/.test(cls)) eyebrows++;
  }
}
const sections = (scan.match(/<section\b/gi) || []).length;
const budget = Math.ceil(sections / 3);
const eyebrowClean = sections === 0 || eyebrows <= budget;
warn('eyebrow-density', eyebrowClean, sections === 0
  ? 'no <section> (N/A)'
  : `eyebrow=${eyebrows}, budget=ceil(${sections}/3)=${budget}`);

// 6·7. 색상 WARN — 유색 액센트 추출(hex·oklch·tailwind). 브랜드(DESIGN.md) 색은 양보.
const accents = extractAccents(scan);

// 6. single-accent (규칙7): 색상 난립. hue 버킷 >3(sprawl) 또는 한 버킷 raw >3(near-dup 토큰 미추출). WARN.
//    브랜드 팔레트 버킷은 sprawl 카운트에서 제외.
const srcBuckets = new Set(accents.map((a) => bucketOf(a.hue)).filter((b) => !brandBuckets.has(b)));
const rawByBucket = {};
for (const a of accents) {
  if (a.kind === 'tw' || brandRaws.has(a.raw)) continue; // tailwind shade=토큰, 브랜드색=양보
  const b = bucketOf(a.hue);
  (rawByBucket[b] = rawByBucket[b] || new Set()).add(a.raw);
}
const sprawl = srcBuckets.size > 3;
const nearDup = Object.entries(rawByBucket).find(([, s]) => s.size > 3);
const accentClean = !sprawl && !nearDup;
warn('single-accent', accentClean, accentClean
  ? `accent hue buckets=${srcBuckets.size}`
  : [sprawl ? `hue sprawl=${srcBuckets.size} (>3)` : null,
     nearDup ? `bucket ${nearDup[0]}: ${nearDup[1].size} near-dup values (>3)` : null].filter(Boolean).join('; '));

// 7. low-saturation (규칙7): 과포화 액센트. hex HSL S≥90 또는 oklch chroma≥0.25 = 네온. tailwind 면제(curated). WARN.
//    브랜드 명시 색은 양보.
const oversaturated = accents.filter((a) => !brandRaws.has(a.raw)
  && ((a.kind === 'hex' && a.sat >= 90) || (a.kind === 'oklch' && a.sat >= 0.25)));
const satClean = oversaturated.length === 0;
warn('low-saturation', satClean, satClean
  ? 'no over-saturated accent'
  : `over-saturated: ${oversaturated.slice(0, 3).map((a) => a.raw).join(', ')}`);

const failed = checks.filter((c) => c.status === 'fail').length;
const warned = checks.filter((c) => c.status === 'warn').length;
const passed = checks.filter((c) => c.status === 'pass').length;
console.log(JSON.stringify({ target: targetRoot, checks, passed, warned, failed }, null, 2));
process.exit(failed === 0 ? 0 : 1); // WARN은 exit code에 영향 없음 — failed만 게이팅
