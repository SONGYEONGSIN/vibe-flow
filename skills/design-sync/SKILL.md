---
name: design-sync
description: 참고 디자인 URL 또는 캡처 이미지에서 CSS를 추출하여 현재 코드베이스와 비교/적용한다
argument-hint: <URL|이미지경로> [페이지경로]
---

참고 디자인 URL 또는 캡처 이미지를 받아 체계적 워크플로우로 CSS를 추출·비교·적용하고, 정량적 싱크율로 검증한다.

**사용법:**
- `/design-sync <URL>` — URL 기반 전체 워크플로우 실행 (7단계)
- `/design-sync <URL> <페이지경로>` — 특정 페이지만
- `/design-sync --from-image <이미지경로>` — 캡처 이미지 기반 워크플로우 (5단계)
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
| 6 | **검색/필터/드롭다운** | 검색 컨테이너(relative wrapper + 아이콘), 필터 바/칩, 커스텀 드롭다운 패널/아이템 |
| 7 | **테이블** | `table`, `thead`, `tbody`, `tr`, `th`, `td` — 행·셀 단위 |
| 8 | **아이콘** | `svg`, `img[src*=".svg"]`, Lucide/Heroicons 컴포넌트 — 크기, 색상, strokeWidth |

**2. 21개 속성 카테고리를 빠짐없이 추출한다.**

| # | 카테고리 | 속성 |
|---|---------|------|
| 1 | 셀렉터/클래스 | `tag.className` |
| 2 | 크기 | `width`, `height`, `minWidth`, `maxWidth`, `minHeight`, `maxHeight`, `aspectRatio` |
| 3 | 색상 | `color`, `backgroundColor`, `opacity` |
| 4 | 서체 | `fontFamily`, `fontSize`, `fontWeight`, `fontStyle`, `lineHeight`, `letterSpacing` |
| 5 | 텍스트 | `textAlign`, `textTransform`, `textDecoration`, `whiteSpace`, `verticalAlign`, `textOverflow`, `wordBreak`, `overflowWrap`, `textShadow` |
| 6 | 패딩 | `padding` (4방향 축약) |
| 7 | 마진 | `margin` (4방향 축약) |
| 8 | 보더 | `border`, `borderColor`, `borderWidth`, `borderRadius`, `outline`, `outlineOffset` |
| 9 | 시각효과 | `boxShadow`, `backgroundImage`(그라데이션), `filter`, `backdropFilter`, `mixBlendMode`, `clipPath` |
| 10 | 레이아웃 | `display`, `flexDirection`, `flexWrap`, `flexGrow/Shrink/Basis`, `alignItems`, `justifyContent`, `gridTemplateColumns/Rows`, `gridColumn/Row`, `placeItems`, `order`, `gap`, `position`, `overflow`, `zIndex`, `isolation`, `columns` |
| 11 | 포지셔닝 | `top`, `right`, `bottom`, `left`, `inset` |
| 12 | 트랜스폼 | `transform`, `transformOrigin` |
| 13 | 인터랙션 | `cursor`, `transition`, `transitionDuration`, `transitionTimingFunction`, `pointerEvents`, `userSelect`, `resize`, `scrollBehavior`, `scrollSnapType`, `scrollSnapAlign` |
| 14 | 이미지/미디어 | `objectFit`, `objectPosition` |
| 15 | 폼 스타일 | `appearance`, `accentColor`, `caretColor` |
| 16 | 접근성 | Contrast ratio, accessible name, ARIA role, keyboard-focusable, `visibility` |
| 17 | CSS 변수 | `--background`, `--foreground`, `--sidebar`, `--primary` 등 custom properties |
| 18 | 의사 요소 | `::before`, `::after` — content, 크기, 색상, 위치 |
| 19 | 선택 스타일 | `::selection` — color, backgroundColor |
| 20 | 아이콘 | `width`, `height`, `color`/`stroke`, `strokeWidth`, `fill` |
| 21 | 애니메이션 | `animationName`, `animationDuration`, `animationTimingFunction`, `animationIterationCount`, `listStyleType` |

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
| **타이포그래피** | `fontFamily`/`fontSize`/`fontWeight`/`fontStyle`/`lineHeight`/`letterSpacing` 조합별 사용 빈도 |
| **간격 체계** | `padding`/`margin`/`gap` 값 분포 → 베이스 유닛(보통 4px) 감지 |
| **보더** | `borderRadius` 패턴 (sm/md/lg/full), `outline` 스타일 정리 |
| **그림자** | `boxShadow`, `textShadow` 고유 값 목록 |
| **그라데이션** | `backgroundImage`에서 `linear-gradient`/`radial-gradient` 추출 → 빈도순 |
| **필터/효과** | `filter`, `backdropFilter` 고유 값 목록 (blur, brightness 등) |
| **트랜스폼** | `transform` 고유 패턴 (scale, rotate, translate) 수집 |
| **애니메이션** | `animationName`/`animationDuration`/`animationTimingFunction` 수집, `@keyframes` 규칙 추출 |
| **CSS 변수** | `:root`/`.dark`에 정의된 `--` custom properties 전체 수집 → 용도별 분류 |

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
      "h1": { "fontFamily": "Geist Sans", "fontSize": "24px", "fontWeight": "500", "lineHeight": "32px", "letterSpacing": "normal" },
      "h2": { "fontFamily": "Geist Sans", "fontSize": "20px", "fontWeight": "500", "lineHeight": "28px", "letterSpacing": "normal" },
      "body": { "fontFamily": "Geist Sans", "fontSize": "14px", "fontWeight": "400", "lineHeight": "20px", "letterSpacing": "normal" },
      "caption": { "fontFamily": "Geist Sans", "fontSize": "12px", "fontWeight": "500", "lineHeight": "16px", "letterSpacing": "0.05em" }
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
    "shadows": ["0 1px 2px 0 rgba(0,0,0,0.05)", "0 4px 6px -1px rgba(0,0,0,0.1)"],
    "textShadows": ["0 1px 2px rgba(0,0,0,0.1)"],
    "gradients": [
      { "value": "linear-gradient(to right, #3b82f6, #8b5cf6)", "count": 3 }
    ],
    "filters": {
      "filter": ["blur(4px)", "brightness(0.95)"],
      "backdropFilter": ["blur(8px)", "blur(12px) saturate(180%)"]
    },
    "transforms": ["scale(1.05)", "translateY(-2px)", "rotate(45deg)"],
    "animations": [
      { "name": "spin", "duration": "1s", "timingFunction": "linear", "iterationCount": "infinite" },
      { "name": "fadeIn", "duration": "300ms", "timingFunction": "ease-out" }
    ],
    "cssVariables": {
      "light": {
        "--background": "oklch(1 0 0)",
        "--foreground": "oklch(0.145 0 0)",
        "--sidebar": "oklch(0.985 0 0)",
        "--primary": "oklch(0.205 0 0)",
        "--border": "oklch(0.922 0 0)",
        "--ring": "oklch(0.708 0 0)"
      },
      "dark": {
        "--background": "oklch(0.145 0 0)",
        "--foreground": "oklch(0.985 0 0)",
        "--sidebar": "oklch(0.205 0 0)",
        "--primary": "oklch(0.922 0 0)",
        "--border": "oklch(0.269 0 0)",
        "--ring": "oklch(0.439 0 0)"
      }
    }
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
      const els = document.querySelectorAll('h1,h2,h3,h4,h5,p,span,a,label,li,button,input,select,td,th,div,section,aside,header,main,nav,svg');
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
        if (['h1','h2','h3','h4','h5','p','span','a','label'].includes(tag)) {
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
```

---

## Phase 2: 전체 페이지 컴포넌트 인벤토리

### 2.1 원패스 전체 추출 전략

한 번의 Playwright 실행으로 모든 페이지를 순회하며 **모든 가시 요소**를 추출한다.
7 카테고리 × 21 속성 포맷으로 영역(sidebar/header/content)과 컴포넌트 타입을 자동 분류한다.

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
| `svg`, `img[src*=".svg"]` | icon |
| `table`, `thead`, `th`, `td` | table |
| `input[type="search"]`, `input` + 부모 `relative` + 형제 `svg` | search |
| `div`/`ul` + `position:absolute` + `z-index≥10` + `boxShadow` + 내부 아이템 목록 | dropdown |
| `div`/`span` + `inline-flex` + `rounded-full`/`rounded-md` + bgColor + 작은 크기 | chip/filter |
| `div` + `display:flex` + `gap` + 내부 `button`/`select` 다수 | filter-bar |
| `input`, `select`, `textarea` | form |
| `button` | button |
| `h1`~`h5` | heading |
| `nav` | navigation |
| `div`/`section` + border + bg + radius | card |
| `span`/`div` + inline + bgColor | badge |
| 그 외 `p`, `span`, `a`, `label` | text |

#### 2.3.1 검색/필터/드롭다운 상세 감지

**검색 컨테이너:**
```
감지 조건:
1. div[position:relative] 내부에 input + svg(아이콘)이 있는 구조
2. input[type="search"] 또는 input[placeholder*="검색"|"Search"|"찾기"]
3. 아이콘이 absolute로 input 좌/우측에 배치

추출 대상:
- 컨테이너: position, width, border, borderRadius, bgColor
- 인풋: padding(아이콘 공간 확보용 pl-10 등), fontSize, placeholder
- 아이콘: position(absolute), top/left, width/height, color
- focus 상태: borderColor, ring/outline, boxShadow 변화
- ::placeholder: color, fontSize, opacity
```

**필터 바 / 필터 칩:**
```
감지 조건:
1. div[display:flex][gap] + 내부에 button/select 2개 이상 → filter-bar
2. span/div[inline-flex][rounded-full] + 작은 padding + bgColor → chip
3. button[bgColor≠transparent] + 작은 크기 → active filter

추출 대상:
- 필터 바: display, flexDirection, flexWrap, gap, alignItems, padding
- 필터 칩(비활성): bgColor, color, border, borderRadius, padding, fontSize
- 필터 칩(활성): bgColor(진한), color(흰/다른색), fontWeight, border 변화
- 필터 카운트 뱃지: bgColor, color, borderRadius(full), fontSize, minWidth
- 필터 구분선: borderRight/borderLeft, height, margin
```

**커스텀 드롭다운:**
```
감지 조건:
1. div/ul[position:absolute][z-index≥10] + boxShadow + border → dropdown panel
2. 내부 li/div/a 반복 요소 → dropdown items
3. 트리거: button/div + 셰브론 아이콘(svg rotate)

추출 대상:
- 트리거 버튼: border, borderRadius, padding, bgColor, fontSize, gap(텍스트↔아이콘)
- 셰브론 아이콘: width/height, transform(rotate), transition
- 패널: position(absolute), top/left/right, width(min-w), maxHeight, overflow-y
         bgColor, border, borderRadius, boxShadow, zIndex, padding(py)
- 아이템: padding(px, py), fontSize, color, cursor
          hover: bgColor, color 변화
          active/selected: bgColor, fontWeight, 체크 아이콘 유무
- 구분선: border-t/divide-y, margin(my)
- 그룹 헤더: fontSize(작음), fontWeight(semibold), color(muted), padding, textTransform
- 열림 트랜지션: opacity, transform(scale), transition-duration
```

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
    if (tag === 'svg' || (tag === 'img' && (el.src || '').includes('.svg'))) return 'icon';
    if (['table','thead','tbody','tr','th','td'].includes(tag)) return 'table';

    // 검색 컨테이너: input[type=search] 또는 relative wrapper + input + svg
    if (tag === 'input') {
      const type = el.getAttribute('type');
      const ph = (el.getAttribute('placeholder') || '').toLowerCase();
      if (type === 'search' || ph.includes('search') || ph.includes('검색') || ph.includes('찾기')) return 'search';
      const parent = el.parentElement;
      if (parent && getComputedStyle(parent).position === 'relative' && parent.querySelector('svg')) return 'search';
    }
    // 검색 컨테이너 wrapper
    if ((tag === 'div') && cs.position === 'relative') {
      const hasInput = el.querySelector('input');
      const hasSvg = el.querySelector('svg');
      if (hasInput && hasSvg) {
        const inputPh = (hasInput.getAttribute('placeholder') || '').toLowerCase();
        const inputType = hasInput.getAttribute('type');
        if (inputType === 'search' || inputPh.includes('search') || inputPh.includes('검색') || inputPh.includes('찾기')) return 'search';
      }
    }

    // 커스텀 드롭다운 패널: absolute + z-index≥10 + shadow/border + 내부 아이템
    if ((tag === 'div' || tag === 'ul') &&
        (cs.position === 'absolute' || cs.position === 'fixed') &&
        parseInt(cs.zIndex) >= 10 &&
        (cs.boxShadow !== 'none' || cs.borderWidth !== '0px')) {
      const children = el.querySelectorAll('li, a, div[role="option"], [class*="item"]');
      if (children.length >= 2) return 'dropdown';
    }

    // 필터 칩: inline-flex + rounded + bgColor + 작은 크기
    if ((tag === 'span' || tag === 'div' || tag === 'button') &&
        (cs.display === 'inline-flex' || cs.display === 'inline-block') &&
        cs.backgroundColor !== 'rgba(0, 0, 0, 0)') {
      const rect = el.getBoundingClientRect();
      if (rect.height < 40 && rect.width < 200 &&
          (cs.borderRadius.includes('9999') || parseInt(cs.borderRadius) >= 12)) return 'chip';
    }

    // 필터 바: flex + gap + 내부에 button/select 2개 이상
    if (tag === 'div' && (cs.display === 'flex' || cs.display === 'inline-flex') && cs.gap !== 'normal') {
      const controls = el.querySelectorAll('button, select, input[type="search"], input');
      if (controls.length >= 2) {
        const rect = el.getBoundingClientRect();
        if (rect.height < 80) return 'filter-bar';
      }
    }

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

  const selectors = 'h1,h2,h3,h4,h5,p,span,a,label,li,table,thead,tbody,tr,th,td,input,select,button,textarea,nav,aside,header,main,section,svg';
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
      // 크기 (min/max/aspect 포함)
      dimensions: `${(rect.width * CORRECTION).toFixed(0)} × ${(rect.height * CORRECTION).toFixed(0)}`,
      minWidth: s.minWidth !== '0px' && s.minWidth !== 'auto' ? s.minWidth : '',
      maxWidth: s.maxWidth !== 'none' ? s.maxWidth : '',
      minHeight: s.minHeight !== '0px' && s.minHeight !== 'auto' ? s.minHeight : '',
      maxHeight: s.maxHeight !== 'none' ? s.maxHeight : '',
      aspectRatio: s.aspectRatio !== 'auto' ? s.aspectRatio : '',
      // 색상
      color: s.color,
      bgColor: s.backgroundColor,
      opacity: s.opacity !== '1' ? s.opacity : '',
      // 서체
      fontFamily: s.fontFamily.split(',')[0].trim().replace(/['"]/g, ''),
      fontSize: `${(parseFloat(s.fontSize) * CORRECTION).toFixed(0)}px`,
      fontWeight: s.fontWeight,
      fontStyle: s.fontStyle !== 'normal' ? s.fontStyle : '',
      lineHeight: `${(parseFloat(s.lineHeight) * CORRECTION).toFixed(0)}px`,
      letterSpacing: s.letterSpacing,
      // 텍스트
      textAlign: s.textAlign !== 'start' ? s.textAlign : '',
      textTransform: s.textTransform !== 'none' ? s.textTransform : '',
      whiteSpace: s.whiteSpace !== 'normal' ? s.whiteSpace : '',
      verticalAlign: s.verticalAlign !== 'baseline' ? s.verticalAlign : '',
      textDecoration: s.textDecorationLine !== 'none' ? s.textDecorationLine : '',
      textOverflow: s.textOverflow !== 'clip' ? s.textOverflow : '',
      wordBreak: s.wordBreak !== 'normal' ? s.wordBreak : '',
      overflowWrap: s.overflowWrap !== 'normal' ? s.overflowWrap : '',
      textShadow: s.textShadow !== 'none' ? s.textShadow : '',
      // 패딩/마진
      padding: shorten4(s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft),
      margin: shorten4(s.marginTop, s.marginRight, s.marginBottom, s.marginLeft),
      // 보더
      border: s.borderWidth !== '0px' ? `${s.borderWidth} ${s.borderStyle} ${s.borderColor}` : 'none',
      borderColor: s.borderColor,
      borderWidth: s.borderWidth !== '0px' ? s.borderWidth : '',
      borderRadius: s.borderRadius !== '0px' ? s.borderRadius : '',
      outline: s.outlineStyle !== 'none' ? `${s.outlineWidth} ${s.outlineStyle} ${s.outlineColor}` : '',
      outlineOffset: s.outlineOffset !== '0px' ? s.outlineOffset : '',
      // 시각효과
      boxShadow: s.boxShadow !== 'none' ? s.boxShadow.substring(0, 80) : '',
      backgroundImage: s.backgroundImage !== 'none' && s.backgroundImage.includes('gradient') ? s.backgroundImage.substring(0, 120) : '',
      filter: s.filter !== 'none' ? s.filter : '',
      backdropFilter: s.backdropFilter !== 'none' ? s.backdropFilter : '',
      mixBlendMode: s.mixBlendMode !== 'normal' ? s.mixBlendMode : '',
      clipPath: s.clipPath !== 'none' ? s.clipPath : '',
      // 레이아웃
      display: s.display,
      alignItems: s.alignItems !== 'normal' ? s.alignItems : '',
      justifyContent: s.justifyContent !== 'normal' ? s.justifyContent : '',
      flexDirection: s.flexDirection !== 'row' ? s.flexDirection : '',
      flexWrap: s.flexWrap !== 'nowrap' ? s.flexWrap : '',
      flexGrow: s.flexGrow !== '0' ? s.flexGrow : '',
      flexShrink: s.flexShrink !== '1' ? s.flexShrink : '',
      flexBasis: s.flexBasis !== 'auto' ? s.flexBasis : '',
      gridTemplateColumns: s.gridTemplateColumns !== 'none' ? s.gridTemplateColumns : '',
      gridTemplateRows: s.gridTemplateRows !== 'none' ? s.gridTemplateRows : '',
      gridColumn: s.gridColumn !== 'auto' ? s.gridColumn : '',
      gridRow: s.gridRow !== 'auto' ? s.gridRow : '',
      placeItems: s.placeItems !== 'normal' ? s.placeItems : '',
      order: s.order !== '0' ? s.order : '',
      gap: s.gap !== 'normal' ? s.gap : '',
      position: s.position !== 'static' ? s.position : '',
      overflow: s.overflow !== 'visible' ? s.overflow : '',
      zIndex: s.zIndex !== 'auto' ? s.zIndex : '',
      isolation: s.isolation !== 'auto' ? s.isolation : '',
      columns: s.columnCount !== 'auto' ? s.columnCount : '',
      // 포지셔닝
      top: s.position !== 'static' && s.top !== 'auto' ? s.top : '',
      right: s.position !== 'static' && s.right !== 'auto' ? s.right : '',
      bottom: s.position !== 'static' && s.bottom !== 'auto' ? s.bottom : '',
      left: s.position !== 'static' && s.left !== 'auto' ? s.left : '',
      // 트랜스폼
      transform: s.transform !== 'none' ? s.transform : '',
      transformOrigin: s.transformOrigin !== '50% 50%' && s.transformOrigin !== '50% 50% 0px' ? s.transformOrigin : '',
      // 인터랙션
      cursor: s.cursor !== 'auto' ? s.cursor : '',
      transition: s.transitionProperty !== 'all' && s.transitionProperty !== 'none'
        ? `${s.transitionProperty} ${s.transitionDuration} ${s.transitionTimingFunction}` : '',
      pointerEvents: s.pointerEvents !== 'auto' ? s.pointerEvents : '',
      userSelect: s.userSelect !== 'auto' ? s.userSelect : '',
      resize: s.resize !== 'none' ? s.resize : '',
      scrollBehavior: s.scrollBehavior !== 'auto' ? s.scrollBehavior : '',
      scrollSnapType: s.scrollSnapType !== 'none' ? s.scrollSnapType : '',
      scrollSnapAlign: s.scrollSnapAlign !== 'none' ? s.scrollSnapAlign : '',
      // 이미지/미디어
      objectFit: s.objectFit !== 'fill' ? s.objectFit : '',
      objectPosition: s.objectPosition !== '50% 50%' ? s.objectPosition : '',
      // 폼 스타일
      appearance: s.appearance !== 'none' && s.appearance !== 'auto' ? s.appearance : '',
      accentColor: s.accentColor !== 'auto' ? s.accentColor : '',
      caretColor: s.caretColor !== 'auto' && s.caretColor !== s.color ? s.caretColor : '',
      // 애니메이션
      animationName: s.animationName !== 'none' ? s.animationName : '',
      animationDuration: s.animationDuration !== '0s' ? s.animationDuration : '',
      // 기타
      visibility: s.visibility !== 'visible' ? s.visibility : '',
      listStyleType: s.listStyleType !== 'none' && s.listStyleType !== 'disc' ? s.listStyleType : '',
      // 아이콘 속성
      ...(tag === 'svg' ? {
        svgWidth: el.getAttribute('width') || s.width,
        svgHeight: el.getAttribute('height') || s.height,
        stroke: el.getAttribute('stroke') || s.stroke || '',
        strokeWidth: el.getAttribute('stroke-width') || '',
        fill: el.getAttribute('fill') || '',
      } : {}),
      // placeholder 스타일 (input/textarea)
      ...(['input','textarea'].includes(tag) ? (() => {
        const ph = el.getAttribute('placeholder');
        if (!ph) return {};
        return { placeholder: ph, placeholderColor: '' };
      })() : {}),
      // ::before/::after 의사 요소
      ...(() => {
        const pseudo = {};
        for (const p of ['::before', '::after']) {
          const ps = getComputedStyle(el, p === '::before' ? ':before' : ':after');
          if (ps.content && ps.content !== 'none' && ps.content !== '""' && ps.content !== "''") {
            pseudo[p] = {
              content: ps.content,
              width: ps.width, height: ps.height,
              bgColor: ps.backgroundColor,
              color: ps.color,
              position: ps.position !== 'static' ? ps.position : '',
              borderRadius: ps.borderRadius !== '0px' ? ps.borderRadius : '',
            };
          }
        }
        return Object.keys(pseudo).length > 0 ? { pseudoElements: pseudo } : {};
      })(),
      // 검색 컨테이너 전용 속성
      ...(() => {
        if (type !== 'search') return {};
        const searchProps = {};
        // 인풋 찾기
        const searchInput = tag === 'input' ? el : el.querySelector('input');
        if (searchInput) {
          const si = getComputedStyle(searchInput);
          searchProps.searchInputPadding = shorten4(si.paddingTop, si.paddingRight, si.paddingBottom, si.paddingLeft);
          searchProps.searchInputFontSize = `${(parseFloat(si.fontSize) * CORRECTION).toFixed(0)}px`;
          searchProps.searchInputBorder = si.borderWidth !== '0px' ? `${si.borderWidth} ${si.borderStyle} ${si.borderColor}` : 'none';
          searchProps.searchInputBorderRadius = si.borderRadius !== '0px' ? si.borderRadius : '';
          searchProps.searchInputBgColor = si.backgroundColor;
          searchProps.searchPlaceholder = searchInput.getAttribute('placeholder') || '';
        }
        // 아이콘 찾기
        const searchIcon = (tag === 'input' ? el.parentElement : el)?.querySelector('svg');
        if (searchIcon) {
          const ics = getComputedStyle(searchIcon);
          searchProps.searchIconPosition = ics.position;
          searchProps.searchIconSize = `${ics.width} × ${ics.height}`;
          searchProps.searchIconColor = ics.color;
          searchProps.searchIconTop = ics.top !== 'auto' ? ics.top : '';
          searchProps.searchIconLeft = ics.left !== 'auto' ? ics.left : '';
          searchProps.searchIconRight = ics.right !== 'auto' ? ics.right : '';
        }
        return searchProps;
      })(),
      // 드롭다운 패널 전용 속성
      ...(() => {
        if (type !== 'dropdown') return {};
        const ddProps = {};
        ddProps.dropdownMaxHeight = s.maxHeight !== 'none' ? s.maxHeight : '';
        ddProps.dropdownOverflowY = s.overflowY !== 'visible' ? s.overflowY : '';
        ddProps.dropdownMinWidth = s.minWidth !== '0px' && s.minWidth !== 'auto' ? s.minWidth : '';
        ddProps.dropdownPadding = shorten4(s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft);
        // 첫 번째 아이템 스타일 추출
        const firstItem = el.querySelector('li, a, div[role="option"], [class*="item"]');
        if (firstItem) {
          const fis = getComputedStyle(firstItem);
          ddProps.dropdownItemPadding = shorten4(fis.paddingTop, fis.paddingRight, fis.paddingBottom, fis.paddingLeft);
          ddProps.dropdownItemFontSize = `${(parseFloat(fis.fontSize) * CORRECTION).toFixed(0)}px`;
          ddProps.dropdownItemColor = fis.color;
          ddProps.dropdownItemBgColor = fis.backgroundColor;
          ddProps.dropdownItemCursor = fis.cursor;
        }
        // 구분선 확인
        const hasDivider = el.querySelector('hr, [class*="divider"], [class*="separator"]')
          || s.getPropertyValue('--tw-divide-y-reverse') !== '';
        ddProps.dropdownHasDivider = !!hasDivider;
        return ddProps;
      })(),
      // 필터 칩 전용 속성
      ...(() => {
        if (type !== 'chip') return {};
        return {
          chipBgColor: s.backgroundColor,
          chipColor: s.color,
          chipBorder: s.borderWidth !== '0px' ? `${s.borderWidth} ${s.borderStyle} ${s.borderColor}` : 'none',
          chipBorderRadius: s.borderRadius,
          chipPadding: shorten4(s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft),
          chipFontSize: `${(parseFloat(s.fontSize) * CORRECTION).toFixed(0)}px`,
          chipFontWeight: s.fontWeight,
          chipGap: s.gap !== 'normal' ? s.gap : '',
        };
      })(),
      // 필터 바 전용 속성
      ...(() => {
        if (type !== 'filter-bar') return {};
        return {
          filterBarDisplay: s.display,
          filterBarFlexWrap: s.flexWrap !== 'nowrap' ? s.flexWrap : '',
          filterBarGap: s.gap !== 'normal' ? s.gap : '',
          filterBarAlignItems: s.alignItems !== 'normal' ? s.alignItems : '',
          filterBarPadding: shorten4(s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft),
          filterBarChildCount: el.querySelectorAll('button, select, input').length,
        };
      })(),
      // ::selection 스타일
      ...(() => {
        try {
          const sel = getComputedStyle(el, '::selection');
          if (sel.backgroundColor !== 'rgba(0, 0, 0, 0)') {
            return { selectionBg: sel.backgroundColor, selectionColor: sel.color };
          }
        } catch {}
        return {};
      })(),
      // 접근성
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

### 3.3 컴포넌트 단위 정밀 비교

전체 페이지 비교로는 개별 컴포넌트의 미세 차이가 묻힌다. 영역별로 분리 비교한다.

**영역 분리 캡처:**
1. 사이드바/메뉴바 영역만 크롭 → 비교
2. 헤더 영역만 크롭 → 비교
3. 콘텐츠 영역 내 주요 컴포넌트(카드, 테이블, 폼)별 bounding box 크롭 → 개별 비교
4. 각 영역/컴포넌트별 싱크율 산출 → 전체 90%여도 특정 영역 70%인 문제 감지

**정밀 threshold 2차 비교:**
- 1차: `threshold: 0.15` (기본 — 안티앨리어싱 등 허용)
- 2차: `threshold: 0.05` (정밀 — 미세 간격/정렬/색상 차이 검출)
- 2차 비교 결과는 "정밀 diff"로 별도 보고

### 3.4 인터랙션 상태 캡처

정적 스크린샷으로는 hover/active/focus 상태를 확인할 수 없다. Playwright로 인터랙션 상태를 캡처한다.

**캡처 대상:**
| 상태 | 대상 요소 | 캡처 방법 |
|------|----------|----------|
| **hover** | 메뉴 아이템, 버튼, 테이블 행, 카드, 링크, 드롭다운 아이템 | `element.hover()` → 스크린샷 |
| **active** | 현재 선택된 메뉴, 활성 탭, 활성 필터 칩 | 네비게이션 클릭 후 스크린샷 |
| **focus** | 검색 인풋, 입력 필드, 셀렉트 | `element.focus()` → 스크린샷 |
| **open** | 드롭다운 메뉴, 셀렉트 박스, 콤보박스 | 트리거 `click()` → 패널 스크린샷 |

**추출 속성:**
- hover 시: `backgroundColor`, `color`, `borderColor`, `boxShadow`, `transform`, `opacity` 변화
- active 시: 인디케이터 스타일 (좌측 바, 배경색, 폰트 굵기)
- focus 시: `outline`, `ring`, `borderColor`, `boxShadow` 변화
- open 시: 드롭다운 패널 전체 스타일 (아래 상세)

**검색/필터/드롭다운 전용 인터랙션 캡처:**

| 컴포넌트 | 상태 | 캡처 속성 |
|----------|------|----------|
| **검색 인풋** | focus | `borderColor`, `boxShadow`(ring), `outline`, `outlineOffset`, 아이콘 `color` 변화 |
| **검색 인풋** | ::placeholder | `color`, `opacity`, `fontSize` (기본 vs focus 시 변화) |
| **필터 칩** | inactive | `bgColor`, `color`, `border`, `fontWeight` |
| **필터 칩** | active/selected | `bgColor`(진함), `color`(변경), `fontWeight`(볼드), `border` 변화 |
| **필터 칩** | hover | `bgColor`, `borderColor` 변화 |
| **드롭다운 트리거** | closed | `border`, `bgColor`, `padding`, 셰브론 `transform`(rotate 0) |
| **드롭다운 트리거** | open | `border` 변화, 셰브론 `transform`(rotate 180deg) |
| **드롭다운 패널** | open | `position`, `top/bottom`, `width`, `maxHeight`, `overflowY`, `bgColor`, `border`, `borderRadius`, `boxShadow`, `zIndex`, `padding` |
| **드롭다운 아이템** | default | `padding`, `fontSize`, `color`, `bgColor`, `cursor` |
| **드롭다운 아이템** | hover | `bgColor`, `color` 변화 |
| **드롭다운 아이템** | selected | `bgColor`, `fontWeight`, 체크 아이콘 유무, `color` |
| **드롭다운 구분선** | — | `borderTop`/`borderBottom`, `margin` |
| **드롭다운 그룹헤더** | — | `fontSize`(작음), `fontWeight`, `color`(muted), `padding`, `textTransform` |

**드롭다운 열림 캡처 방법:**
```javascript
// 트리거 클릭 → 패널 열림
const trigger = page.locator('button[class*="select"], [role="combobox"], [class*="dropdown"]').first();
const beforeStyle = await trigger.evaluate(/* 기본 상태 */);
await trigger.click();
await page.waitForTimeout(300);
// 패널 캡처
const panel = page.locator('[role="listbox"], ul[class*="dropdown"], div[class*="menu"]').first();
const panelStyle = await panel.evaluate(e => {
  const s = getComputedStyle(e);
  return {
    position: s.position, top: s.top, left: s.left, width: s.width,
    maxHeight: s.maxHeight, overflowY: s.overflowY, bgColor: s.backgroundColor,
    border: `${s.borderWidth} ${s.borderStyle} ${s.borderColor}`,
    borderRadius: s.borderRadius, boxShadow: s.boxShadow, zIndex: s.zIndex,
    padding: `${s.paddingTop} ${s.paddingRight} ${s.paddingBottom} ${s.paddingLeft}`,
  };
});
// 아이템 스타일
const items = await panel.locator('li, [role="option"]').all();
for (const item of items.slice(0, 5)) {
  const itemStyle = await item.evaluate(/* default 스타일 */);
  await item.hover();
  const hoverStyle = await item.evaluate(/* hover 스타일 */);
}
// 셰브론 회전 확인
const chevron = await trigger.locator('svg').first();
const chevronTransform = await chevron.evaluate(e => getComputedStyle(e).transform);
```

**비교 방법:**
1. 레퍼런스 사이트에서 각 상태 캡처 + computed style 추출
2. 로컬 사이트에서 동일 요소 동일 상태 캡처 + computed style 추출
3. computed style 값 직접 비교 (px 단위 diff)

### 3.5 정렬/배열 검증

같은 레벨 요소들의 정렬 일관성을 검증한다.

- 형제 요소 간 x/y 좌표 추출 → 수평/수직 정렬 일치 확인
- 형제 요소 간 gap 균일성 검증 (표준편차 2px 이하)
- 그리드 컬럼 너비 균일성 확인

### 3.6 텍스트 콘텐츠 마스킹

더미 데이터와 실제 데이터의 텍스트 차이가 pixelmatch에서 불필요한 diff를 발생시킨다. 텍스트 영역을 마스킹하여 순수 레이아웃/스타일 차이만 비교한다.

**마스킹 방법:**
1. 양쪽 사이트에서 `page.addInitScript()`로 모든 텍스트 요소의 `color`를 `transparent`로 설정
2. 텍스트가 보이지 않는 상태에서 스크린샷 캡처 → 레이아웃/배경/보더만 비교
3. 마스킹 전후 싱크율을 모두 보고하여 "텍스트 제외 싱크율" 산출

**마스킹 대상:** `h1~h6`, `p`, `span`, `a`, `label`, `li`, `td`, `th`, `button` 내 텍스트

### 3.7 스크롤 영역 비교

`fullPage: false`로는 뷰포트 밖 콘텐츠를 놓친다.

**비교 방법:**
1. `fullPage: true`로 전체 페이지 캡처 → 스크롤 영역 포함
2. 뷰포트 단위로 분할 비교 (상단/중간/하단)
3. 스크롤 가능한 컨테이너(`overflow: auto/scroll`) 내부를 별도 스크롤 후 캡처

### 3.8 반응형 멀티 뷰포트 비교

단일 뷰포트(1366×900)만으로는 반응형 레이아웃 차이를 놓친다.

**비교 뷰포트:**
| 뷰포트 | 크기 | 용도 |
|--------|------|------|
| 모바일 | 375 × 812 | 모바일 레이아웃, 햄버거 메뉴 |
| 태블릿 | 768 × 1024 | 태블릿 레이아웃, 그리드 변환 |
| 데스크톱 | 1366 × 900 | 기본 (기존) |
| 와이드 | 1920 × 1080 | 와이드 스크린 레이아웃 |

각 뷰포트별 싱크율을 개별 보고한다.

### 3.9 다크 모드 비교

다크 모드가 있는 사이트는 라이트/다크 양쪽 비교가 필요하다.

**비교 방법:**
1. 라이트 모드 캡처 (기본)
2. `page.emulateMedia({ colorScheme: 'dark' })` 또는 `document.documentElement.classList.add('dark')` 후 다크 모드 캡처
3. 양쪽 모드에서 각각 싱크율 산출
4. CSS 변수 값이 다크 모드에서 올바르게 전환되는지 검증

### 3.10 싱크율 계산

```
싱크율 = (1 - 불일치픽셀수 / 전체픽셀수) × 100
```

페이지별 싱크율 + 전체 평균 싱크율을 출력한다.

### 3.11 스크립트 템플릿 C: visual-regression.js

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
  // 사이드바, 헤더, 콘텐츠 영역을 개별 크롭하여 비교
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
    '800': 'font-extrabold',
  },
  lineHeight: {
    '16px': 'leading-4', '20px': 'leading-5', '24px': 'leading-6',
    '28px': 'leading-7', '32px': 'leading-8', '36px': 'leading-9',
    '40px': 'leading-10', '1': 'leading-none', '1.25': 'leading-tight',
    '1.375': 'leading-snug', '1.5': 'leading-normal', '1.625': 'leading-relaxed',
    '2': 'leading-loose',
  },
  letterSpacing: {
    '-0.05em': 'tracking-tighter', '-0.025em': 'tracking-tight',
    '0em': 'tracking-normal', 'normal': 'tracking-normal',
    '0.025em': 'tracking-wide', '0.05em': 'tracking-wider',
    '0.1em': 'tracking-widest',
  },
  fontStyle: {
    'italic': 'italic', 'normal': 'not-italic',
  },
  textAlign: {
    'left': 'text-left', 'center': 'text-center', 'right': 'text-right',
    'justify': 'text-justify', 'start': 'text-start', 'end': 'text-end',
  },
  textTransform: {
    'uppercase': 'uppercase', 'lowercase': 'lowercase',
    'capitalize': 'capitalize', 'none': 'normal-case',
  },
  whiteSpace: {
    'nowrap': 'whitespace-nowrap', 'pre': 'whitespace-pre',
    'pre-line': 'whitespace-pre-line', 'pre-wrap': 'whitespace-pre-wrap',
    'break-spaces': 'whitespace-break-spaces', 'normal': 'whitespace-normal',
  },
  wordBreak: {
    'break-all': 'break-all', 'keep-all': 'break-keep',
  },
  overflowWrap: {
    'break-word': 'break-words',
  },
  textDecoration: {
    'underline': 'underline', 'overline': 'overline',
    'line-through': 'line-through', 'none': 'no-underline',
  },
  textOverflow: {
    'ellipsis': 'truncate',
  },
  overflow: {
    'hidden': 'overflow-hidden', 'auto': 'overflow-auto',
    'scroll': 'overflow-scroll', 'visible': 'overflow-visible',
  },
  display: {
    'flex': 'flex', 'inline-flex': 'inline-flex',
    'grid': 'grid', 'inline-grid': 'inline-grid',
    'block': 'block', 'inline-block': 'inline-block',
    'inline': 'inline', 'none': 'hidden',
  },
  flexDirection: {
    'row': 'flex-row', 'row-reverse': 'flex-row-reverse',
    'column': 'flex-col', 'column-reverse': 'flex-col-reverse',
  },
  flexWrap: {
    'wrap': 'flex-wrap', 'wrap-reverse': 'flex-wrap-reverse',
    'nowrap': 'flex-nowrap',
  },
  alignItems: {
    'flex-start': 'items-start', 'flex-end': 'items-end',
    'center': 'items-center', 'baseline': 'items-baseline',
    'stretch': 'items-stretch',
  },
  justifyContent: {
    'flex-start': 'justify-start', 'flex-end': 'justify-end',
    'center': 'justify-center', 'space-between': 'justify-between',
    'space-around': 'justify-around', 'space-evenly': 'justify-evenly',
  },
  gridTemplateCols: (value) => {
    const repeatMatch = value.match(/repeat\((\d+),/);
    if (repeatMatch) return `grid-cols-${repeatMatch[1]}`;
    const colCount = value.split(/\s+/).length;
    return `grid-cols-${colCount}`;
  },
  gridTemplateRows: (value) => {
    const repeatMatch = value.match(/repeat\((\d+),/);
    if (repeatMatch) return `grid-rows-${repeatMatch[1]}`;
    const rowCount = value.split(/\s+/).length;
    return `grid-rows-${rowCount}`;
  },
  flexGrow: { '0': 'grow-0', '1': 'grow' },
  flexShrink: { '0': 'shrink-0', '1': 'shrink' },
  placeItems: {
    'center': 'place-items-center', 'start': 'place-items-start',
    'end': 'place-items-end', 'stretch': 'place-items-stretch',
  },
  order: {
    '-1': 'order-first', '0': 'order-none', '1': 'order-1',
    '2': 'order-2', '3': 'order-3', '9999': 'order-last',
  },
  borderRadius: {
    '0px': 'rounded-none', '4px': 'rounded-sm', '6px': 'rounded-md',
    '8px': 'rounded-lg', '12px': 'rounded-xl', '16px': 'rounded-2xl',
    '9999px': 'rounded-full',
  },
  borderWidth: {
    '0px': 'border-0', '1px': 'border', '2px': 'border-2',
    '4px': 'border-4', '8px': 'border-8',
  },
  iconSize: {
    '12px': 'w-3 h-3', '16px': 'w-4 h-4', '20px': 'w-5 h-5',
    '24px': 'w-6 h-6', '32px': 'w-8 h-8', '40px': 'w-10 h-10',
    '48px': 'w-12 h-12',
  },
  zIndex: {
    '0': 'z-0', '10': 'z-10', '20': 'z-20', '30': 'z-30',
    '40': 'z-40', '50': 'z-50',
  },
  spacing: (px) => {
    const rem = parseFloat(px) / 4;
    const map = { 0:'0', 1:'1', 2:'2', 3:'3', 4:'4', 5:'5', 6:'6', 8:'8',
      10:'10', 12:'12', 16:'16', 20:'20', 24:'24' };
    return map[rem] || `[${px}]`;
  },
  // --- 새 속성 매핑 ---
  aspectRatio: {
    'auto': 'aspect-auto', '1 / 1': 'aspect-square',
    '16 / 9': 'aspect-video', '4 / 3': 'aspect-[4/3]',
  },
  objectFit: {
    'contain': 'object-contain', 'cover': 'object-cover',
    'fill': 'object-fill', 'none': 'object-none', 'scale-down': 'object-scale-down',
  },
  objectPosition: {
    '50% 50%': 'object-center', '50% 0%': 'object-top', '50% 100%': 'object-bottom',
    '0% 50%': 'object-left', '100% 50%': 'object-right',
  },
  mixBlendMode: {
    'multiply': 'mix-blend-multiply', 'screen': 'mix-blend-screen',
    'overlay': 'mix-blend-overlay', 'darken': 'mix-blend-darken',
    'lighten': 'mix-blend-lighten', 'color-dodge': 'mix-blend-color-dodge',
    'difference': 'mix-blend-difference', 'exclusion': 'mix-blend-exclusion',
  },
  isolation: { 'isolate': 'isolate', 'auto': 'isolation-auto' },
  visibility: { 'visible': 'visible', 'hidden': 'invisible', 'collapse': 'collapse' },
  pointerEvents: { 'none': 'pointer-events-none', 'auto': 'pointer-events-auto' },
  userSelect: {
    'none': 'select-none', 'text': 'select-text', 'all': 'select-all', 'auto': 'select-auto',
  },
  resize: {
    'both': 'resize', 'horizontal': 'resize-x', 'vertical': 'resize-y', 'none': 'resize-none',
  },
  scrollBehavior: { 'smooth': 'scroll-smooth', 'auto': 'scroll-auto' },
  scrollSnapType: {
    'x mandatory': 'snap-x snap-mandatory', 'y mandatory': 'snap-y snap-mandatory',
    'x proximity': 'snap-x', 'y proximity': 'snap-y',
    'both mandatory': 'snap-both snap-mandatory',
  },
  scrollSnapAlign: {
    'start': 'snap-start', 'end': 'snap-end', 'center': 'snap-center',
  },
  appearance: { 'none': 'appearance-none', 'auto': 'appearance-auto' },
  listStyleType: {
    'disc': 'list-disc', 'decimal': 'list-decimal', 'none': 'list-none',
  },
  columns: {
    '1': 'columns-1', '2': 'columns-2', '3': 'columns-3', '4': 'columns-4',
  },
  backdropFilter: (value) => {
    if (value.includes('blur')) {
      const m = value.match(/blur\((\d+)px\)/);
      if (m) {
        const blurMap = { 4:'backdrop-blur-sm', 8:'backdrop-blur', 12:'backdrop-blur-md',
          16:'backdrop-blur-lg', 24:'backdrop-blur-xl', 40:'backdrop-blur-2xl', 64:'backdrop-blur-3xl' };
        return blurMap[m[1]] || `backdrop-blur-[${m[1]}px]`;
      }
    }
    return null;
  },
  filter: (value) => {
    const parts = [];
    const blurM = value.match(/blur\((\d+)px\)/);
    if (blurM) {
      const bMap = { 0:'blur-none', 4:'blur-sm', 8:'blur', 12:'blur-md', 16:'blur-lg', 24:'blur-xl', 40:'blur-2xl', 64:'blur-3xl' };
      parts.push(bMap[blurM[1]] || `blur-[${blurM[1]}px]`);
    }
    if (value.includes('grayscale(1)')) parts.push('grayscale');
    if (value.includes('invert(1)')) parts.push('invert');
    if (value.includes('sepia(1)')) parts.push('sepia');
    const brightM = value.match(/brightness\(([\d.]+)\)/);
    if (brightM) {
      const v = Math.round(parseFloat(brightM[1]) * 100);
      parts.push(`brightness-${v}`);
    }
    const contrastM = value.match(/contrast\(([\d.]+)\)/);
    if (contrastM) {
      const v = Math.round(parseFloat(contrastM[1]) * 100);
      parts.push(`contrast-${v}`);
    }
    const saturateM = value.match(/saturate\(([\d.]+)\)/);
    if (saturateM) {
      const v = Math.round(parseFloat(saturateM[1]) * 100);
      parts.push(`saturate-${v}`);
    }
    return parts.length > 0 ? parts.join(' ') : null;
  },
  transformOrigin: {
    'center': 'origin-center', 'top': 'origin-top', 'top right': 'origin-top-right',
    'right': 'origin-right', 'bottom right': 'origin-bottom-right', 'bottom': 'origin-bottom',
    'bottom left': 'origin-bottom-left', 'left': 'origin-left', 'top left': 'origin-top-left',
  },
  maxWidth: (value) => {
    const map = { '0px':'max-w-0', '320px':'max-w-xs', '384px':'max-w-sm', '448px':'max-w-md',
      '512px':'max-w-lg', '576px':'max-w-xl', '672px':'max-w-2xl', '768px':'max-w-3xl',
      '896px':'max-w-4xl', '1024px':'max-w-5xl', '1152px':'max-w-6xl', '1280px':'max-w-7xl',
      'none':'max-w-none', '100%':'max-w-full' };
    return map[value] || `max-w-[${value}]`;
  },
  minHeight: (value) => {
    const map = { '0px':'min-h-0', '100%':'min-h-full', '100vh':'min-h-screen',
      '100dvh':'min-h-dvh', '100svh':'min-h-svh' };
    return map[value] || `min-h-[${value}]`;
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
    search: ['ui/search-input.tsx', 'ui/search-bar.tsx'],
    dropdown: ['ui/dropdown.tsx', 'ui/dropdown-menu.tsx', 'ui/select.tsx'],
    chip: ['ui/chip.tsx', 'ui/tag.tsx', 'ui/filter-chip.tsx'],
    'filter-bar': ['ui/filter-bar.tsx', 'ui/toolbar.tsx'],
  },
};

// TAILWIND_MAP은 4.2절의 전체 맵을 그대로 사용 (여기서는 생략, 위 4.2 참조)

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

              // lineHeight 비교
              const refLH = refEl.lineHeight;
              const twLH = TAILWIND_MAP.lineHeight[refLH];
              if (twLH && !fc.classes.includes(twLH)) {
                const currentTW = Object.values(TAILWIND_MAP.lineHeight).find(v => fc.classes.includes(v));
                if (currentTW && currentTW !== twLH) {
                  diffs.push({
                    line: fc.line,
                    property: 'lineHeight',
                    reference: `${refLH} (${twLH})`,
                    current: currentTW,
                    suggestion: `${currentTW} → ${twLH}`,
                  });
                }
              }

              // letterSpacing 비교
              const refLS = refEl.letterSpacing;
              const twLS = TAILWIND_MAP.letterSpacing[refLS];
              if (twLS && !fc.classes.includes(twLS)) {
                const currentTW = Object.values(TAILWIND_MAP.letterSpacing).find(v => fc.classes.includes(v));
                if (currentTW && currentTW !== twLS) {
                  diffs.push({
                    line: fc.line,
                    property: 'letterSpacing',
                    reference: `${refLS} (${twLS})`,
                    current: currentTW,
                    suggestion: `${currentTW} → ${twLS}`,
                  });
                }
              }

              // padding 비교
              if (refEl.padding && refEl.padding !== '0px') {
                const padValues = refEl.padding.split(' ').map(v => parseFloat(v));
                for (const [idx, dir] of ['t','r','b','l'].entries()) {
                  const pv = padValues[idx] || padValues[0];
                  const pvRem = pv / 4;
                  const spMap = { 0:'0',1:'1',2:'2',3:'3',4:'4',5:'5',6:'6',8:'8',10:'10',12:'12',16:'16',20:'20',24:'24' };
                  const twP = spMap[pvRem] ? `p${dir}-${spMap[pvRem]}` : null;
                  // 축약형도 체크 (px-, py-, p-)
                  if (twP && !fc.classes.includes(twP)) {
                    const pxClass = `px-${spMap[pvRem]}`;
                    const pyClass = `py-${spMap[pvRem]}`;
                    const pClass = `p-${spMap[pvRem]}`;
                    if (!fc.classes.includes(pxClass) && !fc.classes.includes(pyClass) && !fc.classes.includes(pClass)) {
                      diffs.push({
                        line: fc.line, property: `padding-${dir}`,
                        reference: `${pv}px (${twP})`,
                        current: '', suggestion: `→ ${twP}`,
                      });
                    }
                  }
                }
              }

              // margin 비교 (padding과 동일 패턴)
              if (refEl.margin && refEl.margin !== '0px') {
                const mValues = refEl.margin.split(' ').map(v => parseFloat(v));
                for (const [idx, dir] of ['t','r','b','l'].entries()) {
                  const mv = mValues[idx] || mValues[0];
                  const mvRem = mv / 4;
                  const spMap = { 0:'0',1:'1',2:'2',3:'3',4:'4',5:'5',6:'6',8:'8',10:'10',12:'12',16:'16',20:'20',24:'24' };
                  const twM = spMap[mvRem] ? `m${dir}-${spMap[mvRem]}` : null;
                  if (twM && !fc.classes.includes(twM)) {
                    const mxClass = `mx-${spMap[mvRem]}`;
                    const myClass = `my-${spMap[mvRem]}`;
                    const mClass = `m-${spMap[mvRem]}`;
                    if (!fc.classes.includes(mxClass) && !fc.classes.includes(myClass) && !fc.classes.includes(mClass)) {
                      diffs.push({
                        line: fc.line, property: `margin-${dir}`,
                        reference: `${mv}px (${twM})`,
                        current: '', suggestion: `→ ${twM}`,
                      });
                    }
                  }
                }
              }

              // borderRadius 비교
              if (refEl.borderRadius) {
                const brMap = { '0px':'rounded-none','4px':'rounded-sm','6px':'rounded-md','8px':'rounded-lg','12px':'rounded-xl','16px':'rounded-2xl','9999px':'rounded-full' };
                const twBR = brMap[refEl.borderRadius];
                if (twBR && !fc.classes.includes(twBR)) {
                  const currentBR = Object.values(brMap).find(v => fc.classes.includes(v));
                  if (currentBR && currentBR !== twBR) {
                    diffs.push({
                      line: fc.line, property: 'borderRadius',
                      reference: `${refEl.borderRadius} (${twBR})`,
                      current: currentBR, suggestion: `${currentBR} → ${twBR}`,
                    });
                  }
                }
              }

              // backgroundColor 비교 (gray 스케일)
              if (refEl.bgColor && refEl.bgColor !== 'rgba(0, 0, 0, 0)') {
                const bgMap = {
                  'rgb(249, 250, 251)': 'bg-gray-50', 'rgb(243, 244, 246)': 'bg-gray-100',
                  'rgb(229, 231, 235)': 'bg-gray-200', 'rgb(209, 213, 219)': 'bg-gray-300',
                  'rgb(255, 255, 255)': 'bg-white',
                };
                const twBG = bgMap[refEl.bgColor];
                if (twBG) {
                  const currentBG = Object.values(bgMap).find(v => fc.classes.includes(v.replace('bg-', '')));
                  if (currentBG && currentBG !== twBG) {
                    diffs.push({
                      line: fc.line, property: 'backgroundColor',
                      reference: twBG, current: currentBG,
                      suggestion: `${currentBG} → ${twBG}`,
                    });
                  }
                }
              }

              // color (텍스트) 비교
              if (refEl.color) {
                const colorMap = {
                  'rgb(17, 24, 39)': 'text-gray-900', 'rgb(31, 41, 55)': 'text-gray-800',
                  'rgb(55, 65, 81)': 'text-gray-700', 'rgb(75, 85, 99)': 'text-gray-600',
                  'rgb(107, 114, 128)': 'text-gray-500', 'rgb(156, 163, 175)': 'text-gray-400',
                  'rgb(209, 213, 219)': 'text-gray-300',
                };
                const twColor = colorMap[refEl.color];
                if (twColor) {
                  const currentColor = Object.values(colorMap).find(v => fc.classes.includes(v.replace('text-', '')));
                  if (currentColor && currentColor !== twColor) {
                    diffs.push({
                      line: fc.line, property: 'color',
                      reference: twColor, current: currentColor,
                      suggestion: `${currentColor} → ${twColor}`,
                    });
                  }
                }
              }

              // boxShadow 비교
              if (refEl.boxShadow) {
                const shadowMap = {
                  'none': 'shadow-none',
                  '0 1px 2px 0 rgba(0,0,0,0.05)': 'shadow-sm',
                  '0 1px 3px 0 rgba(0,0,0,0.1)': 'shadow',
                  '0 4px 6px -1px rgba(0,0,0,0.1)': 'shadow-md',
                  '0 10px 15px -3px rgba(0,0,0,0.1)': 'shadow-lg',
                };
                // 근사 매칭 (shadow 값은 정확히 안 맞을 수 있어서 패턴 매칭)
                let twShadow = null;
                if (refEl.boxShadow.includes('10px') || refEl.boxShadow.includes('15px')) twShadow = 'shadow-lg';
                else if (refEl.boxShadow.includes('4px') || refEl.boxShadow.includes('6px')) twShadow = 'shadow-md';
                else if (refEl.boxShadow.includes('1px 3px')) twShadow = 'shadow';
                else if (refEl.boxShadow.includes('1px 2px')) twShadow = 'shadow-sm';
                if (twShadow && !fc.classes.includes(twShadow)) {
                  const currentShadow = ['shadow-none','shadow-sm','shadow','shadow-md','shadow-lg','shadow-xl','shadow-2xl'].find(v => fc.classes.includes(v));
                  if (currentShadow && currentShadow !== twShadow) {
                    diffs.push({
                      line: fc.line, property: 'boxShadow',
                      reference: `(${twShadow})`, current: currentShadow,
                      suggestion: `${currentShadow} → ${twShadow}`,
                    });
                  }
                }
              }

              // fontStyle 비교
              if (refEl.fontStyle) {
                const twFSt = { 'italic':'italic' }[refEl.fontStyle];
                if (twFSt && !fc.classes.includes(twFSt)) {
                  diffs.push({
                    line: fc.line, property: 'fontStyle',
                    reference: `${refEl.fontStyle} (${twFSt})`,
                    current: 'normal', suggestion: `→ ${twFSt}`,
                  });
                }
              }

              // textAlign 비교
              if (refEl.textAlign && refEl.textAlign !== 'start') {
                const twTA = { 'left':'text-left', 'center':'text-center', 'right':'text-right', 'justify':'text-justify' }[refEl.textAlign];
                if (twTA && !fc.classes.includes(twTA)) {
                  const currentTA = ['text-left','text-center','text-right','text-justify'].find(v => fc.classes.includes(v));
                  if (currentTA && currentTA !== twTA) {
                    diffs.push({
                      line: fc.line, property: 'textAlign',
                      reference: `${refEl.textAlign} (${twTA})`,
                      current: currentTA, suggestion: `${currentTA} → ${twTA}`,
                    });
                  }
                }
              }

              // textTransform 비교
              if (refEl.textTransform && refEl.textTransform !== 'none') {
                const twTT = { 'uppercase':'uppercase', 'lowercase':'lowercase', 'capitalize':'capitalize' }[refEl.textTransform];
                if (twTT && !fc.classes.includes(twTT)) {
                  diffs.push({
                    line: fc.line, property: 'textTransform',
                    reference: `${refEl.textTransform} (${twTT})`,
                    current: 'none', suggestion: `→ ${twTT}`,
                  });
                }
              }

              // whiteSpace 비교
              if (refEl.whiteSpace) {
                const twWS = { 'nowrap':'whitespace-nowrap', 'pre':'whitespace-pre', 'pre-line':'whitespace-pre-line', 'pre-wrap':'whitespace-pre-wrap' }[refEl.whiteSpace];
                if (twWS && !fc.classes.includes(twWS)) {
                  diffs.push({
                    line: fc.line, property: 'whiteSpace',
                    reference: `${refEl.whiteSpace} (${twWS})`,
                    current: 'normal', suggestion: `→ ${twWS}`,
                  });
                }
              }

              // wordBreak 비교
              if (refEl.wordBreak) {
                const twWB = { 'break-all':'break-all', 'keep-all':'break-keep' }[refEl.wordBreak];
                if (twWB && !fc.classes.includes(twWB)) {
                  diffs.push({
                    line: fc.line, property: 'wordBreak',
                    reference: `${refEl.wordBreak} (${twWB})`,
                    current: 'normal', suggestion: `→ ${twWB}`,
                  });
                }
              }

              // overflowWrap 비교
              if (refEl.overflowWrap) {
                const twOW = { 'break-word':'break-words' }[refEl.overflowWrap];
                if (twOW && !fc.classes.includes(twOW)) {
                  diffs.push({
                    line: fc.line, property: 'overflowWrap',
                    reference: `${refEl.overflowWrap} (${twOW})`,
                    current: 'normal', suggestion: `→ ${twOW}`,
                  });
                }
              }

              // textDecoration 비교
              if (refEl.textDecoration) {
                const twTD = { 'underline':'underline', 'line-through':'line-through', 'overline':'overline' }[refEl.textDecoration];
                if (twTD && !fc.classes.includes(twTD)) {
                  diffs.push({
                    line: fc.line, property: 'textDecoration',
                    reference: `${refEl.textDecoration} (${twTD})`,
                    current: 'none', suggestion: `→ ${twTD}`,
                  });
                }
              }

              // textOverflow/overflow 비교
              if (refEl.textOverflow === 'ellipsis' && !fc.classes.includes('truncate')) {
                diffs.push({
                  line: fc.line, property: 'textOverflow',
                  reference: 'ellipsis (truncate)', current: 'clip',
                  suggestion: '→ truncate',
                });
              }
              if (refEl.overflow && refEl.overflow !== 'visible') {
                const twOF = { 'hidden':'overflow-hidden', 'auto':'overflow-auto', 'scroll':'overflow-scroll' }[refEl.overflow];
                if (twOF && !fc.classes.includes(twOF)) {
                  diffs.push({
                    line: fc.line, property: 'overflow',
                    reference: `${refEl.overflow} (${twOF})`,
                    current: '', suggestion: `→ ${twOF}`,
                  });
                }
              }

              // borderColor 비교 (gray 스케일)
              if (refEl.borderWidth && refEl.borderColor) {
                const borderColorMap = {
                  'rgb(229, 231, 235)': 'border-gray-200',
                  'rgb(209, 213, 219)': 'border-gray-300',
                  'rgb(156, 163, 175)': 'border-gray-400',
                };
                const twBC = borderColorMap[refEl.borderColor];
                if (twBC && !fc.classes.includes(twBC.replace('border-', ''))) {
                  const currentBC = Object.values(borderColorMap).find(v => fc.classes.includes(v.replace('border-', '')));
                  if (currentBC && currentBC !== twBC) {
                    diffs.push({
                      line: fc.line, property: 'borderColor',
                      reference: twBC, current: currentBC,
                      suggestion: `${currentBC} → ${twBC}`,
                    });
                  }
                }
              }

              // 아이콘 크기 비교
              if (refEl.svgWidth) {
                const iconSizeMap = { '12':'w-3 h-3', '16':'w-4 h-4', '20':'w-5 h-5', '24':'w-6 h-6', '32':'w-8 h-8' };
                const refSize = parseInt(refEl.svgWidth);
                const twIcon = iconSizeMap[String(refSize)];
                if (twIcon) {
                  const twW = twIcon.split(' ')[0]; // e.g., 'w-4'
                  if (!fc.classes.includes(twW)) {
                    const currentIcon = Object.values(iconSizeMap).map(v => v.split(' ')[0]).find(v => fc.classes.includes(v));
                    if (currentIcon) {
                      diffs.push({
                        line: fc.line, property: 'iconSize',
                        reference: `${refSize}px (${twIcon})`,
                        current: currentIcon, suggestion: `${currentIcon} → ${twW}`,
                      });
                    }
                  }
                }
              }

              // fontFamily 비교
              if (refEl.fontFamily) {
                const refFF = refEl.fontFamily;
                const fontClassPattern = /font-\[([^\]]+)\]|font-(sans|serif|mono)/;
                const currentFontMatch = fc.classes.match(fontClassPattern);
                const currentFont = currentFontMatch ? currentFontMatch[0] : null;
                const expectedFont = refFF.toLowerCase().includes('mono') ? 'font-mono'
                  : refFF.toLowerCase().includes('serif') ? 'font-serif' : 'font-sans';
                if (currentFont && currentFont !== expectedFont) {
                  diffs.push({
                    line: fc.line,
                    property: 'fontFamily',
                    reference: `${refFF} (${expectedFont})`,
                    current: currentFont,
                    suggestion: `${currentFont} → ${expectedFont}`,
                  });
                }
              }

              // flexDirection 비교
              if (refEl.flexDirection) {
                const twFD = { 'column':'flex-col', 'column-reverse':'flex-col-reverse', 'row-reverse':'flex-row-reverse' }[refEl.flexDirection];
                if (twFD && !fc.classes.includes(twFD)) {
                  const currentFD = ['flex-col','flex-col-reverse','flex-row-reverse','flex-row'].find(v => fc.classes.includes(v));
                  diffs.push({
                    line: fc.line, property: 'flexDirection',
                    reference: `${refEl.flexDirection} (${twFD})`,
                    current: currentFD || 'flex-row',
                    suggestion: `→ ${twFD}`,
                  });
                }
              }

              // flexWrap 비교
              if (refEl.flexWrap) {
                const twFW = { 'wrap':'flex-wrap', 'wrap-reverse':'flex-wrap-reverse' }[refEl.flexWrap];
                if (twFW && !fc.classes.includes(twFW)) {
                  diffs.push({
                    line: fc.line, property: 'flexWrap',
                    reference: `${refEl.flexWrap} (${twFW})`,
                    current: 'flex-nowrap', suggestion: `→ ${twFW}`,
                  });
                }
              }

              // alignItems 비교
              if (refEl.alignItems) {
                const twAI = { 'flex-start':'items-start', 'flex-end':'items-end', 'center':'items-center', 'baseline':'items-baseline', 'stretch':'items-stretch' }[refEl.alignItems];
                if (twAI && !fc.classes.includes(twAI)) {
                  const currentAI = ['items-start','items-end','items-center','items-baseline','items-stretch'].find(v => fc.classes.includes(v));
                  if (currentAI && currentAI !== twAI) {
                    diffs.push({
                      line: fc.line, property: 'alignItems',
                      reference: `${refEl.alignItems} (${twAI})`,
                      current: currentAI, suggestion: `${currentAI} → ${twAI}`,
                    });
                  }
                }
              }

              // justifyContent 비교
              if (refEl.justifyContent) {
                const twJC = { 'flex-start':'justify-start', 'flex-end':'justify-end', 'center':'justify-center', 'space-between':'justify-between', 'space-around':'justify-around', 'space-evenly':'justify-evenly' }[refEl.justifyContent];
                if (twJC && !fc.classes.includes(twJC)) {
                  const currentJC = ['justify-start','justify-end','justify-center','justify-between','justify-around','justify-evenly'].find(v => fc.classes.includes(v));
                  if (currentJC && currentJC !== twJC) {
                    diffs.push({
                      line: fc.line, property: 'justifyContent',
                      reference: `${refEl.justifyContent} (${twJC})`,
                      current: currentJC, suggestion: `${currentJC} → ${twJC}`,
                    });
                  }
                }
              }

              // gridTemplateColumns 비교
              if (refEl.gridTemplateColumns) {
                const repeatMatch = refEl.gridTemplateColumns.match(/repeat\((\d+),/);
                const colCount = repeatMatch ? repeatMatch[1] : refEl.gridTemplateColumns.split(/\s+/).length;
                const twGC = `grid-cols-${colCount}`;
                if (!fc.classes.includes(twGC)) {
                  const currentGC = fc.classes.match(/grid-cols-(\d+)/)?.[0];
                  if (currentGC) {
                    diffs.push({
                      line: fc.line, property: 'gridTemplateColumns',
                      reference: `${refEl.gridTemplateColumns} (${twGC})`,
                      current: currentGC, suggestion: `${currentGC} → ${twGC}`,
                    });
                  }
                }
              }

              // gridTemplateRows 비교
              if (refEl.gridTemplateRows) {
                const repeatMatch = refEl.gridTemplateRows.match(/repeat\((\d+),/);
                const rowCount = repeatMatch ? repeatMatch[1] : refEl.gridTemplateRows.split(/\s+/).length;
                const twGR = `grid-rows-${rowCount}`;
                if (!fc.classes.includes(twGR)) {
                  const currentGR = fc.classes.match(/grid-rows-(\d+)/)?.[0];
                  if (currentGR) {
                    diffs.push({
                      line: fc.line, property: 'gridTemplateRows',
                      reference: `${refEl.gridTemplateRows} (${twGR})`,
                      current: currentGR, suggestion: `${currentGR} → ${twGR}`,
                    });
                  }
                }
              }

              // gridColumn span 비교
              if (refEl.gridColumn) {
                const spanMatch = refEl.gridColumn.match(/span\s+(\d+)/);
                if (spanMatch) {
                  const twSpan = `col-span-${spanMatch[1]}`;
                  if (!fc.classes.includes(twSpan)) {
                    const currentSpan = fc.classes.match(/col-span-(\d+|full)/)?.[0];
                    if (currentSpan && currentSpan !== twSpan) {
                      diffs.push({
                        line: fc.line, property: 'gridColumn',
                        reference: `${refEl.gridColumn} (${twSpan})`,
                        current: currentSpan, suggestion: `${currentSpan} → ${twSpan}`,
                      });
                    }
                  }
                }
              }

              // gridRow span 비교
              if (refEl.gridRow) {
                const spanMatch = refEl.gridRow.match(/span\s+(\d+)/);
                if (spanMatch) {
                  const twSpan = `row-span-${spanMatch[1]}`;
                  if (!fc.classes.includes(twSpan)) {
                    const currentSpan = fc.classes.match(/row-span-(\d+|full)/)?.[0];
                    if (currentSpan && currentSpan !== twSpan) {
                      diffs.push({
                        line: fc.line, property: 'gridRow',
                        reference: `${refEl.gridRow} (${twSpan})`,
                        current: currentSpan, suggestion: `${currentSpan} → ${twSpan}`,
                      });
                    }
                  }
                }
              }

              // flexGrow/Shrink/Basis 비교
              if (refEl.flexGrow) {
                const twFG = { '0':'grow-0', '1':'grow' }[refEl.flexGrow];
                if (twFG && !fc.classes.includes(twFG)) {
                  diffs.push({
                    line: fc.line, property: 'flexGrow',
                    reference: `${refEl.flexGrow} (${twFG})`,
                    current: '', suggestion: `→ ${twFG}`,
                  });
                }
              }
              if (refEl.flexShrink) {
                const twFS = { '0':'shrink-0', '1':'shrink' }[refEl.flexShrink];
                if (twFS && !fc.classes.includes(twFS)) {
                  diffs.push({
                    line: fc.line, property: 'flexShrink',
                    reference: `${refEl.flexShrink} (${twFS})`,
                    current: '', suggestion: `→ ${twFS}`,
                  });
                }
              }
              if (refEl.flexBasis) {
                const basisPx = parseFloat(refEl.flexBasis);
                const basisMap = { 0:'basis-0', 64:'basis-16', 128:'basis-32', 256:'basis-64' };
                const twBasis = basisMap[basisPx] || `basis-[${refEl.flexBasis}]`;
                if (!fc.classes.includes(twBasis)) {
                  const currentBasis = fc.classes.match(/basis-(\d+|\[[\w%]+\])/)?.[0];
                  if (currentBasis && currentBasis !== twBasis) {
                    diffs.push({
                      line: fc.line, property: 'flexBasis',
                      reference: `${refEl.flexBasis} (${twBasis})`,
                      current: currentBasis, suggestion: `${currentBasis} → ${twBasis}`,
                    });
                  }
                }
              }

              // placeItems 비교
              if (refEl.placeItems) {
                const twPI = { 'center':'place-items-center', 'start':'place-items-start', 'end':'place-items-end', 'stretch':'place-items-stretch' }[refEl.placeItems];
                if (twPI && !fc.classes.includes(twPI)) {
                  diffs.push({
                    line: fc.line, property: 'placeItems',
                    reference: `${refEl.placeItems} (${twPI})`,
                    current: '', suggestion: `→ ${twPI}`,
                  });
                }
              }

              // order 비교
              if (refEl.order) {
                const twOrd = { '1':'order-1', '2':'order-2', '3':'order-3', '-1':'order-first', '9999':'order-last', '0':'order-none' }[refEl.order];
                if (twOrd && !fc.classes.includes(twOrd)) {
                  diffs.push({
                    line: fc.line, property: 'order',
                    reference: `${refEl.order} (${twOrd})`,
                    current: '', suggestion: `→ ${twOrd}`,
                  });
                }
              }

              // gap 비교
              if (refEl.gap) {
                const gapPx = parseFloat(refEl.gap);
                const gapRem = gapPx / 4;
                const gapMap = { 0:'0', 1:'1', 2:'2', 3:'3', 4:'4', 5:'5', 6:'6', 8:'8', 10:'10', 12:'12' };
                const twGap = gapMap[gapRem] ? `gap-${gapMap[gapRem]}` : `gap-[${gapPx}px]`;
                if (!fc.classes.includes(twGap)) {
                  const currentGap = fc.classes.match(/gap-(\d+|\[[\dpx]+\])/)?.[0];
                  if (currentGap && currentGap !== twGap) {
                    diffs.push({
                      line: fc.line, property: 'gap',
                      reference: `${refEl.gap} (${twGap})`,
                      current: currentGap, suggestion: `${currentGap} → ${twGap}`,
                    });
                  }
                }
              }

              // === 새 속성 비교 ===

              // aspectRatio 비교
              if (refEl.aspectRatio) {
                const twAR = TAILWIND_MAP.aspectRatio[refEl.aspectRatio];
                if (twAR && !fc.classes.includes(twAR)) {
                  diffs.push({ line: fc.line, property: 'aspectRatio', reference: `${refEl.aspectRatio} (${twAR})`, current: '', suggestion: `→ ${twAR}` });
                }
              }

              // objectFit 비교
              if (refEl.objectFit) {
                const twOF = TAILWIND_MAP.objectFit[refEl.objectFit];
                if (twOF && !fc.classes.includes(twOF)) {
                  diffs.push({ line: fc.line, property: 'objectFit', reference: `${refEl.objectFit} (${twOF})`, current: '', suggestion: `→ ${twOF}` });
                }
              }

              // objectPosition 비교
              if (refEl.objectPosition) {
                const twOP = TAILWIND_MAP.objectPosition[refEl.objectPosition];
                if (twOP && !fc.classes.includes(twOP)) {
                  diffs.push({ line: fc.line, property: 'objectPosition', reference: `${refEl.objectPosition} (${twOP})`, current: '', suggestion: `→ ${twOP}` });
                }
              }

              // mixBlendMode 비교
              if (refEl.mixBlendMode) {
                const twMBM = TAILWIND_MAP.mixBlendMode[refEl.mixBlendMode];
                if (twMBM && !fc.classes.includes(twMBM)) {
                  diffs.push({ line: fc.line, property: 'mixBlendMode', reference: `${refEl.mixBlendMode} (${twMBM})`, current: '', suggestion: `→ ${twMBM}` });
                }
              }

              // visibility 비교
              if (refEl.visibility) {
                const twVis = TAILWIND_MAP.visibility[refEl.visibility];
                if (twVis && !fc.classes.includes(twVis)) {
                  diffs.push({ line: fc.line, property: 'visibility', reference: `${refEl.visibility} (${twVis})`, current: '', suggestion: `→ ${twVis}` });
                }
              }

              // pointerEvents 비교
              if (refEl.pointerEvents) {
                const twPE = TAILWIND_MAP.pointerEvents[refEl.pointerEvents];
                if (twPE && !fc.classes.includes(twPE)) {
                  diffs.push({ line: fc.line, property: 'pointerEvents', reference: `${refEl.pointerEvents} (${twPE})`, current: '', suggestion: `→ ${twPE}` });
                }
              }

              // userSelect 비교
              if (refEl.userSelect) {
                const twUS = TAILWIND_MAP.userSelect[refEl.userSelect];
                if (twUS && !fc.classes.includes(twUS)) {
                  diffs.push({ line: fc.line, property: 'userSelect', reference: `${refEl.userSelect} (${twUS})`, current: '', suggestion: `→ ${twUS}` });
                }
              }

              // resize 비교
              if (refEl.resize) {
                const twRS = TAILWIND_MAP.resize[refEl.resize];
                if (twRS && !fc.classes.includes(twRS)) {
                  diffs.push({ line: fc.line, property: 'resize', reference: `${refEl.resize} (${twRS})`, current: '', suggestion: `→ ${twRS}` });
                }
              }

              // scrollBehavior 비교
              if (refEl.scrollBehavior) {
                const twSB = TAILWIND_MAP.scrollBehavior[refEl.scrollBehavior];
                if (twSB && !fc.classes.includes(twSB)) {
                  diffs.push({ line: fc.line, property: 'scrollBehavior', reference: `${refEl.scrollBehavior} (${twSB})`, current: '', suggestion: `→ ${twSB}` });
                }
              }

              // scrollSnapType 비교
              if (refEl.scrollSnapType) {
                const twSST = TAILWIND_MAP.scrollSnapType[refEl.scrollSnapType];
                if (twSST && !fc.classes.includes(twSST.split(' ')[0])) {
                  diffs.push({ line: fc.line, property: 'scrollSnapType', reference: `${refEl.scrollSnapType} (${twSST})`, current: '', suggestion: `→ ${twSST}` });
                }
              }

              // scrollSnapAlign 비교
              if (refEl.scrollSnapAlign) {
                const twSSA = TAILWIND_MAP.scrollSnapAlign[refEl.scrollSnapAlign];
                if (twSSA && !fc.classes.includes(twSSA)) {
                  diffs.push({ line: fc.line, property: 'scrollSnapAlign', reference: `${refEl.scrollSnapAlign} (${twSSA})`, current: '', suggestion: `→ ${twSSA}` });
                }
              }

              // appearance 비교
              if (refEl.appearance) {
                const twApp = TAILWIND_MAP.appearance[refEl.appearance];
                if (twApp && !fc.classes.includes(twApp)) {
                  diffs.push({ line: fc.line, property: 'appearance', reference: `${refEl.appearance} (${twApp})`, current: '', suggestion: `→ ${twApp}` });
                }
              }

              // listStyleType 비교
              if (refEl.listStyleType) {
                const twLS = TAILWIND_MAP.listStyleType[refEl.listStyleType];
                if (twLS && !fc.classes.includes(twLS)) {
                  diffs.push({ line: fc.line, property: 'listStyleType', reference: `${refEl.listStyleType} (${twLS})`, current: '', suggestion: `→ ${twLS}` });
                }
              }

              // isolation 비교
              if (refEl.isolation) {
                const twIso = TAILWIND_MAP.isolation[refEl.isolation];
                if (twIso && !fc.classes.includes(twIso)) {
                  diffs.push({ line: fc.line, property: 'isolation', reference: `${refEl.isolation} (${twIso})`, current: '', suggestion: `→ ${twIso}` });
                }
              }

              // columns 비교
              if (refEl.columns) {
                const twCol = TAILWIND_MAP.columns[refEl.columns];
                if (twCol && !fc.classes.includes(twCol)) {
                  diffs.push({ line: fc.line, property: 'columns', reference: `${refEl.columns} (${twCol})`, current: '', suggestion: `→ ${twCol}` });
                }
              }

              // filter 비교
              if (refEl.filter) {
                const twFilter = typeof TAILWIND_MAP.filter === 'function' ? TAILWIND_MAP.filter(refEl.filter) : null;
                if (twFilter) {
                  diffs.push({ line: fc.line, property: 'filter', reference: `${refEl.filter} (${twFilter})`, current: '', suggestion: `→ ${twFilter}` });
                }
              }

              // backdropFilter 비교
              if (refEl.backdropFilter) {
                const twBDF = typeof TAILWIND_MAP.backdropFilter === 'function' ? TAILWIND_MAP.backdropFilter(refEl.backdropFilter) : null;
                if (twBDF) {
                  diffs.push({ line: fc.line, property: 'backdropFilter', reference: `${refEl.backdropFilter} (${twBDF})`, current: '', suggestion: `→ ${twBDF}` });
                }
              }

              // maxWidth 비교
              if (refEl.maxWidth && refEl.maxWidth !== 'none') {
                const twMW = typeof TAILWIND_MAP.maxWidth === 'function' ? TAILWIND_MAP.maxWidth(refEl.maxWidth) : null;
                if (twMW && !fc.classes.includes(twMW)) {
                  const currentMW = fc.classes.match(/max-w-(\w+|\[[\w%]+\])/)?.[0];
                  if (currentMW && currentMW !== twMW) {
                    diffs.push({ line: fc.line, property: 'maxWidth', reference: `${refEl.maxWidth} (${twMW})`, current: currentMW, suggestion: `${currentMW} → ${twMW}` });
                  }
                }
              }

              // transformOrigin 비교
              if (refEl.transformOrigin) {
                const twTO = TAILWIND_MAP.transformOrigin[refEl.transformOrigin];
                if (twTO && !fc.classes.includes(twTO)) {
                  diffs.push({ line: fc.line, property: 'transformOrigin', reference: `${refEl.transformOrigin} (${twTO})`, current: '', suggestion: `→ ${twTO}` });
                }
              }

              // outline 비교
              if (refEl.outline) {
                // outline ring 패턴 검출
                if (refEl.outline.includes('2px') && !fc.classes.includes('ring-2') && !fc.classes.includes('outline')) {
                  diffs.push({ line: fc.line, property: 'outline', reference: refEl.outline, current: '', suggestion: '→ ring-2 또는 outline' });
                }
              }

              // textShadow 비교
              if (refEl.textShadow) {
                if (!fc.classes.includes('drop-shadow')) {
                  diffs.push({ line: fc.line, property: 'textShadow', reference: refEl.textShadow, current: '', suggestion: '→ drop-shadow-* (커스텀)' });
                }
              }

              // backgroundImage (gradient) 비교
              if (refEl.backgroundImage) {
                const hasGradient = fc.classes.match(/bg-gradient/);
                if (!hasGradient) {
                  diffs.push({ line: fc.line, property: 'backgroundImage', reference: refEl.backgroundImage.substring(0, 60), current: '', suggestion: '→ bg-gradient-to-* (커스텀)' });
                }
              }

              // accentColor 비교
              if (refEl.accentColor) {
                if (!fc.classes.match(/accent-/)) {
                  diffs.push({ line: fc.line, property: 'accentColor', reference: refEl.accentColor, current: '', suggestion: '→ accent-* (커스텀)' });
                }
              }

              // caretColor 비교
              if (refEl.caretColor) {
                if (!fc.classes.match(/caret-/)) {
                  diffs.push({ line: fc.line, property: 'caretColor', reference: refEl.caretColor, current: '', suggestion: '→ caret-* (커스텀)' });
                }
              }

              // === 검색/필터/드롭다운 전용 속성 비교 ===

              // 검색 인풋 속성
              if (refEl.searchInputPadding) {
                const padValues = refEl.searchInputPadding.split(' ').map(v => parseFloat(v));
                const spMap = { 0:'0',1:'1',2:'2',3:'3',4:'4',5:'5',6:'6',8:'8',10:'10',12:'12' };
                const pyVal = spMap[padValues[0] / 4];
                const pxVal = spMap[(padValues[1] || padValues[0]) / 4];
                if (pyVal && pxVal) {
                  const twPy = `py-${pyVal}`;
                  const twPx = `px-${pxVal}`;
                  if (!fc.classes.includes(twPy) || !fc.classes.includes(twPx)) {
                    diffs.push({ line: fc.line, property: 'searchInputPadding', reference: `${refEl.searchInputPadding} (${twPy} ${twPx})`, current: '', suggestion: `→ ${twPy} ${twPx}` });
                  }
                }
              }
              if (refEl.searchInputFontSize) {
                const twFS = TAILWIND_MAP.fontSize[refEl.searchInputFontSize];
                if (twFS && !fc.classes.includes(twFS)) {
                  diffs.push({ line: fc.line, property: 'searchInputFontSize', reference: `${refEl.searchInputFontSize} (${twFS})`, current: '', suggestion: `→ ${twFS}` });
                }
              }
              if (refEl.searchInputBorderRadius) {
                const brMap = { '4px':'rounded-sm','6px':'rounded-md','8px':'rounded-lg','12px':'rounded-xl','9999px':'rounded-full' };
                const twBR = brMap[refEl.searchInputBorderRadius];
                if (twBR && !fc.classes.includes(twBR)) {
                  diffs.push({ line: fc.line, property: 'searchInputBorderRadius', reference: `${refEl.searchInputBorderRadius} (${twBR})`, current: '', suggestion: `→ ${twBR}` });
                }
              }
              if (refEl.searchInputBgColor && refEl.searchInputBgColor !== 'rgba(0, 0, 0, 0)') {
                const bgMap = {
                  'rgb(249, 250, 251)': 'bg-gray-50', 'rgb(243, 244, 246)': 'bg-gray-100',
                  'rgb(255, 255, 255)': 'bg-white',
                };
                const twBG = bgMap[refEl.searchInputBgColor];
                if (twBG && !fc.classes.includes(twBG.replace('bg-', ''))) {
                  diffs.push({ line: fc.line, property: 'searchInputBgColor', reference: twBG, current: '', suggestion: `→ ${twBG}` });
                }
              }
              // 검색 아이콘
              if (refEl.searchIconSize) {
                const [w, h] = refEl.searchIconSize.split('×').map(s => parseInt(s.trim()));
                const iconMap = { 12:'w-3 h-3', 16:'w-4 h-4', 20:'w-5 h-5', 24:'w-6 h-6' };
                const twIcon = iconMap[w];
                if (twIcon) {
                  const twW = twIcon.split(' ')[0];
                  if (!fc.classes.includes(twW)) {
                    diffs.push({ line: fc.line, property: 'searchIconSize', reference: `${refEl.searchIconSize} (${twIcon})`, current: '', suggestion: `→ ${twIcon}` });
                  }
                }
              }
              if (refEl.searchIconColor) {
                const colorMap = {
                  'rgb(107, 114, 128)': 'text-gray-500', 'rgb(156, 163, 175)': 'text-gray-400',
                  'rgb(75, 85, 99)': 'text-gray-600',
                };
                const twColor = colorMap[refEl.searchIconColor];
                if (twColor && !fc.classes.includes(twColor.replace('text-', ''))) {
                  diffs.push({ line: fc.line, property: 'searchIconColor', reference: twColor, current: '', suggestion: `→ ${twColor}` });
                }
              }

              // 드롭다운 패널 속성
              if (refEl.dropdownMaxHeight) {
                const mhPx = parseFloat(refEl.dropdownMaxHeight);
                const twMH = mhPx <= 256 ? `max-h-64` : mhPx <= 384 ? 'max-h-96' : `max-h-[${mhPx}px]`;
                if (!fc.classes.includes(twMH) && !fc.classes.match(/max-h-/)) {
                  diffs.push({ line: fc.line, property: 'dropdownMaxHeight', reference: `${refEl.dropdownMaxHeight} (${twMH})`, current: '', suggestion: `→ ${twMH}` });
                }
              }
              if (refEl.dropdownOverflowY && refEl.dropdownOverflowY !== 'visible') {
                const twOF = { 'auto':'overflow-y-auto', 'scroll':'overflow-y-scroll', 'hidden':'overflow-y-hidden' }[refEl.dropdownOverflowY];
                if (twOF && !fc.classes.includes(twOF)) {
                  diffs.push({ line: fc.line, property: 'dropdownOverflowY', reference: `${refEl.dropdownOverflowY} (${twOF})`, current: '', suggestion: `→ ${twOF}` });
                }
              }
              if (refEl.dropdownPadding) {
                const padValues = refEl.dropdownPadding.split(' ').map(v => parseFloat(v));
                const spMap = { 0:'0',0.5:'0.5',1:'1',1.5:'1.5',2:'2',3:'3',4:'4' };
                const pyVal = spMap[padValues[0] / 4];
                if (pyVal) {
                  const twPy = `py-${pyVal}`;
                  if (!fc.classes.includes(twPy)) {
                    diffs.push({ line: fc.line, property: 'dropdownPadding', reference: `${refEl.dropdownPadding} (${twPy})`, current: '', suggestion: `→ ${twPy}` });
                  }
                }
              }
              // 드롭다운 아이템 속성
              if (refEl.dropdownItemPadding) {
                const padValues = refEl.dropdownItemPadding.split(' ').map(v => parseFloat(v));
                const spMap = { 0:'0',1:'1',2:'2',3:'3',4:'4',5:'5',6:'6',8:'8' };
                const pyVal = spMap[padValues[0] / 4];
                const pxVal = spMap[(padValues[1] || padValues[0]) / 4];
                if (pyVal && pxVal) {
                  const twPy = `py-${pyVal}`;
                  const twPx = `px-${pxVal}`;
                  if (!fc.classes.includes(twPy) || !fc.classes.includes(twPx)) {
                    diffs.push({ line: fc.line, property: 'dropdownItemPadding', reference: `${refEl.dropdownItemPadding} (${twPy} ${twPx})`, current: '', suggestion: `→ ${twPy} ${twPx}` });
                  }
                }
              }
              if (refEl.dropdownItemFontSize) {
                const twFS = TAILWIND_MAP.fontSize[refEl.dropdownItemFontSize];
                if (twFS && !fc.classes.includes(twFS)) {
                  diffs.push({ line: fc.line, property: 'dropdownItemFontSize', reference: `${refEl.dropdownItemFontSize} (${twFS})`, current: '', suggestion: `→ ${twFS}` });
                }
              }
              if (refEl.dropdownItemColor) {
                const colorMap = {
                  'rgb(17, 24, 39)': 'text-gray-900', 'rgb(55, 65, 81)': 'text-gray-700',
                  'rgb(75, 85, 99)': 'text-gray-600', 'rgb(107, 114, 128)': 'text-gray-500',
                };
                const twColor = colorMap[refEl.dropdownItemColor];
                if (twColor && !fc.classes.includes(twColor.replace('text-', ''))) {
                  diffs.push({ line: fc.line, property: 'dropdownItemColor', reference: twColor, current: '', suggestion: `→ ${twColor}` });
                }
              }

              // 필터 칩 속성
              if (refEl.chipBgColor && refEl.chipBgColor !== 'rgba(0, 0, 0, 0)') {
                const bgMap = {
                  'rgb(243, 244, 246)': 'bg-gray-100', 'rgb(229, 231, 235)': 'bg-gray-200',
                  'rgb(219, 234, 254)': 'bg-blue-100', 'rgb(239, 246, 255)': 'bg-blue-50',
                  'rgb(255, 255, 255)': 'bg-white',
                };
                const twBG = bgMap[refEl.chipBgColor];
                if (twBG && !fc.classes.includes(twBG.replace('bg-', ''))) {
                  diffs.push({ line: fc.line, property: 'chipBgColor', reference: twBG, current: '', suggestion: `→ ${twBG}` });
                }
              }
              if (refEl.chipActiveBgColor && refEl.chipActiveBgColor !== refEl.chipBgColor) {
                const bgMap = {
                  'rgb(37, 99, 235)': 'bg-blue-600', 'rgb(59, 130, 246)': 'bg-blue-500',
                  'rgb(219, 234, 254)': 'bg-blue-100', 'rgb(243, 244, 246)': 'bg-gray-100',
                };
                const twBG = bgMap[refEl.chipActiveBgColor];
                if (twBG) {
                  diffs.push({ line: fc.line, property: 'chipActiveBgColor', reference: twBG, current: '', suggestion: `활성 상태: → ${twBG}` });
                }
              }
              if (refEl.chipFontSize) {
                const twFS = TAILWIND_MAP.fontSize[refEl.chipFontSize];
                if (twFS && !fc.classes.includes(twFS)) {
                  diffs.push({ line: fc.line, property: 'chipFontSize', reference: `${refEl.chipFontSize} (${twFS})`, current: '', suggestion: `→ ${twFS}` });
                }
              }
              if (refEl.chipBorderRadius) {
                const brMap = { '4px':'rounded-sm','6px':'rounded-md','9999px':'rounded-full','16px':'rounded-2xl' };
                const twBR = brMap[refEl.chipBorderRadius];
                if (twBR && !fc.classes.includes(twBR)) {
                  diffs.push({ line: fc.line, property: 'chipBorderRadius', reference: `${refEl.chipBorderRadius} (${twBR})`, current: '', suggestion: `→ ${twBR}` });
                }
              }
              if (refEl.chipPadding) {
                const padValues = refEl.chipPadding.split(' ').map(v => parseFloat(v));
                const spMap = { 0:'0',0.5:'0.5',1:'1',1.5:'1.5',2:'2',3:'3',4:'4' };
                const pyVal = spMap[padValues[0] / 4];
                const pxVal = spMap[(padValues[1] || padValues[0]) / 4];
                if (pyVal && pxVal) {
                  diffs.push({ line: fc.line, property: 'chipPadding', reference: `${refEl.chipPadding} (py-${pyVal} px-${pxVal})`, current: '', suggestion: `→ py-${pyVal} px-${pxVal}` });
                }
              }

              // 필터 바 속성
              if (refEl.filterBarGap) {
                const gapPx = parseFloat(refEl.filterBarGap);
                const gapRem = gapPx / 4;
                const gapMap = { 1:'1', 2:'2', 3:'3', 4:'4', 6:'6', 8:'8' };
                const twGap = gapMap[gapRem] ? `gap-${gapMap[gapRem]}` : `gap-[${gapPx}px]`;
                if (!fc.classes.includes(twGap)) {
                  diffs.push({ line: fc.line, property: 'filterBarGap', reference: `${refEl.filterBarGap} (${twGap})`, current: '', suggestion: `→ ${twGap}` });
                }
              }
              if (refEl.filterBarFlexWrap && refEl.filterBarFlexWrap !== 'nowrap') {
                const twFW = { 'wrap':'flex-wrap', 'wrap-reverse':'flex-wrap-reverse' }[refEl.filterBarFlexWrap];
                if (twFW && !fc.classes.includes(twFW)) {
                  diffs.push({ line: fc.line, property: 'filterBarFlexWrap', reference: `${refEl.filterBarFlexWrap} (${twFW})`, current: '', suggestion: `→ ${twFW}` });
                }
              }
              if (refEl.filterBarAlignItems) {
                const twAI = { 'center':'items-center', 'flex-start':'items-start', 'flex-end':'items-end' }[refEl.filterBarAlignItems];
                if (twAI && !fc.classes.includes(twAI)) {
                  diffs.push({ line: fc.line, property: 'filterBarAlignItems', reference: `${refEl.filterBarAlignItems} (${twAI})`, current: '', suggestion: `→ ${twAI}` });
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

  // CSS 변수 비교 (tokens.json이 있으면)
  const tokensPath = 'tokens.json';
  if (fs.existsSync(tokensPath)) {
    const tokens = JSON.parse(fs.readFileSync(tokensPath, 'utf-8'));
    const refVars = tokens.tokens?.cssVariables?.light || {};
    // globals.css에서 로컬 CSS 변수 추출
    const globalsPath = path.join('src/app', 'globals.css');
    if (fs.existsSync(globalsPath)) {
      const globalsContent = fs.readFileSync(globalsPath, 'utf-8');
      const localVars = {};
      const varRegex = /--([\w-]+):\s*([^;]+);/g;
      let match;
      while ((match = varRegex.exec(globalsContent)) !== null) {
        localVars[`--${match[1]}`] = match[2].trim();
      }
      console.log('\n┌─── CSS Variables Comparison ─────────────────────────');
      for (const [varName, refValue] of Object.entries(refVars)) {
        const localValue = localVars[varName];
        if (!localValue) {
          console.log(`│ ${varName}: MISSING in local`);
        } else if (localValue !== refValue) {
          console.log(`│ ${varName}: ${localValue} → ${refValue}`);
        }
      }
      console.log('└' + '─'.repeat(55));
    }
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

## 이미지 모드 (`--from-image`)

URL 없이 **캡처 이미지**(PNG/JPG/WebP)만으로 디자인을 추출·비교·적용하는 모드.
와이어프레임, Figma 캡처, 스크린샷 등 정적 이미지를 입력으로 받는다.

```
/design-sync --from-image ./reference-design.png
```

### URL 모드 vs 이미지 모드 비교

| 항목 | URL 모드 | 이미지 모드 |
|------|---------|------------|
| **입력** | 라이브 URL | 이미지 파일 (PNG/JPG/WebP) |
| **추출 도구** | Playwright (computed styles) | AI Vision + Sharp (픽셀 분석) |
| **추출 정밀도** | 정확 (CSS 값 직접) | 높음~중간 (추정치) |
| **Phase 수** | 7단계 | 5단계 |
| **hover/인터랙션** | 캡처 가능 | 불가 (정적 이미지) |
| **반응형** | 멀티 뷰포트 | 단일 (이미지 크기 기준) |
| **싱크율 목표** | 95%+ | 85~90% |

### 워크플로우 (5단계)

```
/design-sync --from-image ./design.png

Step I-1 → AI Vision 토큰 추출    이미지 분석 → 색상/타이포/간격/레이아웃 토큰
Step I-2 → AI Vision 인벤토리     영역 분할 → 컴포넌트 식별·분류
Step I-3 → 비주얼 비교            로컬 스크린샷 vs 원본 이미지 pixelmatch
Step I-4 → 매핑 + 수정 적용       기존 Phase 4~5와 동일
Step I-5 → 최종 검증 + 정리       기존 Phase 6~7과 동일
```

---

### Phase I-1: AI Vision + Sharp 토큰 추출

URL 모드에서는 Playwright로 computed style을 직접 읽지만, 이미지 모드에서는 **Claude Vision**(멀티모달)으로 구조를 파악하고 **Sharp**(이미지 처리)로 픽셀을 정밀 분석한다.

#### I-1.1 AI Vision 구조 분석

Claude의 멀티모달 기능으로 이미지를 읽어 다음을 추출한다:

**추출 대상:**
| 항목 | 추출 내용 |
|------|----------|
| **레이아웃 구조** | sidebar/header/content 영역 존재 여부, 대략적 비율 |
| **컴포넌트 식별** | 카드, 테이블, 폼, 버튼, 네비게이션, 배지 등 |
| **타이포그래피** | 제목/본문/캡션 크기 비율, 굵기, 정렬 |
| **색상 테마** | 주요 색상 (primary, background, text, accent) |
| **간격 패턴** | 컴포넌트 간 간격 비율, padding 패턴 |
| **그리드/플렉스** | 컬럼 수, 정렬 방식, gap 패턴 |
| **아이콘** | 아이콘 존재 위치, 대략적 크기 |

**프롬프트 템플릿:**
```
이 UI 캡처 이미지를 분석하여 다음 정보를 JSON으로 추출해주세요:

1. layout: { type: "sidebar+header+content" | "header+content" | "fullwidth",
   sidebar: { width: "약 Npx", position: "left|right" },
   header: { height: "약 Npx" } }

2. components: [{
   type: "card|table|form|button|nav|badge|heading|text",
   area: "sidebar|header|content",
   position: { x: "약 N%", y: "약 N%", width: "약 N%", height: "약 Npx" },
   description: "컴포넌트 설명" }]

3. typography: {
   headings: [{ level: 1-5, estimatedSize: "Npx", weight: "bold|medium|normal", align: "left|center" }],
   body: { estimatedSize: "Npx", weight: "normal", lineHeight: "약 N배" },
   caption: { estimatedSize: "Npx", color: "밝은회색|중간회색 등" } }

4. colors: {
   primary: "색상 설명 (파란계열 등)",
   background: "흰색|밝은회색 등",
   text: { heading: "진한회색|검정", body: "중간회색", muted: "밝은회색" },
   accent: "강조색 설명",
   border: "보더 색상" }

5. spacing: {
   density: "compact|normal|spacious",
   componentGap: "약 Npx",
   sectionGap: "약 Npx",
   cardPadding: "약 Npx" }

6. borders: { radius: "none|small|medium|large", style: "solid|none", color: "설명" }
```

#### I-1.2 Sharp 픽셀 분석

AI Vision의 추정치를 **Sharp 라이브러리**로 정밀 보정한다.

**분석 항목:**

| 분석 | 방법 | 출력 |
|------|------|------|
| **색상 팔레트** | 이미지 전체 픽셀 → k-means 클러스터링 (k=15) | 상위 15개 색상 + 빈도 + Tailwind 매핑 |
| **영역 바운딩박스** | 행/열별 색상 변화 감지 → 경계선 추출 | sidebar/header/content 좌표 |
| **간격 측정** | 동일 배경색 영역 간 거리 측정 | gap/padding 값 (px) |
| **텍스트 영역 높이** | 텍스트 배경과 다른 영역의 높이 → fontSize 추정 | 높이 × 0.75 ≈ fontSize |
| **보더 감지** | 1px 너비 직선 감지 (수평/수직) | border 존재 여부, 색상 |
| **그림자 감지** | 영역 경계 주변 그라데이션 감지 | shadow 존재 여부, 크기 |

**스크립트 템플릿 E: analyze-image.js**

```javascript
import sharp from 'sharp';
import fs from 'fs';

const IMAGE_PATH = '<<IMAGE_PATH>>';

// --- 색상 팔레트 추출 ---
async function extractColorPalette(imagePath, sampleSize = 10000) {
  const { data, info } = await sharp(imagePath)
    .raw()
    .toBuffer({ resolveWithObject: true });

  const { width, height, channels } = info;
  const totalPixels = width * height;
  const step = Math.max(1, Math.floor(totalPixels / sampleSize));

  // 색상 빈도 집계 (8비트 양자화로 유사 색상 병합)
  const colorMap = new Map();
  for (let i = 0; i < totalPixels; i += step) {
    const offset = i * channels;
    // 8단계 양자화 (32 단위로 반올림)
    const r = Math.round(data[offset] / 32) * 32;
    const g = Math.round(data[offset + 1] / 32) * 32;
    const b = Math.round(data[offset + 2] / 32) * 32;
    const key = `${r},${g},${b}`;
    colorMap.set(key, (colorMap.get(key) || 0) + 1);
  }

  // 빈도순 정렬 → 상위 15개
  const sorted = [...colorMap.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 15)
    .map(([rgb, count]) => {
      const [r, g, b] = rgb.split(',').map(Number);
      return {
        rgb: `rgb(${r}, ${g}, ${b})`,
        hex: `#${r.toString(16).padStart(2,'0')}${g.toString(16).padStart(2,'0')}${b.toString(16).padStart(2,'0')}`,
        frequency: (count / sampleSize * 100).toFixed(1) + '%',
        tailwind: mapToTailwindColor(r, g, b),
      };
    });

  return sorted;
}

// Tailwind gray 스케일 근사 매핑
function mapToTailwindColor(r, g, b) {
  // 무채색 감지 (R≈G≈B)
  const isGray = Math.max(r, g, b) - Math.min(r, g, b) < 30;
  if (isGray) {
    const avg = (r + g + b) / 3;
    if (avg > 250) return 'white';
    if (avg > 245) return 'gray-50';
    if (avg > 235) return 'gray-100';
    if (avg > 215) return 'gray-200';
    if (avg > 190) return 'gray-300';
    if (avg > 150) return 'gray-400';
    if (avg > 115) return 'gray-500';
    if (avg > 85) return 'gray-600';
    if (avg > 60) return 'gray-700';
    if (avg > 40) return 'gray-800';
    if (avg > 20) return 'gray-900';
    return 'gray-950';
  }
  // 유채색 — 가장 가까운 Tailwind 색상 계열 반환
  if (r > g && r > b) return b > 100 ? 'purple/pink' : 'red/orange';
  if (g > r && g > b) return 'green';
  if (b > r && b > g) return r > 100 ? 'purple' : 'blue';
  return 'neutral';
}

// --- 영역 경계 감지 ---
async function detectRegions(imagePath) {
  const { data, info } = await sharp(imagePath)
    .greyscale()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const { width, height } = info;

  // 수직 스캔: 사이드바 경계 찾기
  // 좌측에서 우측으로 스캔하며 급격한 색상 변화 위치 감지
  let sidebarRight = 0;
  for (let x = 150; x < Math.min(350, width); x++) {
    let changes = 0;
    for (let y = 0; y < height; y += 5) {
      const curr = data[y * width + x];
      const next = data[y * width + x + 1];
      if (Math.abs(curr - next) > 30) changes++;
    }
    // 수직 경계선 = 많은 y 좌표에서 색상 변화
    if (changes > height / 20) {
      sidebarRight = x;
      break;
    }
  }

  // 수평 스캔: 헤더 하단 경계 찾기
  let headerBottom = 0;
  for (let y = 30; y < Math.min(120, height); y++) {
    let changes = 0;
    const start = sidebarRight || 0;
    for (let x = start; x < width; x += 5) {
      const curr = data[y * width + x];
      const next = data[(y + 1) * width + x];
      if (Math.abs(curr - next) > 30) changes++;
    }
    if (changes > (width - start) / 20) {
      headerBottom = y;
      break;
    }
  }

  return {
    sidebar: sidebarRight > 0 ? { x: 0, y: 0, width: sidebarRight, height } : null,
    header: headerBottom > 0 ? { x: sidebarRight, y: 0, width: width - sidebarRight, height: headerBottom } : null,
    content: { x: sidebarRight, y: headerBottom, width: width - sidebarRight, height: height - headerBottom },
    imageSize: { width, height },
  };
}

// --- 텍스트 영역 높이 기반 fontSize 추정 ---
async function estimateFontSizes(imagePath, regions) {
  const { data, info } = await sharp(imagePath)
    .greyscale()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const { width } = info;

  // 콘텐츠 영역에서 텍스트 행 높이 감지
  const contentRegion = regions.content;
  const rowHeights = [];
  let inTextRow = false;
  let rowStart = 0;

  for (let y = contentRegion.y; y < contentRegion.y + contentRegion.height; y++) {
    // 행의 평균 밝기 계산
    let sum = 0;
    for (let x = contentRegion.x; x < contentRegion.x + contentRegion.width; x += 3) {
      sum += data[y * width + x];
    }
    const avgBrightness = sum / (contentRegion.width / 3);

    // 텍스트 행 = 배경보다 어두운 영역
    const isText = avgBrightness < 230;
    if (isText && !inTextRow) {
      inTextRow = true;
      rowStart = y;
    } else if (!isText && inTextRow) {
      inTextRow = false;
      const rowHeight = y - rowStart;
      if (rowHeight > 8 && rowHeight < 80) {
        rowHeights.push(rowHeight);
      }
    }
  }

  // 높이 → fontSize 추정 (높이 × 0.75)
  const fontSizes = [...new Set(rowHeights.map(h => Math.round(h * 0.75)))]
    .sort((a, b) => a - b);

  // Tailwind 스케일에 가장 가까운 값으로 스냅
  const TAILWIND_SCALE = [12, 14, 16, 18, 20, 24, 30, 36, 48, 60, 72];
  const snapped = fontSizes.map(fs => {
    const nearest = TAILWIND_SCALE.reduce((a, b) =>
      Math.abs(b - fs) < Math.abs(a - fs) ? b : a);
    return { estimated: fs, snapped: nearest, tailwind: `text-${
      {12:'xs',14:'sm',16:'base',18:'lg',20:'xl',24:'2xl',30:'3xl',36:'4xl',48:'5xl',60:'6xl',72:'7xl'}[nearest] || `[${nearest}px]`
    }` };
  });

  return snapped;
}

// --- 간격 패턴 감지 ---
async function detectSpacing(imagePath, regions) {
  const { data, info } = await sharp(imagePath)
    .greyscale()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const { width } = info;
  const contentRegion = regions.content;

  // 콘텐츠 영역에서 동일 배경색 수평 띠 (간격) 감지
  const gaps = [];
  let inGap = false;
  let gapStart = 0;
  const bgThreshold = 245; // 밝은 배경

  for (let y = contentRegion.y; y < contentRegion.y + contentRegion.height; y++) {
    let sum = 0;
    for (let x = contentRegion.x; x < contentRegion.x + contentRegion.width; x += 5) {
      sum += data[y * width + x];
    }
    const avg = sum / (contentRegion.width / 5);
    const isBg = avg > bgThreshold;

    if (isBg && !inGap) {
      inGap = true;
      gapStart = y;
    } else if (!isBg && inGap) {
      inGap = false;
      const gapSize = y - gapStart;
      if (gapSize >= 4 && gapSize <= 96) {
        gaps.push(gapSize);
      }
    }
  }

  // 빈도순 정렬 → Tailwind 간격으로 매핑
  const gapFreq = new Map();
  gaps.forEach(g => {
    // 4px 단위로 스냅
    const snapped = Math.round(g / 4) * 4;
    gapFreq.set(snapped, (gapFreq.get(snapped) || 0) + 1);
  });

  return [...gapFreq.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8)
    .map(([px, count]) => ({ px: `${px}px`, count, tailwind: `${px / 4}` }));
}

// --- 메인 실행 ---
(async () => {
  console.log(`Analyzing image: ${IMAGE_PATH}`);
  console.log('='.repeat(60));

  // 1. 색상 팔레트
  console.log('\n[1/4] Extracting color palette...');
  const colors = await extractColorPalette(IMAGE_PATH);
  console.log(`  Found ${colors.length} dominant colors`);
  colors.forEach(c => console.log(`  ${c.hex} (${c.frequency}) → ${c.tailwind}`));

  // 2. 영역 감지
  console.log('\n[2/4] Detecting regions...');
  const regions = await detectRegions(IMAGE_PATH);
  console.log(`  Sidebar: ${regions.sidebar ? `${regions.sidebar.width}px wide` : 'not detected'}`);
  console.log(`  Header: ${regions.header ? `${regions.header.height}px tall` : 'not detected'}`);
  console.log(`  Content: ${regions.content.width}×${regions.content.height}px`);

  // 3. 폰트 크기 추정
  console.log('\n[3/4] Estimating font sizes...');
  const fontSizes = await estimateFontSizes(IMAGE_PATH, regions);
  fontSizes.forEach(f => console.log(`  ~${f.estimated}px → ${f.snapped}px (${f.tailwind})`));

  // 4. 간격 패턴
  console.log('\n[4/4] Detecting spacing patterns...');
  const spacing = await detectSpacing(IMAGE_PATH, regions);
  spacing.forEach(s => console.log(`  ${s.px} × ${s.count}회 → spacing-${s.tailwind}`));

  // tokens.json 생성 (URL 모드와 동일 포맷)
  const tokens = {
    meta: {
      source: IMAGE_PATH,
      mode: 'image',
      extractedAt: new Date().toISOString(),
      imageSize: regions.imageSize,
      confidence: 'MEDIUM', // 이미지 모드는 URL 모드보다 낮은 신뢰도
    },
    tokens: {
      colors: colors.map(c => ({
        value: c.rgb,
        hex: c.hex,
        tailwind: c.tailwind,
        frequency: c.frequency,
      })),
      typography: Object.fromEntries(
        fontSizes.map((f, i) => [
          i === 0 ? 'caption' : i === fontSizes.length - 1 ? 'h1' :
          i === fontSizes.length - 2 ? 'h2' : 'body',
          { fontSize: `${f.snapped}px`, tailwind: f.tailwind }
        ])
      ),
      spacing: {
        baseUnit: '4px',
        scale: spacing.map(s => s.px),
        dominant: spacing.slice(0, 3).map(s => s.px),
      },
      regions,
    },
  };

  fs.writeFileSync('tokens.json', JSON.stringify(tokens, null, 2));
  console.log('\n' + '='.repeat(60));
  console.log('Saved: tokens.json');
})().catch(console.error);
```

#### I-1.3 AI Vision + Sharp 결과 통합

Sharp의 정밀 데이터로 AI Vision의 추정치를 **보정**한다:

| 항목 | AI Vision (구조) | Sharp (정밀) | 통합 방법 |
|------|-----------------|-------------|----------|
| 색상 | "파란 계열 primary" | `#3B82F6` → `blue-500` | Sharp 우선 |
| 폰트 크기 | "제목은 큰 글자" | `~24px` → `text-2xl` | Sharp 측정 + Tailwind 스냅 |
| 레이아웃 | "sidebar + content" | sidebar 너비 `256px` | AI 구조 + Sharp 치수 |
| 간격 | "여유있는 간격" | `16px, 24px 반복` | Sharp 측정 + 패턴 |
| 컴포넌트 | "카드 3개 가로 배치" | 3등분 영역 감지 | AI 식별 + Sharp 좌표 |

---

### Phase I-2: AI Vision 컴포넌트 인벤토리

이미지를 **격자 분할**하여 영역별 컴포넌트를 식별한다.

#### I-2.1 영역 분할 전략

Phase I-1에서 감지한 regions를 기반으로 이미지를 크롭하여 개별 분석한다:

```
1. sidebar 영역 크롭 → AI Vision으로 메뉴 아이템, 로고, 아이콘 식별
2. header 영역 크롭 → AI Vision으로 검색바, 사용자 메뉴, 알림 아이콘 식별
3. content 영역 크롭 → AI Vision으로 카드, 테이블, 폼, 차트 식별
4. content를 추가 격자 분할 → 개별 컴포넌트 상세 분석
```

#### I-2.2 컴포넌트 상세 추출

각 식별된 컴포넌트에 대해:

```json
{
  "area": "content",
  "type": "card",
  "position": { "x": 300, "y": 100, "width": 320, "height": 180 },
  "styles": {
    "backgroundColor": "white",
    "borderRadius": "rounded-lg",
    "border": "border border-gray-200",
    "padding": "p-4 또는 p-6",
    "shadow": "shadow-sm 또는 none"
  },
  "children": [
    { "type": "heading", "estimatedSize": "text-sm", "weight": "font-medium" },
    { "type": "text", "estimatedSize": "text-2xl", "weight": "font-bold" },
    { "type": "text", "estimatedSize": "text-xs", "color": "text-gray-500" }
  ]
}
```

#### I-2.3 Sharp 영역 크롭 스크립트

```javascript
import sharp from 'sharp';
import fs from 'fs';

const IMAGE_PATH = '<<IMAGE_PATH>>';
const TOKENS_PATH = 'tokens.json';

(async () => {
  const tokens = JSON.parse(fs.readFileSync(TOKENS_PATH, 'utf-8'));
  const regions = tokens.tokens.regions;

  // 영역별 크롭 이미지 생성
  const crops = [];
  if (regions.sidebar) {
    const buf = await sharp(IMAGE_PATH)
      .extract({ left: regions.sidebar.x, top: regions.sidebar.y,
        width: regions.sidebar.width, height: regions.sidebar.height })
      .toBuffer();
    fs.writeFileSync('region-sidebar.png', buf);
    crops.push('region-sidebar.png');
    console.log(`Sidebar: ${regions.sidebar.width}×${regions.sidebar.height}px`);
  }

  if (regions.header) {
    const buf = await sharp(IMAGE_PATH)
      .extract({ left: regions.header.x, top: regions.header.y,
        width: regions.header.width, height: regions.header.height })
      .toBuffer();
    fs.writeFileSync('region-header.png', buf);
    crops.push('region-header.png');
    console.log(`Header: ${regions.header.width}×${regions.header.height}px`);
  }

  // 콘텐츠 영역 → 4분할 격자
  const cx = regions.content.x, cy = regions.content.y;
  const cw = regions.content.width, ch = regions.content.height;
  const halfW = Math.floor(cw / 2), halfH = Math.floor(ch / 2);

  const quadrants = [
    { name: 'content-tl', left: cx, top: cy, width: halfW, height: halfH },
    { name: 'content-tr', left: cx + halfW, top: cy, width: cw - halfW, height: halfH },
    { name: 'content-bl', left: cx, top: cy + halfH, width: halfW, height: ch - halfH },
    { name: 'content-br', left: cx + halfW, top: cy + halfH, width: cw - halfW, height: ch - halfH },
  ];

  for (const q of quadrants) {
    if (q.width > 10 && q.height > 10) {
      const buf = await sharp(IMAGE_PATH)
        .extract({ left: q.left, top: q.top, width: q.width, height: q.height })
        .toBuffer();
      fs.writeFileSync(`region-${q.name}.png`, buf);
      crops.push(`region-${q.name}.png`);
      console.log(`${q.name}: ${q.width}×${q.height}px`);
    }
  }

  console.log(`\nCropped ${crops.length} regions: ${crops.join(', ')}`);
  console.log('→ AI Vision으로 각 크롭 이미지를 분석하여 inventory.json 생성');
})().catch(console.error);
```

#### I-2.4 인벤토리 생성

AI Vision으로 각 크롭 이미지를 분석한 결과를 **URL 모드와 동일한 inventory.json 포맷**으로 통합한다:

```json
{
  "meta": { "source": "image", "imagePath": "./design.png" },
  "pages": {
    "main": {
      "sidebar": {
        "navigation": [
          { "area": "sidebar", "type": "navigation", "tag": "nav",
            "text": "Dashboard", "fontSize": "14px", "fontWeight": "500",
            "color": "text-gray-700", "bgColor": "transparent",
            "padding": "8px 16px", "borderRadius": "6px" }
        ]
      },
      "content": {
        "card": [
          { "area": "content", "type": "card", "tag": "div",
            "dimensions": "320 × 180",
            "bgColor": "white", "borderRadius": "8px",
            "border": "1px solid rgb(229,231,235)",
            "padding": "16px", "boxShadow": "none" }
        ]
      }
    }
  }
}
```

---

### Phase I-3: 비주얼 비교 (이미지 vs 로컬)

원본 이미지와 로컬 개발 서버의 스크린샷을 **pixelmatch**로 비교한다.

#### I-3.1 비교 방법

1. 원본 이미지를 Sharp로 리사이즈 (로컬 뷰포트 크기에 맞춤)
2. 로컬 개발 서버(`localhost:3000`)를 Playwright로 스크린샷
3. pixelmatch로 비교 → 싱크율 산출

```javascript
import sharp from 'sharp';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';
import fs from 'fs';

const IMAGE_PATH = '<<IMAGE_PATH>>';
const LOCAL_URL = 'http://localhost:3000';
const VIEWPORT = { width: 1366, height: 900 };

(async () => {
  // 1. 원본 이미지를 뷰포트 크기로 리사이즈 → PNG 변환
  const refBuffer = await sharp(IMAGE_PATH)
    .resize(VIEWPORT.width, VIEWPORT.height, { fit: 'contain', background: { r: 255, g: 255, b: 255 } })
    .png()
    .toBuffer();

  fs.writeFileSync('ref-resized.png', refBuffer);
  console.log(`Reference image resized to ${VIEWPORT.width}×${VIEWPORT.height}`);

  // 2. 로컬 스크린샷 캡처
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: VIEWPORT });
  await page.addInitScript(() => {
    const style = document.createElement('style');
    style.textContent = '*, *::before, *::after { animation-duration: 0s !important; transition-duration: 0s !important; }';
    document.head.appendChild(style);
  });
  await page.goto(LOCAL_URL, { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(2000);
  const localBuffer = await page.screenshot({ fullPage: false });
  fs.writeFileSync('local-screenshot.png', localBuffer);
  await browser.close();

  // 3. pixelmatch 비교
  const refPng = PNG.sync.read(refBuffer);
  const localPng = PNG.sync.read(localBuffer);

  const w = Math.min(refPng.width, localPng.width);
  const h = Math.min(refPng.height, localPng.height);

  function cropData(png, tw, th) {
    if (png.width === tw && png.height === th) return png.data;
    const out = Buffer.alloc(tw * th * 4);
    for (let y = 0; y < th; y++) {
      png.data.copy(out, y * tw * 4, y * png.width * 4, y * png.width * 4 + tw * 4);
    }
    return out;
  }

  const dataA = cropData(refPng, w, h);
  const dataB = cropData(localPng, w, h);
  const diff = new PNG({ width: w, height: h });

  // 이미지 모드는 기본 threshold를 0.2로 높임 (렌더링 차이 허용)
  const numDiff = pixelmatch(dataA, dataB, diff.data, w, h, {
    threshold: 0.2,
    includeAA: false,
  });

  const total = w * h;
  const syncRate = ((1 - numDiff / total) * 100).toFixed(1);

  fs.writeFileSync('diff-image-mode.png', PNG.sync.write(diff));

  console.log('\n' + '='.repeat(60));
  console.log('  IMAGE MODE VISUAL COMPARISON');
  console.log('='.repeat(60));
  console.log(`  Sync Rate: ${syncRate}%`);
  console.log(`  Diff pixels: ${numDiff.toLocaleString()} / ${total.toLocaleString()}`);
  console.log(`  Diff image: diff-image-mode.png`);

  // 정밀 비교
  const diff2 = new PNG({ width: w, height: h });
  const numDiff2 = pixelmatch(dataA, dataB, diff2.data, w, h, {
    threshold: 0.1,
    includeAA: false,
  });
  const syncRate2 = ((1 - numDiff2 / total) * 100).toFixed(1);
  fs.writeFileSync('diff-image-precision.png', PNG.sync.write(diff2));
  console.log(`  Precision Sync: ${syncRate2}%`);

  // 텍스트 마스킹 비교
  const browser2 = await chromium.launch({ headless: true });
  const page2 = await browser2.newPage({ viewport: VIEWPORT });
  await page2.addInitScript(() => {
    const style = document.createElement('style');
    style.textContent = `
      *, *::before, *::after { animation-duration: 0s !important; transition-duration: 0s !important; }
      h1,h2,h3,h4,h5,h6,p,span,a,label,li,td,th,button { color: transparent !important; }
    `;
    document.head.appendChild(style);
  });
  await page2.goto(LOCAL_URL, { waitUntil: 'networkidle', timeout: 30000 });
  await page2.waitForTimeout(2000);
  const maskedBuffer = await page2.screenshot({ fullPage: false });
  await browser2.close();

  // 원본도 텍스트 영역 마스킹 (Sharp로 텍스트 영역 블러)
  // 이미지 모드에서는 텍스트 정확도보다 레이아웃 비교가 중요
  const maskedPng = PNG.sync.read(maskedBuffer);
  const { width: mw, height: mh, dataA: mA, dataB: mB } = (() => {
    const tw = Math.min(refPng.width, maskedPng.width);
    const th = Math.min(refPng.height, maskedPng.height);
    return { width: tw, height: th, dataA: cropData(refPng, tw, th), dataB: cropData(maskedPng, tw, th) };
  })();
  const mdiff = new PNG({ width: mw, height: mh });
  const mNumDiff = pixelmatch(mA, mB, mdiff.data, mw, mh, { threshold: 0.2, includeAA: false });
  console.log(`  Layout-only Sync (text masked): ${((1 - mNumDiff / (mw * mh)) * 100).toFixed(1)}%`);

  console.log('-'.repeat(60));
})().catch(console.error);
```

#### I-3.2 이미지 모드 싱크율 해석

| 싱크율 | 판정 | 조치 |
|--------|------|------|
| 90%+ | 우수 | 미세 조정만 필요 |
| 80~90% | 양호 | 특정 영역 diff 이미지 분석 → 수동 조정 |
| 70~80% | 보통 | 레이아웃 구조부터 재검토 |
| < 70% | 미달 | AI Vision 분석 재실행, 컴포넌트 구조 재설계 |

**이미지 모드 특수 고려사항:**
- 텍스트 내용 차이는 무시 (마스킹 비교 우선)
- 아이콘 차이는 별도 처리 (종류가 다를 수 있음)
- 이미지/사진 콘텐츠는 비교 대상에서 제외
- 폰트 렌더링 차이는 threshold 0.2로 허용

---

### Phase I-4~I-5: 기존 Phase 4~7 합류

이미지 모드의 tokens.json, inventory.json이 생성되면, **기존 URL 모드의 Phase 4 (매핑 + Diff), Phase 5 (수정 적용), Phase 6 (최종 검증), Phase 7 (학습 + 정리)**를 그대로 실행한다.

유일한 차이:
- 비교 대상이 "URL 재캡처"가 아닌 "원본 이미지 (리사이즈)"
- threshold가 0.15가 아닌 0.2 (이미지 모드 허용 범위)
- hover/인터랙션 비교는 생략

---

### 이미지 모드 필요 의존성

```bash
npm install -D sharp         # 이미지 분석
npm install -D playwright    # 로컬 스크린샷
npm install -D pixelmatch    # 비교
npm install -D pngjs         # PNG 처리
```

---

## 규칙

- Playwright가 설치되어 있어야 한다 (`npx playwright install chromium`)
- `pixelmatch`와 `pngjs`가 devDependencies에 있어야 한다
- 이미지 모드 사용 시 `sharp`도 devDependencies에 있어야 한다
- 추출 스크립트는 `scripts/` 에 임시 작성 → 완료 후 삭제
- 스크린샷/diff 이미지도 완료 후 삭제
- `tokens.json`, `inventory.json`, `mapping.json`은 작업 중 프로젝트 루트에 생성 → 완료 후 삭제 (학습 저장 시 `learned/`로 복사)
- 수정 후 반드시 `npx tsc --noEmit && npm test` 검증
- **7 카테고리 × 21 속성** 모두 동일 깊이로 추출·비교
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

### 행간 (lineHeight)
| CSS | Tailwind |
|-----|----------|
| 16px | leading-4 |
| 20px | leading-5 |
| 24px | leading-6 |
| 28px | leading-7 |
| 32px | leading-8 |
| 36px | leading-9 |
| 40px | leading-10 |
| 1 | leading-none |
| 1.25 | leading-tight |
| 1.375 | leading-snug |
| 1.5 | leading-normal |
| 1.625 | leading-relaxed |
| 2 | leading-loose |

### 자간 (letterSpacing)
| CSS | Tailwind |
|-----|----------|
| -0.05em | tracking-tighter |
| -0.025em | tracking-tight |
| 0em / normal | tracking-normal |
| 0.025em | tracking-wide |
| 0.05em | tracking-wider |
| 0.1em | tracking-widest |

### 폰트 패밀리
| 패턴 | Tailwind |
|------|----------|
| sans-serif 계열 (Geist, Inter, Pretendard 등) | font-sans |
| serif 계열 (Georgia, Times 등) | font-serif |
| monospace 계열 (Geist Mono, JetBrains Mono 등) | font-mono |
| 커스텀 폰트 | font-[폰트명] |

### 폰트 스타일
| CSS | Tailwind |
|-----|----------|
| italic | italic |
| normal | not-italic |

### 텍스트 정렬
| CSS | Tailwind |
|-----|----------|
| left | text-left |
| center | text-center |
| right | text-right |
| justify | text-justify |

### 텍스트 변환
| CSS | Tailwind |
|-----|----------|
| uppercase | uppercase |
| lowercase | lowercase |
| capitalize | capitalize |
| none | normal-case |

### 공백 처리 (whiteSpace)
| CSS | Tailwind |
|-----|----------|
| nowrap | whitespace-nowrap |
| pre | whitespace-pre |
| pre-line | whitespace-pre-line |
| pre-wrap | whitespace-pre-wrap |
| normal | whitespace-normal |

### 단어 줄바꿈
| CSS | Tailwind |
|-----|----------|
| word-break: break-all | break-all |
| word-break: keep-all | break-keep |
| overflow-wrap: break-word | break-words |

### Flex 방향
| CSS | Tailwind |
|-----|----------|
| row | flex-row |
| row-reverse | flex-row-reverse |
| column | flex-col |
| column-reverse | flex-col-reverse |

### Flex 줄바꿈
| CSS | Tailwind |
|-----|----------|
| nowrap | flex-nowrap |
| wrap | flex-wrap |
| wrap-reverse | flex-wrap-reverse |

### 정렬 (alignItems)
| CSS | Tailwind |
|-----|----------|
| flex-start | items-start |
| flex-end | items-end |
| center | items-center |
| baseline | items-baseline |
| stretch | items-stretch |

### 배치 (justifyContent)
| CSS | Tailwind |
|-----|----------|
| flex-start | justify-start |
| flex-end | justify-end |
| center | justify-center |
| space-between | justify-between |
| space-around | justify-around |
| space-evenly | justify-evenly |

### Grid 컬럼
| CSS | Tailwind |
|-----|----------|
| repeat(1, minmax(0, 1fr)) | grid-cols-1 |
| repeat(2, minmax(0, 1fr)) | grid-cols-2 |
| repeat(3, minmax(0, 1fr)) | grid-cols-3 |
| repeat(4, minmax(0, 1fr)) | grid-cols-4 |
| repeat(6, minmax(0, 1fr)) | grid-cols-6 |
| repeat(12, minmax(0, 1fr)) | grid-cols-12 |
| 커스텀 | grid-cols-[값] |

### Grid Span
| CSS | Tailwind |
|-----|----------|
| span 1 / span 1 | col-span-1 |
| span 2 / span 2 | col-span-2 |
| span 3 / span 3 | col-span-3 |
| 1 / -1 | col-span-full |

### 아이콘 크기
| CSS (width/height) | Tailwind |
|-----|----------|
| 12px | w-3 h-3 |
| 16px | w-4 h-4 |
| 20px | w-5 h-5 |
| 24px | w-6 h-6 |
| 32px | w-8 h-8 |
| 40px | w-10 h-10 |
| 48px | w-12 h-12 |

### 텍스트 꾸밈 (textDecoration)
| CSS | Tailwind |
|-----|----------|
| underline | underline |
| overline | overline |
| line-through | line-through |
| none | no-underline |

### 텍스트 오버플로우
| CSS | Tailwind |
|-----|----------|
| text-overflow: ellipsis + overflow: hidden + white-space: nowrap | truncate |
| overflow: hidden + -webkit-line-clamp: N | line-clamp-N |

### 오버플로우
| CSS | Tailwind |
|-----|----------|
| hidden | overflow-hidden |
| auto | overflow-auto |
| scroll | overflow-scroll |
| visible | overflow-visible |

### 보더 너비
| CSS | Tailwind |
|-----|----------|
| 0px | border-0 |
| 1px | border |
| 2px | border-2 |
| 4px | border-4 |
| 8px | border-8 |

### z-index
| CSS | Tailwind |
|-----|----------|
| 0 | z-0 |
| 10 | z-10 |
| 20 | z-20 |
| 30 | z-30 |
| 40 | z-40 |
| 50 | z-50 |

### 커스텀 스크롤바
| 스타일 | Tailwind / CSS |
|--------|----------------|
| 스크롤바 숨김 | `scrollbar-hide` 또는 `::-webkit-scrollbar { display: none }` |
| 얇은 스크롤바 | `scrollbar-thin` 또는 `scrollbar-width: thin` |
| 스크롤바 색상 | `scrollbar-thumb-gray-300 scrollbar-track-transparent` |

### 트랜지션
| CSS | Tailwind |
|-----|----------|
| 150ms | duration-150 |
| 200ms | duration-200 |
| 300ms | duration-300 |
| 500ms | duration-500 |
| ease | ease-in-out |
| ease-in | ease-in |
| ease-out | ease-out |
| linear | ease-linear |

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

### 비율 (aspectRatio)
| CSS | Tailwind |
|-----|----------|
| auto | aspect-auto |
| 1 / 1 | aspect-square |
| 16 / 9 | aspect-video |
| 4 / 3 | aspect-[4/3] |

### 이미지 맞춤 (objectFit)
| CSS | Tailwind |
|-----|----------|
| contain | object-contain |
| cover | object-cover |
| fill | object-fill |
| none | object-none |
| scale-down | object-scale-down |

### 이미지 위치 (objectPosition)
| CSS | Tailwind |
|-----|----------|
| 50% 50% (center) | object-center |
| 50% 0% (top) | object-top |
| 50% 100% (bottom) | object-bottom |
| 0% 50% (left) | object-left |
| 100% 50% (right) | object-right |

### 최대 너비 (maxWidth)
| CSS | Tailwind |
|-----|----------|
| 320px | max-w-xs |
| 384px | max-w-sm |
| 448px | max-w-md |
| 512px | max-w-lg |
| 576px | max-w-xl |
| 672px | max-w-2xl |
| 768px | max-w-3xl |
| 896px | max-w-4xl |
| 1024px | max-w-5xl |
| 1152px | max-w-6xl |
| 1280px | max-w-7xl |
| 100% | max-w-full |
| none | max-w-none |

### 최소 높이 (minHeight)
| CSS | Tailwind |
|-----|----------|
| 0px | min-h-0 |
| 100% | min-h-full |
| 100vh | min-h-screen |
| 100dvh | min-h-dvh |

### 블렌드 모드 (mixBlendMode)
| CSS | Tailwind |
|-----|----------|
| multiply | mix-blend-multiply |
| screen | mix-blend-screen |
| overlay | mix-blend-overlay |
| darken | mix-blend-darken |
| lighten | mix-blend-lighten |
| color-dodge | mix-blend-color-dodge |
| difference | mix-blend-difference |

### 필터 (filter)
| CSS | Tailwind |
|-----|----------|
| blur(0px) | blur-none |
| blur(4px) | blur-sm |
| blur(8px) | blur |
| blur(12px) | blur-md |
| blur(16px) | blur-lg |
| blur(24px) | blur-xl |
| grayscale(1) | grayscale |
| invert(1) | invert |
| sepia(1) | sepia |
| brightness(0.5) | brightness-50 |
| brightness(0.75) | brightness-75 |
| brightness(1.5) | brightness-150 |
| contrast(0.5) | contrast-50 |
| contrast(1.5) | contrast-150 |
| saturate(0.5) | saturate-50 |
| saturate(1.5) | saturate-150 |

### 배경 필터 (backdropFilter)
| CSS | Tailwind |
|-----|----------|
| blur(4px) | backdrop-blur-sm |
| blur(8px) | backdrop-blur |
| blur(12px) | backdrop-blur-md |
| blur(16px) | backdrop-blur-lg |
| blur(24px) | backdrop-blur-xl |
| blur(40px) | backdrop-blur-2xl |
| blur(64px) | backdrop-blur-3xl |

### 트랜스폼 원점 (transformOrigin)
| CSS | Tailwind |
|-----|----------|
| center | origin-center |
| top | origin-top |
| top right | origin-top-right |
| right | origin-right |
| bottom right | origin-bottom-right |
| bottom | origin-bottom |
| bottom left | origin-bottom-left |
| left | origin-left |
| top left | origin-top-left |

### 가시성 (visibility)
| CSS | Tailwind |
|-----|----------|
| visible | visible |
| hidden | invisible |
| collapse | collapse |

### 포인터 이벤트 (pointerEvents)
| CSS | Tailwind |
|-----|----------|
| none | pointer-events-none |
| auto | pointer-events-auto |

### 텍스트 선택 (userSelect)
| CSS | Tailwind |
|-----|----------|
| none | select-none |
| text | select-text |
| all | select-all |
| auto | select-auto |

### 리사이즈 (resize)
| CSS | Tailwind |
|-----|----------|
| both | resize |
| horizontal | resize-x |
| vertical | resize-y |
| none | resize-none |

### 스크롤 동작 (scrollBehavior)
| CSS | Tailwind |
|-----|----------|
| smooth | scroll-smooth |
| auto | scroll-auto |

### 스크롤 스냅
| CSS | Tailwind |
|-----|----------|
| scroll-snap-type: x mandatory | snap-x snap-mandatory |
| scroll-snap-type: y mandatory | snap-y snap-mandatory |
| scroll-snap-type: both mandatory | snap-both snap-mandatory |
| scroll-snap-align: start | snap-start |
| scroll-snap-align: end | snap-end |
| scroll-snap-align: center | snap-center |

### 외형 (appearance)
| CSS | Tailwind |
|-----|----------|
| none | appearance-none |
| auto | appearance-auto |

### 리스트 스타일 (listStyleType)
| CSS | Tailwind |
|-----|----------|
| disc | list-disc |
| decimal | list-decimal |
| none | list-none |

### 컬럼 (columns)
| CSS | Tailwind |
|-----|----------|
| 1 | columns-1 |
| 2 | columns-2 |
| 3 | columns-3 |
| 4 | columns-4 |

### 격리 (isolation)
| CSS | Tailwind |
|-----|----------|
| isolate | isolate |
| auto | isolation-auto |
