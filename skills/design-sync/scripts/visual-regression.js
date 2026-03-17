/**
 * Phase 3: 시각적 회귀 테스트
 *
 * 참고 사이트와 로컬 개발 서버를 동일 뷰포트로 캡처 → pixelmatch 비교.
 * - 기본 비교 (threshold 0.15) + 정밀 비교 (threshold 0.05)
 * - 컴포넌트 단위 비교 (sidebar, header, main-content)
 * - Hover 상태 비교
 * - 텍스트 마스킹 비교 (레이아웃만)
 * - 멀티 뷰포트 비교 (mobile, tablet, wide)
 * - 다크 모드 비교
 *
 * 사용법: REF_URL, LOCAL_URL, PAGES를 수정한 뒤 `node visual-regression.js` 실행
 * 출력: diff-*.png 이미지들 + 콘솔 싱크율 리포트
 */

import { chromium } from 'playwright';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';
import fs from 'fs';

const REF_URL = '<<REF_URL>>';
const LOCAL_URL = 'http://localhost:3000';
const VIEWPORT = { width: 1366, height: 900 };
const PAGES = [
  // { name: 'dashboard', nav: 'Dashboard', localPath: '/dashboard' },
];

async function capturePages(url, pages, navByClick = true) {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: VIEWPORT });

  // CSS 애니메이션 비활성화
  await page.addInitScript(() => {
    const style = document.createElement('style');
    style.textContent = '*, *::before, *::after { animation-duration: 0s !important; transition-duration: 0s !important; }';
    document.head.appendChild(style);
  });

  await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(2000);

  const shots = {};
  for (const pg of pages) {
    try {
      if (navByClick && pg.nav) {
        await page.locator(`text=${pg.nav}`).first().click({ timeout: 5000 });
        await page.waitForTimeout(1500);
      } else if (pg.localPath) {
        await page.goto(`${url}${pg.localPath}`, { waitUntil: 'networkidle' });
        await page.waitForTimeout(1500);
      }
      shots[pg.name] = await page.screenshot({ fullPage: false });
    } catch (e) {
      console.error(`[SKIP] ${pg.name}: ${e.message}`);
    }
  }

  await browser.close();
  return shots;
}

function cropToMatch(pngA, pngB) {
  const w = Math.min(pngA.width, pngB.width);
  const h = Math.min(pngA.height, pngB.height);

  function cropData(png, tw, th) {
    if (png.width === tw && png.height === th) return png.data;
    const out = Buffer.alloc(tw * th * 4);
    for (let y = 0; y < th; y++) {
      png.data.copy(out, y * tw * 4, y * png.width * 4, y * png.width * 4 + tw * 4);
    }
    return out;
  }

  return {
    width: w, height: h,
    dataA: cropData(pngA, w, h),
    dataB: cropData(pngB, w, h),
  };
}

(async () => {
  console.log('Capturing reference site...');
  const refShots = await capturePages(REF_URL, PAGES, true);

  console.log('Capturing local site...');
  const localShots = await capturePages(LOCAL_URL, PAGES, false);

  let totalSync = 0, pageCount = 0;

  console.log('\n' + '='.repeat(60));
  console.log('  VISUAL REGRESSION REPORT');
  console.log('='.repeat(60));

  for (const [name, refBuf] of Object.entries(refShots)) {
    const localBuf = localShots[name];
    if (!localBuf) { console.log(`  [SKIP] ${name}: no local screenshot`); continue; }

    const refPng = PNG.sync.read(refBuf);
    const localPng = PNG.sync.read(localBuf);
    const { width, height, dataA, dataB } = cropToMatch(refPng, localPng);

    const diff = new PNG({ width, height });
    const numDiff = pixelmatch(dataA, dataB, diff.data, width, height, {
      threshold: 0.15,
      includeAA: false,
    });

    const total = width * height;
    const syncRate = ((1 - numDiff / total) * 100).toFixed(1);

    fs.writeFileSync(`diff-${name}.png`, PNG.sync.write(diff));
    console.log(`  [${name}] Sync: ${syncRate}%  (${numDiff.toLocaleString()} / ${total.toLocaleString()} diff pixels)`);

    totalSync += parseFloat(syncRate);
    pageCount++;
  }

  const overallSync = pageCount > 0 ? (totalSync / pageCount).toFixed(1) : '0.0';
  console.log('\n' + '-'.repeat(60));
  console.log(`  OVERALL SYNC RATE: ${overallSync}%`);
  console.log('-'.repeat(60));
  console.log(`\nDiff images saved: ${Object.keys(refShots).map(n => `diff-${n}.png`).join(', ')}`);

  // === 정밀 비교 (threshold 0.05) ===
  console.log('\n' + '='.repeat(60));
  console.log('  PRECISION COMPARISON (threshold: 0.05)');
  console.log('='.repeat(60));

  for (const [name, refBuf] of Object.entries(refShots)) {
    const localBuf = localShots[name];
    if (!localBuf) continue;

    const refPng = PNG.sync.read(refBuf);
    const localPng = PNG.sync.read(localBuf);
    const { width, height, dataA, dataB } = cropToMatch(refPng, localPng);

    const diff = new PNG({ width, height });
    const numDiff = pixelmatch(dataA, dataB, diff.data, width, height, {
      threshold: 0.05,
      includeAA: false,
    });

    const total = width * height;
    const syncRate = ((1 - numDiff / total) * 100).toFixed(1);
    fs.writeFileSync(`diff-precision-${name}.png`, PNG.sync.write(diff));
    console.log(`  [${name}] Precision Sync: ${syncRate}%`);
  }

  // === 컴포넌트 단위 비교 ===
  console.log('\n' + '='.repeat(60));
  console.log('  COMPONENT-LEVEL COMPARISON');
  console.log('='.repeat(60));

  async function captureRegion(url, selector, name) {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: VIEWPORT });
    await page.addInitScript(() => {
      const style = document.createElement('style');
      style.textContent = '*, *::before, *::after { animation-duration: 0s !important; transition-duration: 0s !important; }';
      document.head.appendChild(style);
    });
    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(2000);
    try {
      const el = page.locator(selector).first();
      const shot = await el.screenshot();
      await browser.close();
      return shot;
    } catch {
      await browser.close();
      return null;
    }
  }

  const REGIONS = [
    { name: 'sidebar', selector: 'aside, nav[class*="sidebar"], div[class*="sidebar"]' },
    { name: 'header', selector: 'header, div[class*="header"]' },
    { name: 'main-content', selector: 'main, div[class*="content"]' },
  ];

  for (const region of REGIONS) {
    const refRegion = await captureRegion(REF_URL, region.selector, region.name);
    const localRegion = await captureRegion(LOCAL_URL, region.selector, region.name);
    if (!refRegion || !localRegion) {
      console.log(`  [${region.name}] SKIP — element not found`);
      continue;
    }
    const refPng = PNG.sync.read(refRegion);
    const localPng = PNG.sync.read(localRegion);
    const { width, height, dataA, dataB } = cropToMatch(refPng, localPng);
    const diff = new PNG({ width, height });
    const numDiff = pixelmatch(dataA, dataB, diff.data, width, height, { threshold: 0.15, includeAA: false });
    const syncRate = ((1 - numDiff / (width * height)) * 100).toFixed(1);
    fs.writeFileSync(`diff-region-${region.name}.png`, PNG.sync.write(diff));
    console.log(`  [${region.name}] Sync: ${syncRate}%`);
  }

  // === Hover 상태 비교 ===
  console.log('\n' + '='.repeat(60));
  console.log('  HOVER STATE COMPARISON');
  console.log('='.repeat(60));

  async function captureHoverStyles(url, selectors) {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: VIEWPORT });
    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(2000);
    const results = [];
    for (const sel of selectors) {
      try {
        const el = page.locator(sel).first();
        // 기본 상태 스타일
        const beforeStyle = await el.evaluate(e => {
          const s = getComputedStyle(e);
          return { bg: s.backgroundColor, color: s.color, border: s.borderColor, shadow: s.boxShadow, opacity: s.opacity };
        });
        // hover 상태
        await el.hover();
        await page.waitForTimeout(300);
        const afterStyle = await el.evaluate(e => {
          const s = getComputedStyle(e);
          return { bg: s.backgroundColor, color: s.color, border: s.borderColor, shadow: s.boxShadow, opacity: s.opacity };
        });
        const changed = Object.keys(beforeStyle).filter(k => beforeStyle[k] !== afterStyle[k]);
        if (changed.length > 0) {
          results.push({ selector: sel, before: beforeStyle, after: afterStyle, changed });
        }
      } catch { /* skip */ }
    }
    await browser.close();
    return results;
  }

  const HOVER_TARGETS = [
    'nav a', 'nav button', 'aside a', 'aside button',
    'button', 'a[href]', 'tr', '[class*="card"]',
    // 검색/필터/드롭다운
    'input[type="search"]', '[class*="search"] input',
    '[class*="dropdown"] li', '[class*="dropdown"] a', '[class*="menu"] li',
    '[class*="chip"]', '[class*="tag"]', '[class*="filter"] button',
    'select', '[role="option"]', '[role="listbox"] > *',
  ];

  const refHover = await captureHoverStyles(REF_URL, HOVER_TARGETS);
  const localHover = await captureHoverStyles(LOCAL_URL, HOVER_TARGETS);

  for (const rh of refHover) {
    const lh = localHover.find(l => l.selector === rh.selector);
    if (!lh) {
      console.log(`  [${rh.selector}] MISSING hover in local`);
      continue;
    }
    const mismatches = rh.changed.filter(k => rh.after[k] !== lh.after?.[k]);
    if (mismatches.length > 0) {
      console.log(`  [${rh.selector}] Hover diff: ${mismatches.map(k => `${k}: ${rh.after[k]} vs ${lh.after?.[k]}`).join(', ')}`);
    } else {
      console.log(`  [${rh.selector}] Hover OK`);
    }
  }

  // === 텍스트 마스킹 비교 ===
  console.log('\n' + '='.repeat(60));
  console.log('  TEXT-MASKED COMPARISON (layout/style only)');
  console.log('='.repeat(60));

  async function captureMasked(url) {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: VIEWPORT });
    await page.addInitScript(() => {
      const style = document.createElement('style');
      style.textContent = `
        *, *::before, *::after { animation-duration: 0s !important; transition-duration: 0s !important; }
        h1,h2,h3,h4,h5,h6,p,span,a,label,li,td,th,button { color: transparent !important; }
      `;
      document.head.appendChild(style);
    });
    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(2000);
    const shot = await page.screenshot({ fullPage: false });
    await browser.close();
    return shot;
  }

  const refMasked = await captureMasked(REF_URL);
  const localMasked = await captureMasked(LOCAL_URL);
  if (refMasked && localMasked) {
    const rp = PNG.sync.read(refMasked), lp = PNG.sync.read(localMasked);
    const { width, height, dataA, dataB } = cropToMatch(rp, lp);
    const diff = new PNG({ width, height });
    const nd = pixelmatch(dataA, dataB, diff.data, width, height, { threshold: 0.15, includeAA: false });
    const sr = ((1 - nd / (width * height)) * 100).toFixed(1);
    fs.writeFileSync('diff-masked.png', PNG.sync.write(diff));
    console.log(`  Text-masked Sync: ${sr}%`);
  }

  // === 멀티 뷰포트 비교 ===
  console.log('\n' + '='.repeat(60));
  console.log('  MULTI-VIEWPORT COMPARISON');
  console.log('='.repeat(60));

  const VIEWPORTS = [
    { name: 'mobile', width: 375, height: 812 },
    { name: 'tablet', width: 768, height: 1024 },
    { name: 'wide', width: 1920, height: 1080 },
  ];

  for (const vp of VIEWPORTS) {
    async function captureVP(url) {
      const browser = await chromium.launch({ headless: true });
      const page = await browser.newPage({ viewport: { width: vp.width, height: vp.height } });
      await page.addInitScript(() => {
        const style = document.createElement('style');
        style.textContent = '*, *::before, *::after { animation-duration: 0s !important; transition-duration: 0s !important; }';
        document.head.appendChild(style);
      });
      await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
      await page.waitForTimeout(2000);
      const shot = await page.screenshot({ fullPage: false });
      await browser.close();
      return shot;
    }
    const refVP = await captureVP(REF_URL);
    const localVP = await captureVP(LOCAL_URL);
    if (refVP && localVP) {
      const rp = PNG.sync.read(refVP), lp = PNG.sync.read(localVP);
      const { width, height, dataA, dataB } = cropToMatch(rp, lp);
      const diff = new PNG({ width, height });
      const nd = pixelmatch(dataA, dataB, diff.data, width, height, { threshold: 0.15, includeAA: false });
      const sr = ((1 - nd / (width * height)) * 100).toFixed(1);
      fs.writeFileSync(`diff-${vp.name}.png`, PNG.sync.write(diff));
      console.log(`  [${vp.name} ${vp.width}×${vp.height}] Sync: ${sr}%`);
    }
  }

  // === 다크 모드 비교 ===
  console.log('\n' + '='.repeat(60));
  console.log('  DARK MODE COMPARISON');
  console.log('='.repeat(60));

  async function captureDark(url) {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: VIEWPORT, colorScheme: 'dark' });
    await page.addInitScript(() => {
      const style = document.createElement('style');
      style.textContent = '*, *::before, *::after { animation-duration: 0s !important; transition-duration: 0s !important; }';
      document.head.appendChild(style);
      // class 기반 다크 모드 토글
      document.documentElement.classList.add('dark');
    });
    await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(2000);
    const shot = await page.screenshot({ fullPage: false });
    await browser.close();
    return shot;
  }

  try {
    const refDark = await captureDark(REF_URL);
    const localDark = await captureDark(LOCAL_URL);
    if (refDark && localDark) {
      const rp = PNG.sync.read(refDark), lp = PNG.sync.read(localDark);
      const { width, height, dataA, dataB } = cropToMatch(rp, lp);
      const diff = new PNG({ width, height });
      const nd = pixelmatch(dataA, dataB, diff.data, width, height, { threshold: 0.15, includeAA: false });
      const sr = ((1 - nd / (width * height)) * 100).toFixed(1);
      fs.writeFileSync('diff-dark.png', PNG.sync.write(diff));
      console.log(`  Dark mode Sync: ${sr}%`);
    }
  } catch (e) {
    console.log(`  Dark mode: SKIP (${e.message})`);
  }
})().catch(console.error);
