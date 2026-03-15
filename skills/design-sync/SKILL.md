---
name: design-sync
description: 참고 디자인 URL에서 CSS를 추출하여 현재 코드베이스와 비교/적용한다
argument-hint: <URL> [페이지경로]
---

참고 디자인 URL을 받아 5단계 체계적 워크플로우로 CSS를 추출·비교·적용하고, 정량적 싱크율로 검증한다.

**사용법:**
- `/design-sync <URL>` — 전체 워크플로우 실행
- `/design-sync <URL> <페이지경로>` — 특정 페이지만
- `/design-sync --verify-only` — 시각적 회귀 테스트만
- `/design-sync --tokens-only` — 토큰 추출만

## 핵심 원칙

**1. 모든 요소를 동일한 깊이로 추출한다.**

| # | 카테고리 | 대상 요소 |
|---|---------|----------|
| 1 | **레이아웃** | `aside`, `header`, `main`, `nav`, 사이드바 전체 |
| 2 | **헤딩** | `h1`~`h5` — 페이지 제목, 카드 제목, 섹션 제목 |
| 3 | **텍스트/문단** | `p`, `span`, `label`, `li`, `a` — 부제, 설명, 배지, 링크 |
| 4 | **카드/컨테이너** | `div`(border/bg/rounded), `section` — stat card, 카드 래퍼 |
| 5 | **폼** | `input`, `select`, `button`, `textarea` — 검색, 필터, 액션 버튼 |
| 6 | **테이블** | `table`, `thead`, `tbody`, `tr`, `th`, `td` — 행·셀 단위 |

**2. 12개 속성 카테고리를 빠짐없이 추출한다.**

| # | 카테고리 | 속성 |
|---|---------|------|
| 1 | 셀렉터/클래스 | `tag.className` |
| 2 | 크기 | `width × height` |
| 3 | 색상 | `color`, `backgroundColor`, `opacity` |
| 4 | 서체 | `fontSize`, `fontWeight`, `lineHeight`, `letterSpacing` |
| 5 | 텍스트 | `textAlign`, `textTransform`, `textDecoration`, `whiteSpace`, `verticalAlign` |
| 6 | 패딩 | `padding` (4방향 축약) |
| 7 | 마진 | `margin` (4방향 축약) |
| 8 | 보더 | `border`, `borderRadius`, `outline` |
| 9 | 시각효과 | `boxShadow`, `backgroundImage` |
| 10 | 레이아웃 | `display`, `flex*`, `grid*`, `gap`, `position`, `overflow` |
| 11 | 인터랙션 | `cursor`, `transition` |
| 12 | 접근성 | Contrast ratio, accessible name, ARIA role, keyboard-focusable |

**3. 정량적 검증이 필수다.** 수정 전후 싱크율을 측정하여 개선을 숫자로 확인한다.

**4. 보정 계수는 자동 산출한다.** 수동 계산 대신 통계적 최적화로 정확도를 높인다.

---

## 엔드투엔드 워크플로우

```
/design-sync https://example.site

Step 1 → 기준 측정    참고 + 로컬 스크린샷 비교 → "싱크율: 72.3%"
Step 2 → 토큰 추출    보정 계수 자동 산출 + 글로벌 토큰 JSON
Step 3 → 인벤토리     전체 페이지 원패스 추출 → 영역/타입별 분류
Step 4 → 매핑 + Diff  참고 요소 ↔ 코드베이스 매핑 → 변경 제안
Step 5 → 수정 적용    파일별 × 카테고리별 수정, tsc+test 검증
Step 6 → 최종 검증    다시 스크린샷 비교 → "싱크율: 94.7%"
Step 7 → 학습 + 정리  90%↑ 시 패턴 저장, 임시 파일 삭제
```

---

## Phase 1: 디자인 토큰 자동 추출

### 1.1 보정 계수 자동 산출

Figma Sites 등 뷰포트 스케일링이 적용된 사이트에서 정확한 CSS 값을 얻기 위한 자동 보정.

**알고리즘:**
1. 모든 텍스트 요소의 `fontSize`를 수집
2. Tailwind 스케일 `[12, 14, 16, 18, 20, 24, 30, 36, 48, 60, 72, 96]`과 대조
3. 보정 계수 1.00~1.30을 0.01 단위로 시도
4. 보정 후 Tailwind 스케일과의 편차 합이 **최소**인 계수 선택
5. 계수가 0.98~1.02이면 "보정 불필요", 그 외 계수와 신뢰도 출력

### 1.2 글로벌 토큰 추출

| 토큰 | 추출 방법 |
|------|----------|
| **색상 팔레트** | 모든 고유 `color`/`bgColor` 수집 → 빈도순 정렬 → Tailwind 컬러 매칭 |
| **타이포그래피** | `fontSize`/`fontWeight`/`lineHeight` 조합별 사용 빈도 |
| **간격 체계** | `padding`/`margin`/`gap` 값 분포 → 베이스 유닛(보통 4px) 감지 |
| **보더** | `borderRadius` 패턴 (sm/md/lg/full) 정리 |
| **그림자** | `boxShadow` 고유 값 목록 |

### 1.3 토큰 출력 포맷

```json
{
  "meta": {
    "url": "https://example.site",
    "extractedAt": "2026-03-15T10:00:00Z",
    "viewport": { "width": 1366, "height": 900 },
    "correctionFactor": 1.14,
    "confidence": "HIGH",
    "framework": "shadcn-ui"
  },
  "tokens": {
    "colors": [
      { "value": "oklch(0.145 0 0)", "tailwind": "gray-900", "count": 42, "usage": "headings, body" },
      { "value": "oklch(0.556 0 0)", "tailwind": "gray-500", "count": 28, "usage": "descriptions" }
    ],
    "typography": {
      "h1": { "fontSize": "24px", "fontWeight": "500", "lineHeight": "32px" },
      "h2": { "fontSize": "20px", "fontWeight": "500", "lineHeight": "28px" },
      "body": { "fontSize": "14px", "fontWeight": "400", "lineHeight": "20px" },
      "caption": { "fontSize": "12px", "fontWeight": "500", "lineHeight": "16px" }
    },
    "spacing": {
      "baseUnit": "4px",
      "scale": ["4px", "8px", "12px", "16px", "24px", "32px", "48px"],
      "dominant": ["16px", "24px", "8px"]
    },
    "borders": {
      "default": { "width": "1px", "style": "solid", "color": "oklch(0.878 0 0)" },
      "radius": { "sm": "6px", "md": "8px", "lg": "12px", "full": "9999px" }
    },
    "shadows": ["0 1px 2px 0 rgba(0,0,0,0.05)", "0 4px 6px -1px rgba(0,0,0,0.1)"]
  }
}
```

### 1.4 스크립트 템플릿 A: extract-tokens.js

```javascript
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
  const typoMap = new Map();

  for (const pg of [{ name: 'home', nav: null }, ...PAGES]) {
    if (pg.nav) {
      try {
        await page.locator(`text=${pg.nav}`).first().click({ timeout: 5000 });
        await page.waitForTimeout(2000);
      } catch { continue; }
    }

    const data = await page.evaluate(() => {
      const els = document.querySelectorAll('h1,h2,h3,h4,h5,p,span,a,label,li,button,input,select,td,th,div,section');
      const result = { fontSizes: [], colors: [], spacing: [], radius: [], shadows: [], typo: [] };

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

        const tag = el.tagName.toLowerCase();
        if (['h1','h2','h3','h4','h5','p','span','a','label'].includes(tag)) {
          const key = `${s.fontSize}|${s.fontWeight}|${s.lineHeight}`;
          result.typo.push({ tag, key, fontSize: s.fontSize, fontWeight: s.fontWeight, lineHeight: s.lineHeight });
        }
      }
      return result;
    });

    allFontSizes.push(...data.fontSizes);
    data.colors.forEach(c => colorMap.set(c, (colorMap.get(c) || 0) + 1));
    data.spacing.forEach(s => spacingSet.add(s));
    data.radius.forEach(r => radiusSet.add(r));
    data.shadows.forEach(s => shadowSet.add(s));
    data.typo.forEach(t => {
      const existing = typoMap.get(t.key) || { ...t, count: 0 };
      existing.count++;
      typoMap.set(t.key, existing);
    });
  }

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
            fontSize: `${Math.round(parseFloat(t.fontSize) * factor)}px`,
            fontWeight: t.fontWeight,
            lineHeight: `${Math.round(parseFloat(t.lineHeight) * factor)}px`,
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
    },
  };

  fs.writeFileSync('tokens.json', JSON.stringify(tokens, null, 2));
  console.log(`Correction Factor: ${factor} (${confidence})`);
  console.log(`Colors: ${tokens.tokens.colors.length}`);
  console.log(`Typography styles: ${Object.keys(tokens.tokens.typography).length}`);
  console.log(`Spacing scale: ${tokens.tokens.spacing.scale.join(', ')}`);
  console.log(`Border radius: ${tokens.tokens.borders.radius.join(', ')}`);
  console.log('Saved: tokens.json');

  await browser.close();
})().catch(console.error);
```

---

## Phase 2: 전체 페이지 컴포넌트 인벤토리

### 2.1 원패스 전체 추출 전략

한 번의 Playwright 실행으로 모든 페이지를 순회하며 **모든 가시 요소**를 추출한다.
기존 6 카테고리 × 12 속성 포맷을 유지하되, 영역(sidebar/header/content)과 컴포넌트 타입을 자동 분류한다.

### 2.2 영역 자동 분류

레이아웃 랜드마크(sidebar, header)를 먼저 감지하고, 각 요소의 좌표로 영역을 분류:

```
x < sidebarRight                    → sidebar
y < headerBottom && x ≥ sidebarRight → header
그 외                                → content
```

랜드마크 감지: `position:fixed` + 좌측 200~280px 너비 → sidebar, 상단 40~80px 높이 → header

### 2.3 컴포넌트 타입 감지

| 신호 | 타입 |
|------|------|
| `table`, `thead`, `th`, `td` | table |
| `input`, `select`, `textarea` | form |
| `button` | button |
| `h1`~`h5` | heading |
| `nav` | navigation |
| `div`/`section` + border + bg + radius | card |
| `span`/`div` + inline + bgColor | badge |
| 그 외 `p`, `span`, `a`, `label` | text |

### 2.4 스크립트 템플릿 B: extract-inventory.js

```javascript
import { chromium } from 'playwright';
import fs from 'fs';

const URL = '<<URL>>';
const VIEWPORT = { width: 1366, height: 900 };
const CORRECTION = <<FACTOR>>; // Phase 1에서 산출한 값
const PAGES = [
  // { name: 'dashboard', nav: 'Dashboard' },
];

function shorten4(t, r, b, l) {
  if (t === r && r === b && b === l) return t;
  if (t === b && l === r) return `${t} ${r}`;
  return `${t} ${r} ${b} ${l}`;
}

const extractAll = (CORRECTION) => {
  // 랜드마크 감지
  const allDivs = [...document.querySelectorAll('div')];
  let sidebarRight = 0, headerBottom = 0;

  for (const d of allDivs) {
    const cs = getComputedStyle(d);
    const r = d.getBoundingClientRect();
    if (cs.position === 'fixed' && r.left < 5 && r.width > 150 && r.width < 300 && r.height > 400) {
      sidebarRight = r.right;
    }
  }
  for (const d of allDivs) {
    const r = d.getBoundingClientRect();
    if (r.left >= sidebarRight && r.top < 10 && r.height > 30 && r.height < 80 && r.width > 500) {
      headerBottom = r.bottom;
      break;
    }
  }

  function classifyArea(rect) {
    if (rect.left < sidebarRight) return 'sidebar';
    if (rect.top < headerBottom && rect.left >= sidebarRight) return 'header';
    return 'content';
  }

  function classifyType(tag, el, cs) {
    if (['table','thead','tbody','tr','th','td'].includes(tag)) return 'table';
    if (['input','select','textarea'].includes(tag)) return 'form';
    if (tag === 'button') return 'button';
    if (/^h[1-5]$/.test(tag)) return 'heading';
    if (tag === 'nav') return 'navigation';
    if ((tag === 'div' || tag === 'section') &&
        (cs.borderWidth !== '0px' || cs.boxShadow !== 'none') &&
        (cs.backgroundColor !== 'rgba(0, 0, 0, 0)' || cs.borderRadius !== '0px')) return 'card';
    if ((tag === 'span' || tag === 'div') &&
        cs.display.includes('inline') &&
        cs.backgroundColor !== 'rgba(0, 0, 0, 0)') return 'badge';
    return 'text';
  }

  // 접근성 헬퍼
  function parseRGB(c) {
    const m = c.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
    return m ? { r: +m[1], g: +m[2], b: +m[3] } : null;
  }
  function luminance(rgb) {
    return [rgb.r, rgb.g, rgb.b].map(c => {
      c = c / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }).reduce((acc, v, i) => acc + [0.2126, 0.7152, 0.0722][i] * v, 0);
  }
  function contrastRatio(fg, bg) {
    const l1 = luminance(fg), l2 = luminance(bg);
    return ((Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)).toFixed(2);
  }
  function accessibleName(el) {
    return el.getAttribute('aria-label')
      || el.getAttribute('title')
      || (el.tagName === 'INPUT' ? el.placeholder : '')
      || (el.textContent || '').trim().substring(0, 30) || '';
  }
  function implicitRole(tag) {
    const roles = { th:'columnheader', td:'cell', button:'button', a:'link',
      nav:'navigation', main:'main', header:'banner', aside:'complementary',
      h1:'heading', h2:'heading', h3:'heading', h4:'heading', h5:'heading',
      input:'textbox', select:'combobox', textarea:'textbox' };
    return roles[tag] || '';
  }

  const selectors = 'h1,h2,h3,h4,h5,p,span,a,label,li,table,thead,tbody,tr,th,td,input,select,button,textarea,nav,aside,header,main,section';
  const cardSelector = 'div[class*="border"],div[class*="bg-"],div[class*="rounded"]';
  const allEls = [...document.querySelectorAll(selectors), ...document.querySelectorAll(cardSelector)];

  const seen = new Set();
  const items = [];

  for (const el of allEls) {
    const tag = el.tagName.toLowerCase();
    const text = (el.innerText || '').trim().substring(0, 50);
    const rect = el.getBoundingClientRect();
    if (rect.width < 10 || rect.height < 5) continue;

    // 중복 필터
    const key = `${tag}:${text || (el.className?.toString() || '').substring(0, 40)}`;
    if (seen.has(key)) continue;
    seen.add(key);

    const s = getComputedStyle(el);
    const area = classifyArea(rect);
    const type = classifyType(tag, el, s);

    // 배경색 체인 탐색
    let bgColor = s.backgroundColor;
    let parent = el;
    while (bgColor === 'rgba(0, 0, 0, 0)' && parent.parentElement) {
      parent = parent.parentElement;
      bgColor = getComputedStyle(parent).backgroundColor;
    }
    const fgP = parseRGB(s.color), bgP = parseRGB(bgColor);
    const cr = fgP && bgP ? contrastRatio(fgP, bgP) : null;

    items.push({
      area, type, tag,
      text: text.substring(0, 40),
      selector: `${tag}.${(el.className || '').toString().split(/\s+/).filter(Boolean).join('.')}`.substring(0, 120),
      dimensions: `${(rect.width * CORRECTION).toFixed(0)} × ${(rect.height * CORRECTION).toFixed(0)}`,
      color: s.color,
      bgColor: s.backgroundColor,
      opacity: s.opacity !== '1' ? s.opacity : '',
      fontSize: `${(parseFloat(s.fontSize) * CORRECTION).toFixed(0)}px`,
      fontWeight: s.fontWeight,
      lineHeight: `${(parseFloat(s.lineHeight) * CORRECTION).toFixed(0)}px`,
      letterSpacing: s.letterSpacing,
      textAlign: s.textAlign !== 'start' ? s.textAlign : '',
      textTransform: s.textTransform !== 'none' ? s.textTransform : '',
      whiteSpace: s.whiteSpace !== 'normal' ? s.whiteSpace : '',
      verticalAlign: s.verticalAlign !== 'baseline' ? s.verticalAlign : '',
      padding: shorten4(s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft),
      margin: shorten4(s.marginTop, s.marginRight, s.marginBottom, s.marginLeft),
      border: s.borderWidth !== '0px' ? `${s.borderWidth} ${s.borderStyle} ${s.borderColor}` : 'none',
      borderRadius: s.borderRadius !== '0px' ? s.borderRadius : '',
      boxShadow: s.boxShadow !== 'none' ? s.boxShadow.substring(0, 80) : '',
      display: s.display,
      alignItems: s.alignItems !== 'normal' ? s.alignItems : '',
      justifyContent: s.justifyContent !== 'normal' ? s.justifyContent : '',
      gap: s.gap !== 'normal' ? s.gap : '',
      position: s.position !== 'static' ? s.position : '',
      cursor: s.cursor !== 'auto' ? s.cursor : '',
      transition: s.transitionProperty !== 'all' && s.transitionProperty !== 'none'
        ? `${s.transitionProperty} ${s.transitionDuration}` : '',
      contrast: cr,
      contrastPass: cr ? parseFloat(cr) >= 4.5 : null,
      name: accessibleName(el),
      role: el.getAttribute('role') || implicitRole(tag),
      keyboardFocusable: el.tabIndex >= 0 || ['a','button','input','select','textarea'].includes(tag),
    });
  }
  return { items, landmarks: { sidebarRight, headerBottom } };
};

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: VIEWPORT });
  await page.goto(URL, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(3000);

  const inventory = { pages: {} };

  for (const pg of [{ name: 'home', nav: null }, ...PAGES]) {
    if (pg.nav) {
      try {
        await page.locator(`text=${pg.nav}`).first().click({ timeout: 5000 });
        await page.waitForTimeout(2000);
      } catch { console.error(`[SKIP] ${pg.name}`); continue; }
    }

    const { items, landmarks } = await page.evaluate(extractAll, CORRECTION);

    // 영역 > 타입별 분류
    const classified = {};
    for (const item of items) {
      if (!classified[item.area]) classified[item.area] = {};
      if (!classified[item.area][item.type]) classified[item.area][item.type] = [];
      classified[item.area][item.type].push(item);
    }

    inventory.pages[pg.name] = classified;

    // 콘솔 요약
    console.log(`\n=== ${pg.name.toUpperCase()} ===`);
    console.log(`  Landmarks: sidebar→${landmarks.sidebarRight}px, header→${landmarks.headerBottom}px`);
    for (const [area, types] of Object.entries(classified)) {
      const counts = Object.entries(types).map(([t, arr]) => `${t}:${arr.length}`).join(', ');
      console.log(`  ${area}: ${counts}`);
    }
  }

  fs.writeFileSync('inventory.json', JSON.stringify(inventory, null, 2));
  console.log('\nSaved: inventory.json');
  await browser.close();
})().catch(console.error);
```

---

## Phase 3: 시각적 회귀 테스트

### 3.1 기준 스크린샷 캡처

참고 사이트와 로컬 개발 서버 양쪽을 동일 뷰포트(1366×900)로 캡처한다.
CSS 애니메이션을 비활성화하여 결정론적 스크린샷을 확보한다.

### 3.2 pixelmatch 비교

- `threshold: 0.15` — 폰트 렌더링, 서브픽셀 차이 허용
- `includeAA: false` — 안티앨리어싱 픽셀 자동 무시
- 이미지 크기 불일치 시 작은 쪽에 맞춰 crop

### 3.3 싱크율 계산

```
싱크율 = (1 - 불일치픽셀수 / 전체픽셀수) × 100
```

페이지별 싱크율 + 전체 평균 싱크율을 출력한다.

### 3.4 스크립트 템플릿 C: visual-regression.js

```javascript
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
})().catch(console.error);
```

---

## Phase 4: 컴포넌트 매핑 + 자동 Diff

### 4.1 참고 요소 ↔ 코드베이스 매핑

다중 시그널로 매핑:

| 시그널 | 가중치 | 예시 |
|--------|--------|------|
| 영역 위치 | 0.4 | sidebar → `layout/sidebar.tsx` |
| 요소 tag/role | 0.3 | `table` → `ui/data-table.tsx` |
| Tailwind 클래스 겹침 | 0.2 | `rounded-lg border` → 특정 컴포넌트 |
| 텍스트 유사도 | 0.1 | "Dashboard" → NavItem |

2개 이상 시그널 매칭 시 자동 매핑. 모호하면 사용자에게 확인.

### 4.2 Tailwind 클래스 리졸버

CSS computed value → Tailwind 클래스 자동 변환:

```javascript
const TAILWIND_MAP = {
  fontSize: {
    '12px': 'text-xs', '14px': 'text-sm', '16px': 'text-base',
    '18px': 'text-lg', '20px': 'text-xl', '24px': 'text-2xl',
    '30px': 'text-3xl', '36px': 'text-4xl',
  },
  fontWeight: {
    '100': 'font-thin', '300': 'font-light', '400': 'font-normal',
    '500': 'font-medium', '600': 'font-semibold', '700': 'font-bold',
  },
  borderRadius: {
    '0px': 'rounded-none', '4px': 'rounded-sm', '6px': 'rounded-md',
    '8px': 'rounded-lg', '12px': 'rounded-xl', '16px': 'rounded-2xl',
    '9999px': 'rounded-full',
  },
  spacing: (px) => {
    const rem = parseFloat(px) / 4;
    const map = { 0:'0', 1:'1', 2:'2', 3:'3', 4:'4', 5:'5', 6:'6', 8:'8',
      10:'10', 12:'12', 16:'16', 20:'20', 24:'24' };
    return map[rem] || `[${px}]`;
  },
};
```

### 4.3 자동 변경 제안 출력 포맷

```
┌─── src/components/layout/sidebar.tsx ───────────────────────┐
│ Line 40: className="...w-52..."                             │
│   width: 208px → 224px                                      │
│   제안: w-52 → w-56                                         │
│                                                              │
│ Line 41: className="...px-6..."                              │
│   padding-left: 24px → 16px                                  │
│   제안: px-6 → px-4                                          │
└──────────────────────────────────────────────────────────────┘
```

### 4.4 스크립트 템플릿 D: component-map.js

```javascript
import fs from 'fs';
import path from 'path';

const INVENTORY_PATH = 'inventory.json';
const SRC_DIR = 'src/components';

// 영역 → 파일 매핑 (프로젝트별 수정 필요)
const AREA_FILE_MAP = {
  sidebar: ['layout/sidebar.tsx', 'layout/nav-item.tsx'],
  header: ['layout/header.tsx', 'layout/user-menu.tsx'],
  content: {
    card: ['ui/stat-card.tsx', 'dashboard/recent-tasks.tsx', 'dashboard/recent-work.tsx'],
    table: ['ui/data-table.tsx', 'employees/employee-table.tsx', 'tasks/task-table.tsx'],
    form: ['ui/form-field.tsx', 'employees/employee-filters.tsx', 'tasks/task-filters.tsx'],
    badge: ['ui/status-badge.tsx'],
    heading: [], // 페이지 파일에서 직접 사용
    button: [],
  },
};

const TAILWIND_MAP = {
  fontSize: { '12px':'text-xs', '14px':'text-sm', '16px':'text-base', '18px':'text-lg',
    '20px':'text-xl', '24px':'text-2xl', '30px':'text-3xl' },
  fontWeight: { '400':'font-normal', '500':'font-medium', '600':'font-semibold', '700':'font-bold' },
  borderRadius: { '4px':'rounded-sm', '6px':'rounded-md', '8px':'rounded-lg', '12px':'rounded-xl', '9999px':'rounded-full' },
};

function extractClassesFromFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');
  const results = [];

  lines.forEach((line, idx) => {
    const matches = [...line.matchAll(/className="([^"]+)"/g)];
    for (const m of matches) {
      results.push({ line: idx + 1, classes: m[1], raw: line.trim() });
    }
    // Template literal className
    const tmplMatches = [...line.matchAll(/className=\{`([^`]+)`\}/g)];
    for (const m of tmplMatches) {
      results.push({ line: idx + 1, classes: m[1], raw: line.trim() });
    }
  });

  return results;
}

function suggestChange(refValue, property) {
  const map = TAILWIND_MAP[property];
  if (!map) return null;
  return map[refValue] || null;
}

(async () => {
  const inventory = JSON.parse(fs.readFileSync(INVENTORY_PATH, 'utf-8'));
  const mapping = { mappings: [] };

  // 각 페이지의 각 영역 처리
  for (const [pageName, areas] of Object.entries(inventory.pages)) {
    for (const [area, types] of Object.entries(areas)) {
      for (const [type, elements] of Object.entries(types)) {
        // 대상 파일 찾기
        let targetFiles = [];
        if (area === 'sidebar' || area === 'header') {
          targetFiles = AREA_FILE_MAP[area] || [];
        } else {
          targetFiles = AREA_FILE_MAP.content?.[type] || [];
        }

        for (const relFile of targetFiles) {
          const filePath = path.join(SRC_DIR, relFile);
          if (!fs.existsSync(filePath)) continue;

          const fileClasses = extractClassesFromFile(filePath);
          const diffs = [];

          // 각 참고 요소의 CSS vs 파일의 클래스 비교
          for (const refEl of elements.slice(0, 5)) {
            for (const fc of fileClasses) {
              // fontSize 비교
              const refFS = refEl.fontSize;
              const twFS = TAILWIND_MAP.fontSize[refFS];
              if (twFS && !fc.classes.includes(twFS)) {
                const currentTW = Object.values(TAILWIND_MAP.fontSize).find(v => fc.classes.includes(v));
                if (currentTW && currentTW !== twFS) {
                  diffs.push({
                    line: fc.line,
                    property: 'fontSize',
                    reference: `${refFS} (${twFS})`,
                    current: currentTW,
                    suggestion: `${currentTW} → ${twFS}`,
                  });
                }
              }

              // fontWeight 비교
              const refFW = refEl.fontWeight;
              const twFW = TAILWIND_MAP.fontWeight[refFW];
              if (twFW && !fc.classes.includes(twFW)) {
                const currentTW = Object.values(TAILWIND_MAP.fontWeight).find(v => fc.classes.includes(v));
                if (currentTW && currentTW !== twFW) {
                  diffs.push({
                    line: fc.line,
                    property: 'fontWeight',
                    reference: `w:${refFW} (${twFW})`,
                    current: currentTW,
                    suggestion: `${currentTW} → ${twFW}`,
                  });
                }
              }
            }
          }

          if (diffs.length > 0) {
            mapping.mappings.push({
              page: pageName,
              area,
              type,
              file: filePath,
              diffs: diffs.filter((d, i, a) =>
                a.findIndex(x => x.line === d.line && x.property === d.property) === i),
            });
          }
        }
      }
    }
  }

  // 출력
  for (const m of mapping.mappings) {
    console.log(`\n┌─── ${m.file} (${m.page}/${m.area}/${m.type}) ${'─'.repeat(30)}`);
    for (const d of m.diffs) {
      console.log(`│ Line ${d.line}: ${d.property}`);
      console.log(`│   참고: ${d.reference}`);
      console.log(`│   현재: ${d.current}`);
      console.log(`│   제안: ${d.suggestion}`);
    }
    console.log('└' + '─'.repeat(60));
  }

  fs.writeFileSync('mapping.json', JSON.stringify(mapping, null, 2));
  console.log('\nSaved: mapping.json');
})().catch(console.error);
```

---

## Phase 5: 다중 사이트 학습

### 5.1 패턴 저장 포맷

싱크율 90% 이상 달성 시 결과를 저장하여 향후 재사용:

```
.claude/skills/design-sync/learned/
  {site-hash}/
    meta.json          # 사이트 메타 (URL, 날짜, 프레임워크, 싱크율)
    tokens.json        # 디자인 토큰
    inventory.json     # 컴포넌트 인벤토리
    mapping.json       # 컴포넌트 매핑
```

**meta.json 포맷:**
```json
{
  "url": "https://example.figma.site",
  "hash": "a1b2c3d4",
  "extractedAt": "2026-03-15T10:00:00Z",
  "correctionFactor": 1.14,
  "framework": "shadcn-ui",
  "syncRate": 94.7,
  "pages": ["dashboard", "employees", "tasks", "reports", "settings"]
}
```

### 5.2 프레임워크 자동 감지

클래스명 패턴으로 프레임워크를 식별:

| 프레임워크 | 식별 패턴 |
|-----------|----------|
| **Shadcn UI** | `bg-background`, `text-foreground`, `border-border`, `ring-ring` |
| **Figma Sites** | `css-` 접두사, 뷰포트 스케일링 |
| **Tailwind UI** | `divide-y`, `group-hover`, `focus-within` 조합 |
| **Plain Tailwind** | `text-gray-`, `bg-white`, `rounded-` (범용) |

### 5.3 크로스 사이트 패턴 재사용

동일 프레임워크의 이전 학습 데이터가 있으면:
- 보정 계수 초기값으로 사용 (계산 시간 단축)
- 컴포넌트 타입 감지 정확도 향상
- 알려진 quirk 자동 적용 (예: Figma Sites의 48px 상단 툴바)

---

## 규칙

- Playwright가 설치되어 있어야 한다 (`npx playwright install chromium`)
- `pixelmatch`와 `pngjs`가 devDependencies에 있어야 한다
- 추출 스크립트는 `scripts/` 에 임시 작성 → 완료 후 삭제
- 스크린샷/diff 이미지도 완료 후 삭제
- `tokens.json`, `inventory.json`, `mapping.json`은 작업 중 프로젝트 루트에 생성 → 완료 후 삭제 (학습 저장 시 `learned/`로 복사)
- 수정 후 반드시 `npx tsc --noEmit && npm test` 검증
- **6 카테고리 × 12 속성** 모두 동일 깊이로 추출·비교
- 시각적 회귀 테스트는 **수정 전후** 두 번 실행하여 개선을 정량화
- 로컬 개발 서버(`localhost:3000`)가 실행 중이어야 시각적 회귀 테스트 가능

## 부록: Tailwind CSS 4 값 매핑 테이블

### 폰트 크기
| CSS | Tailwind |
|-----|----------|
| 12px | text-xs |
| 14px | text-sm |
| 16px | text-base |
| 18px | text-lg |
| 20px | text-xl |
| 24px | text-2xl |
| 30px | text-3xl |
| 36px | text-4xl |

### 폰트 굵기
| CSS | Tailwind |
|-----|----------|
| 100 | font-thin |
| 300 | font-light |
| 400 | font-normal |
| 500 | font-medium |
| 600 | font-semibold |
| 700 | font-bold |
| 800 | font-extrabold |

### 간격 (padding/margin/gap)
| CSS | Tailwind |
|-----|----------|
| 0px | 0 |
| 4px | 1 |
| 8px | 2 |
| 12px | 3 |
| 16px | 4 |
| 20px | 5 |
| 24px | 6 |
| 32px | 8 |
| 40px | 10 |
| 48px | 12 |
| 64px | 16 |
| 96px | 24 |

### 보더 라운딩
| CSS | Tailwind |
|-----|----------|
| 0px | rounded-none |
| 2px | rounded-sm |
| 6px | rounded-md |
| 8px | rounded-lg |
| 12px | rounded-xl |
| 16px | rounded-2xl |
| 9999px | rounded-full |

### 색상 (gray 스케일 기준)
| CSS (oklch 근사) | Tailwind |
|-----------------|----------|
| oklch(0.985 0 0) | gray-50 |
| oklch(0.97 0 0) | gray-100 |
| oklch(0.922 0 0) | gray-200 |
| oklch(0.870 0 0) | gray-300 |
| oklch(0.707 0 0) | gray-400 |
| oklch(0.556 0 0) | gray-500 |
| oklch(0.439 0 0) | gray-600 |
| oklch(0.371 0 0) | gray-700 |
| oklch(0.269 0 0) | gray-800 |
| oklch(0.205 0 0) | gray-900 |
| oklch(0.145 0 0) | gray-950 |
