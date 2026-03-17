/**
 * Phase 1: 디자인 토큰 자동 추출
 *
 * 참고 사이트에서 Playwright로 전체 CSS 토큰을 수집한다.
 * - 보정 계수 자동 산출 (Figma Sites 등 뷰포트 스케일링 대응)
 * - 색상, 타이포그래피, 간격, 보더, 그림자, 그라데이션, 필터, 트랜스폼, 애니메이션, CSS 변수 추출
 *
 * 사용법: URL과 PAGES 배열을 수정한 뒤 `node extract-tokens.js` 실행
 * 출력: tokens.json
 */

import { chromium } from 'playwright';
import fs from 'fs';

const URL = '<<URL>>';
const VIEWPORT = { width: 1366, height: 900 };
const TAILWIND_FONT_SCALE = [12, 14, 16, 18, 20, 24, 30, 36, 48, 60, 72, 96];
const PAGES = [
  // { name: 'dashboard', nav: 'Dashboard' },
  // ...
];

function autoCalcCorrectionFactor(fontSizes) {
  let bestFactor = 1.0, bestError = Infinity;
  for (let f = 1.0; f <= 1.3; f += 0.01) {
    const error = fontSizes.reduce((sum, fs) => {
      const corrected = fs * f;
      const nearest = TAILWIND_FONT_SCALE.reduce((a, b) =>
        Math.abs(b - corrected) < Math.abs(a - corrected) ? b : a);
      return sum + Math.abs(corrected - nearest);
    }, 0);
    if (error < bestError) { bestError = error; bestFactor = f; }
  }
  const factor = Math.round(bestFactor * 100) / 100;
  const confidence = factor >= 0.98 && factor <= 1.02 ? 'NONE' :
    bestError / fontSizes.length < 0.5 ? 'HIGH' : 'MEDIUM';
  return { factor, confidence };
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: VIEWPORT });
  await page.goto(URL, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(3000);

  const allFontSizes = [];
  const colorMap = new Map();
  const spacingSet = new Set();
  const radiusSet = new Set();
  const shadowSet = new Set();
  const textShadowSet = new Set();
  const gradientSet = new Set();
  const filterSet = new Set();
  const backdropFilterSet = new Set();
  const transformSet = new Set();
  const animationMap = new Map();
  const typoMap = new Map();

  for (const pg of [{ name: 'home', nav: null }, ...PAGES]) {
    if (pg.nav) {
      try {
        await page.locator(`text=${pg.nav}`).first().click({ timeout: 5000 });
        await page.waitForTimeout(2000);
      } catch { continue; }
    }

    const data = await page.evaluate(() => {
      const els = document.querySelectorAll('h1,h2,h3,h4,h5,h6,p,span,a,label,li,button,input,textarea,select,td,th,div,section,aside,header,main,nav,svg');
      const result = {
        fontSizes: [], colors: [], spacing: [], radius: [], shadows: [],
        textShadows: [], gradients: [], filters: [], backdropFilters: [],
        transforms: [], animations: [], typo: [],
      };

      for (const el of els) {
        const s = getComputedStyle(el);
        const rect = el.getBoundingClientRect();
        if (rect.width < 10 || rect.height < 5) continue;

        const fs = parseFloat(s.fontSize);
        if (fs > 0) result.fontSizes.push(fs);

        for (const c of [s.color, s.backgroundColor]) {
          if (c && c !== 'rgba(0, 0, 0, 0)') result.colors.push(c);
        }

        for (const v of [s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft,
          s.marginTop, s.marginRight, s.marginBottom, s.marginLeft, s.gap]) {
          const n = parseFloat(v);
          if (n > 0 && n < 200) result.spacing.push(`${n}px`);
        }

        if (s.borderRadius !== '0px') result.radius.push(s.borderRadius);
        if (s.boxShadow !== 'none') result.shadows.push(s.boxShadow);
        if (s.textShadow !== 'none') result.textShadows.push(s.textShadow);
        if (s.backgroundImage !== 'none' && s.backgroundImage.includes('gradient')) {
          result.gradients.push(s.backgroundImage);
        }
        if (s.filter !== 'none') result.filters.push(s.filter);
        if (s.backdropFilter !== 'none') result.backdropFilters.push(s.backdropFilter);
        if (s.transform !== 'none') result.transforms.push(s.transform);
        if (s.animationName !== 'none') {
          result.animations.push({
            name: s.animationName, duration: s.animationDuration,
            timingFunction: s.animationTimingFunction, iterationCount: s.animationIterationCount,
          });
        }

        const tag = el.tagName.toLowerCase();
        if (['h1','h2','h3','h4','h5','h6','p','span','a','label'].includes(tag)) {
          const family = s.fontFamily.split(',')[0].trim().replace(/['"]/g, '');
          const key = `${family}|${s.fontSize}|${s.fontWeight}|${s.fontStyle}|${s.lineHeight}|${s.letterSpacing}`;
          result.typo.push({ tag, key, fontFamily: family, fontSize: s.fontSize, fontWeight: s.fontWeight, fontStyle: s.fontStyle, lineHeight: s.lineHeight, letterSpacing: s.letterSpacing });
        }
      }
      return result;
    });

    allFontSizes.push(...data.fontSizes);
    data.colors.forEach(c => colorMap.set(c, (colorMap.get(c) || 0) + 1));
    data.spacing.forEach(s => spacingSet.add(s));
    data.radius.forEach(r => radiusSet.add(r));
    data.shadows.forEach(s => shadowSet.add(s));
    data.textShadows.forEach(s => textShadowSet.add(s));
    data.gradients.forEach(g => gradientSet.add(g));
    data.filters.forEach(f => filterSet.add(f));
    data.backdropFilters.forEach(f => backdropFilterSet.add(f));
    data.transforms.forEach(t => transformSet.add(t));
    data.animations.forEach(a => {
      if (!animationMap.has(a.name)) animationMap.set(a.name, a);
    });
    data.typo.forEach(t => {
      const existing = typoMap.get(t.key) || { ...t, count: 0 };
      existing.count++;
      typoMap.set(t.key, existing);
    });
  }

  // CSS 변수 추출
  const cssVariables = await page.evaluate(() => {
    const vars = { light: {}, dark: {} };
    // :root (light) 변수
    const rootStyles = getComputedStyle(document.documentElement);
    for (const prop of [...document.styleSheets].flatMap(s => {
      try { return [...s.cssRules]; } catch { return []; }
    }).filter(r => r.selectorText === ':root' || r.selectorText === '.light')
      .flatMap(r => [...r.style])) {
      if (prop.startsWith('--')) {
        vars.light[prop] = rootStyles.getPropertyValue(prop).trim();
      }
    }
    // .dark 변수
    for (const rule of [...document.styleSheets].flatMap(s => {
      try { return [...s.cssRules]; } catch { return []; }
    }).filter(r => r.selectorText === '.dark')) {
      for (const prop of [...rule.style]) {
        if (prop.startsWith('--')) {
          vars.dark[prop] = rule.style.getPropertyValue(prop).trim();
        }
      }
    }
    return vars;
  });

  const { factor, confidence } = autoCalcCorrectionFactor([...new Set(allFontSizes)]);

  const tokens = {
    meta: {
      url: URL,
      extractedAt: new Date().toISOString(),
      viewport: VIEWPORT,
      correctionFactor: factor,
      confidence,
    },
    tokens: {
      colors: [...colorMap.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 30)
        .map(([value, count]) => ({ value, count })),
      typography: Object.fromEntries(
        [...typoMap.values()]
          .sort((a, b) => b.count - a.count)
          .slice(0, 15)
          .map(t => [t.tag, {
            fontFamily: t.fontFamily,
            fontSize: `${Math.round(parseFloat(t.fontSize) * factor)}px`,
            fontWeight: t.fontWeight,
            fontStyle: t.fontStyle !== 'normal' ? t.fontStyle : undefined,
            lineHeight: `${Math.round(parseFloat(t.lineHeight) * factor)}px`,
            letterSpacing: t.letterSpacing,
            rawFontSize: t.fontSize,
            count: t.count,
          }])
      ),
      spacing: {
        baseUnit: '4px',
        scale: [...spacingSet]
          .map(v => Math.round(parseFloat(v) * factor))
          .filter((v, i, a) => a.indexOf(v) === i)
          .sort((a, b) => a - b)
          .map(v => `${v}px`),
      },
      borders: {
        radius: [...radiusSet]
          .map(v => `${Math.round(parseFloat(v) * factor)}px`)
          .filter((v, i, a) => a.indexOf(v) === i)
          .sort((a, b) => parseFloat(a) - parseFloat(b)),
      },
      shadows: [...shadowSet].slice(0, 5),
      textShadows: [...textShadowSet].slice(0, 5),
      gradients: [...gradientSet].slice(0, 10).map(g => ({ value: g })),
      filters: {
        filter: [...filterSet].slice(0, 5),
        backdropFilter: [...backdropFilterSet].slice(0, 5),
      },
      transforms: [...transformSet].slice(0, 10),
      animations: [...animationMap.values()].slice(0, 10),
      cssVariables,
    },
  };

  fs.writeFileSync('tokens.json', JSON.stringify(tokens, null, 2));
  console.log(`Correction Factor: ${factor} (${confidence})`);
  console.log(`Colors: ${tokens.tokens.colors.length}`);
  console.log(`Typography styles: ${Object.keys(tokens.tokens.typography).length}`);
  console.log(`Spacing scale: ${tokens.tokens.spacing.scale.join(', ')}`);
  console.log(`Border radius: ${tokens.tokens.borders.radius.join(', ')}`);
  console.log(`Gradients: ${tokens.tokens.gradients.length}`);
  console.log(`Filters: ${tokens.tokens.filters.filter.length} filter, ${tokens.tokens.filters.backdropFilter.length} backdrop`);
  console.log(`Transforms: ${tokens.tokens.transforms.length}`);
  console.log(`Animations: ${tokens.tokens.animations.length}`);
  console.log('Saved: tokens.json');

  await browser.close();
})().catch(console.error);
