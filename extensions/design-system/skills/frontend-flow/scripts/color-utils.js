// color-utils.js — anti-slop 색상 WARN(single-accent/low-saturation)용 결정론적 파서.
// hex·oklch·tailwind 유색을 추출해 hue/채도로 변환. 중성색(회색/near-neutral)은 제외.
// 브라우저·의존성 없음. 순수 함수 → 단위 테스트 가능.

// Tailwind 색상군 → 대표 hue(도). 중성군(slate/gray/zinc/neutral/stone)은 제외 목록.
const TW_HUE = {
  red: 0, orange: 25, amber: 40, yellow: 50, lime: 85, green: 140, emerald: 155,
  teal: 175, cyan: 190, sky: 200, blue: 220, indigo: 245, violet: 260, purple: 275,
  fuchsia: 295, pink: 330, rose: 350,
};
const TW_NEUTRAL = new Set(['slate', 'gray', 'zinc', 'neutral', 'stone']);
const TW_PREFIX = 'bg|text|border|ring|fill|stroke|from|via|to|decoration|outline|accent|caret|divide|shadow';

function parseHex(hex) {
  let h = hex.replace('#', '');
  if (h.length === 3) h = h.split('').map((c) => c + c).join('');
  if (h.length !== 6) return null; // 8자리(alpha)는 앞 6자리만
  const r = parseInt(h.slice(0, 2), 16);
  const g = parseInt(h.slice(2, 4), 16);
  const b = parseInt(h.slice(4, 6), 16);
  if ([r, g, b].some(Number.isNaN)) return null;
  return { r, g, b };
}

function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h = 0;
  let s = 0;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h *= 60;
  }
  return { h, s: s * 100, l: l * 100 };
}

// 소스 텍스트 → 액센트 색 목록 [{hue, sat, kind, raw}]. 중성색은 걸러냄.
// sat 의미는 kind별: hex=HSL S(0~100), oklch=chroma 원값(0~0.4), tailwind=null(채도 검사 면제).
// 과포화 판정은 소비자(anti-slop-check.js)가 kind별 임계값으로 수행.
function extractAccents(text) {
  const accents = [];

  // 1. hex — #RGB / #RRGGBB / #RRGGBBAA(앞 6자리)
  for (const m of text.matchAll(/#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?(?:[0-9a-fA-F]{2})?\b/g)) {
    const rgb = parseHex(m[0]);
    if (!rgb) continue;
    const { h, s, l } = rgbToHsl(rgb.r, rgb.g, rgb.b);
    if (s < 10 || l < 6 || l > 96) continue; // near-neutral·순수흑백 제외
    accents.push({ hue: h, sat: s, kind: 'hex', raw: m[0].toLowerCase().slice(0, 7) });
  }

  // 2. oklch(L C H) — H를 hue로, C(chroma) 원값을 sat로
  for (const m of text.matchAll(/oklch\(\s*([\d.]+)%?\s+([\d.]+)\s+([\d.]+)/gi)) {
    const c = parseFloat(m[2]);
    const hue = parseFloat(m[3]);
    if (Number.isNaN(c) || Number.isNaN(hue)) continue;
    if (c < 0.04) continue; // near-neutral
    accents.push({ hue, sat: c, kind: 'oklch', raw: `oklch:${m[2]}:${m[3]}` });
  }

  // 3. tailwind 유틸 — {prefix}-{family}-{shade}. 중성군 제외. 채도 검사 면제(sat=null).
  const twRe = new RegExp(`\\b(?:${TW_PREFIX})-(${Object.keys(TW_HUE).concat([...TW_NEUTRAL]).join('|')})-(\\d{2,3})\\b`, 'g');
  for (const m of text.matchAll(twRe)) {
    const family = m[1];
    if (TW_NEUTRAL.has(family)) continue;
    accents.push({ hue: TW_HUE[family], sat: null, kind: 'tw', raw: `${family}-${m[2]}` });
  }

  return accents;
}

const bucketOf = (hue) => Math.floor(((hue % 360) + 360) % 360 / 30);

module.exports = { parseHex, rgbToHsl, extractAccents, bucketOf, TW_HUE };
