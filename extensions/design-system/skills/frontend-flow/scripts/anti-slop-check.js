#!/usr/bin/env node
// P4 기계적 anti-slop 단언. DESIGN.md 브랜드 토큰이 일반 금지 규칙을 무효화한다.
// Usage: node anti-slop-check.js <targetRoot> [designMdPath]
const fs = require('fs');
const path = require('path');

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
if (designMdPath && fs.existsSync(designMdPath)) {
  const dm = fs.readFileSync(designMdPath, 'utf8').toLowerCase();
  brandFonts = FORBIDDEN_FONTS.filter((f) => dm.includes(f.toLowerCase()));
  // F-J05 (audit R10): 승인 신호는 순수검정 hex 명시로 한정. 산문 "black"(예: "never
  // use black" 같은 금지 문장)까지 승인으로 오인하던 경로 제거 — brand-override 거짓승인 차단.
  brandAllowsBlack = /#000000|#000\b/.test(dm);
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

const checks = [];
const record = (id, ok, detail) => checks.push({ id, status: ok ? 'pass' : 'fail', detail });

// 1. em-dash 금지 (—) — 브랜드 무관 항상 적용
const emDashes = (corpus.match(/—/g) || []).length;
record('em-dash-ban', emDashes === 0, `em-dash count = ${emDashes}`);

// 2. 금지 폰트 — 브랜드 승인분 양보
const foundFonts = FORBIDDEN_FONTS
  .filter((f) => new RegExp(`\\b${f.replace(/ /g, '[ _-]?')}\\b`, 'i').test(corpus))
  .filter((f) => !brandFonts.includes(f));
record('forbidden-font', foundFonts.length === 0,
  foundFonts.length ? `not-brand-approved: ${foundFonts.join(', ')}` : 'none');

// 3. 순수 검정 금지 — 브랜드 승인 시 양보
// F-J06 (audit R10): hex 뿐 아니라 tailwind 순수검정 유틸 클래스도 탐지 (고정 스택에서 더 흔함).
const pureBlack = /#000000|#000\b/i.test(corpus)
  || /\b(?:bg|text|border|ring|fill|stroke)-black\b/.test(corpus);
record('pure-black-ban', !pureBlack || brandAllowsBlack,
  pureBlack ? (brandAllowsBlack ? 'present-but-brand-approved' : 'pure black #000 present') : 'none');

const failed = checks.filter((c) => c.status === 'fail').length;
console.log(JSON.stringify({ target: targetRoot, checks, passed: checks.length - failed, failed }, null, 2));
process.exit(failed === 0 ? 0 : 1);
