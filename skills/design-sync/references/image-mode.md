# 이미지 모드 (`--from-image`)

URL 없이 **캡처 이미지**(PNG/JPG/WebP)만으로 디자인을 추출·비교·적용하는 모드.
와이어프레임, Figma 캡처, 스크린샷 등 정적 이미지를 입력으로 받는다.

```
/design-sync --from-image ./reference-design.png
```

---

## 1. URL 모드 vs 이미지 모드 비교

| 항목 | URL 모드 | 이미지 모드 |
|------|---------|------------|
| **입력** | 라이브 URL | 이미지 파일 (PNG/JPG/WebP) |
| **추출 도구** | Playwright (computed styles) | AI Vision + Sharp (픽셀 분석) |
| **추출 정밀도** | 정확 (CSS 값 직접) | 높음~중간 (추정치) |
| **Phase 수** | 7단계 | 5단계 |
| **hover/인터랙션** | 캡처 가능 | 불가 (정적 이미지) |
| **반응형** | 멀티 뷰포트 | 단일 (이미지 크기 기준) |
| **싱크율 목표** | 95%+ | 85~90% |

---

## 2. 워크플로우 (5단계)

```
/design-sync --from-image ./design.png

Step I-1 → AI Vision 토큰 추출    이미지 분석 → 색상/타이포/간격/레이아웃 토큰
Step I-2 → AI Vision 인벤토리     영역 분할 → 컴포넌트 식별·분류
Step I-3 → 비주얼 비교            로컬 스크린샷 vs 원본 이미지 pixelmatch
Step I-4 → 매핑 + 수정 적용       기존 Phase 4 + Step 5와 동일
Step I-5 → 최종 검증 + 정리       Phase 3 재실행 + Phase 5와 동일
```

---

## 3. Phase I-1: AI Vision + Sharp 토큰 추출

URL 모드에서는 Playwright로 computed style을 직접 읽지만, 이미지 모드에서는 **Claude Vision**(멀티모달)으로 구조를 파악하고 **Sharp**(이미지 처리)로 픽셀을 정밀 분석한다.

### I-1.1 AI Vision 구조 분석

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

### I-1.2 Sharp 픽셀 분석

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

### I-1.3 AI Vision + Sharp 결과 통합

Sharp의 정밀 데이터로 AI Vision의 추정치를 **보정**한다:

| 항목 | AI Vision (구조) | Sharp (정밀) | 통합 방법 |
|------|-----------------|-------------|----------|
| 색상 | "파란 계열 primary" | `#3B82F6` → `blue-500` | Sharp 우선 |
| 폰트 크기 | "제목은 큰 글자" | `~24px` → `text-2xl` | Sharp 측정 + Tailwind 스냅 |
| 레이아웃 | "sidebar + content" | sidebar 너비 `256px` | AI 구조 + Sharp 치수 |
| 간격 | "여유있는 간격" | `16px, 24px 반복` | Sharp 측정 + 패턴 |
| 컴포넌트 | "카드 3개 가로 배치" | 3등분 영역 감지 | AI 식별 + Sharp 좌표 |

---

## 4. Phase I-2: AI Vision 컴포넌트 인벤토리

이미지를 **격자 분할**하여 영역별 컴포넌트를 식별한다.

### I-2.1 영역 분할 전략

Phase I-1에서 감지한 regions를 기반으로 이미지를 크롭하여 개별 분석한다:

```
1. sidebar 영역 크롭 → AI Vision으로 메뉴 아이템, 로고, 아이콘 식별
2. header 영역 크롭 → AI Vision으로 검색바, 사용자 메뉴, 알림 아이콘 식별
3. content 영역 크롭 → AI Vision으로 카드, 테이블, 폼, 차트 식별
4. content를 추가 격자 분할 → 개별 컴포넌트 상세 분석
```

### I-2.2 컴포넌트 상세 추출

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

### I-2.3 Sharp 영역 크롭 스크립트

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

### I-2.4 인벤토리 생성

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

## 5. Phase I-3: 비주얼 비교 (이미지 vs 로컬)

원본 이미지와 로컬 개발 서버의 스크린샷을 **pixelmatch**로 비교한다.

### I-3.1 비교 방법

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

### I-3.2 이미지 모드 싱크율 해석

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

## 6. Phase I-4~I-5: 기존 Phase 4~7 합류

이미지 모드의 tokens.json, inventory.json이 생성되면, **기존 URL 모드의 Phase 4 (매핑 + Diff) → 수정 적용 → 최종 검증 (Phase 3 재실행) → Phase 5 (학습 + 정리)**를 그대로 실행한다.

유일한 차이:
- 비교 대상이 "URL 재캡처"가 아닌 "원본 이미지 (리사이즈)"
- threshold가 0.15가 아닌 0.2 (이미지 모드 허용 범위)
- hover/인터랙션 비교는 생략

---

## 7. 이미지 모드 필요 의존성

```bash
npm install -D sharp         # 이미지 분석
npm install -D playwright    # 로컬 스크린샷
npm install -D pixelmatch    # 비교
npm install -D pngjs         # PNG 처리
```
