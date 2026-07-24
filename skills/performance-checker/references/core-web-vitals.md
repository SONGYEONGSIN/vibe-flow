# Core Web Vitals 심층 가이드

사용자 경험의 핵심 지표인 LCP, INP, CLS를 이해하고 최적화하는 방법

---

## 임계값 요약

| 지표 | Good | Needs Improvement | Poor |
|------|------|-------------------|------|
| LCP | ≤ 2.5초 | 2.5초 ~ 4.0초 | > 4.0초 |
| INP | ≤ 200ms | 200ms ~ 500ms | > 500ms |
| CLS | ≤ 0.1 | 0.1 ~ 0.25 | > 0.25 |

> INP은 2024년 3월부터 FID를 대체하는 공식 CWV 지표다.

---

## LCP (Largest Contentful Paint)

뷰포트 내 가장 큰 콘텐츠가 렌더링되는 시간. **2.5초 이하**가 목표.

### 주요 저하 원인
- 느린 서버 응답 시간 (TTFB > 200ms)
- 렌더링 차단 CSS/JS
- 최적화되지 않은 이미지 (크기, 포맷, 압축)
- 클라이언트 사이드 렌더링으로 인한 지연

### DO

```tsx
// next/image의 priority로 LCP 이미지 우선 로드
import Image from 'next/image';

<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  priority          // fetchpriority="high" + preload 자동 설정
  sizes="100vw"
/>

// 또는 raw img 태그에 fetchpriority 직접 지정
<img
  src="/hero.jpg"
  fetchpriority="high"
  width={1200}
  height={600}
  alt="Hero"
/>
```

### DON'T

```tsx
// LCP 이미지에 lazy loading 금지
<img src="/hero.jpg" loading="lazy" />  // ❌ LCP 이미지

// next/image에서 priority 없이 큰 이미지 사용
<Image src="/hero.jpg" width={1200} height={600} alt="" />  // ❌ 기본값은 lazy
```

### TTFB 최적화 (200ms 목표)
- **Edge Computing**: Vercel Edge Functions, Cloudflare Workers
- **다계층 캐싱**: 브라우저 → CDN → 오리진
- **Streaming SSR**: 준비된 부분부터 점진적 전송 (React Suspense 활용)

---

## INP (Interaction to Next Paint)

사용자 상호작용 후 다음 프레임까지의 시간. **200ms 이하**가 목표.
FID 대비 단일 입력이 아닌 전체 세션의 최악 상호작용 측정.

### 주요 저하 원인
- Long Tasks (50ms 이상 메인 스레드 점유)
- 과도한 JavaScript 실행 (클라이언트 번들 과다)
- 입력 지연 (메인 스레드가 다른 작업으로 바쁨)
- React 리렌더링 폭주 (불필요한 cascading re-render)

### 긴 작업 분할

```javascript
// scheduler.postTask API (Chrome 94+)
scheduler.postTask(() => {
  // 사용자 입력에 즉시 반응해야 하는 작업
}, { priority: 'user-blocking' });

scheduler.postTask(() => {
  // 백그라운드 작업 (분석, 캐싱)
}, { priority: 'background' });

// 폴백: setTimeout 0으로 태스크 양보
function yieldToMain() {
  return new Promise(resolve => setTimeout(resolve, 0));
}

async function processHeavyTask(items) {
  for (const item of items) {
    processItem(item);
    await yieldToMain();  // 매 아이템마다 메인 스레드 양보
  }
}
```

### React에서 INP 개선

```tsx
// useTransition으로 비긴급 상태 업데이트 분리
import { useTransition } from 'react';

function SearchInput() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [isPending, startTransition] = useTransition();

  function handleChange(e) {
    setQuery(e.target.value);  // 즉시 반응 (입력 필드)
    startTransition(() => {
      setResults(heavySearch(e.target.value));  // 비긴급 (결과 렌더링)
    });
  }

  return (
    <input value={query} onChange={handleChange} />
  );
}

// React.memo로 불필요한 리렌더링 방지
const ExpensiveItem = React.memo(({ data }) => {
  return <div>{/* 복잡한 렌더링 */}</div>;
});

// useCallback으로 이벤트 핸들러 참조 안정화
const handleClick = useCallback(() => {
  // 핸들러 로직
}, [dep1, dep2]);
```

> 주의: React.memo와 useCallback은 남용 시 오히려 메모이제이션 비용이 발생한다. 실제 성능 문제가 측정된 경우에만 적용한다.

### 우선순위 종류

| 우선순위 | 용도 |
|---------|------|
| `user-blocking` | UI 업데이트, 즉각 반응 필요 |
| `user-visible` | 빠르게 처리되어야 할 렌더링 |
| `background` | 분석, 캐싱 등 백그라운드 작업 |

---

## CLS (Cumulative Layout Shift)

페이지 로딩 중 예상치 못한 레이아웃 이동 점수. **0.1 이하**가 목표.

### 주요 발생 원인
- 크기가 지정되지 않은 이미지/영상
- 웹 폰트 로딩 (FOUT/FOIT)
- 동적 콘텐츠 삽입 (광고, 배너, 쿠키 배너)

### 미디어 요소 공간 예약

```tsx
// next/image는 자동으로 aspect-ratio 설정
import Image from 'next/image';
<Image src="/photo.jpg" width={800} height={600} alt="" />

// raw img 태그는 반드시 width + height 또는 aspect-ratio
<img src="/photo.jpg" width={800} height={600} alt="" />

// CSS로 반응형 처리 시
<style>
  .image-wrap {
    aspect-ratio: 16 / 9;
    width: 100%;
  }
  .image-wrap img {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }
</style>
```

### 폰트 최적화 (next/font 권장)

#### next/font 사용 (권장)

```tsx
// app/layout.tsx 또는 _app.tsx
import { Noto_Sans_KR } from 'next/font/google';

const notoSansKr = Noto_Sans_KR({
  subsets: ['latin'],
  weight: ['400', '700'],
  display: 'swap',
  preload: true,
  // 한국어 서브셋
  // next/font는 자동으로 사용된 글자만 서브셋 처리
});

export default function RootLayout({ children }) {
  return (
    <html lang="ko" className={notoSansKr.className}>
      <body>{children}</body>
    </html>
  );
}
```

```tsx
// 로컬 폰트
import localFont from 'next/font/local';

const pretendard = localFont({
  src: [
    { path: '../public/fonts/Pretendard-Regular.woff2', weight: '400' },
    { path: '../public/fonts/Pretendard-Bold.woff2', weight: '700' },
  ],
  display: 'swap',
  preload: true,
  fallback: ['Apple SD Gothic Neo', 'Malgun Gothic', 'sans-serif'],
});
```

#### 직접 @font-face 사용 시 (차선)

```css
@font-face {
  font-family: 'Pretendard';
  src: url('/fonts/Pretendard-Regular.woff2') format('woff2');
  font-weight: 400;
  font-display: optional; /* 느린 연결에서 시스템 폰트 유지 (CLS 최소화) */
  /* font-display: swap; — FOUT 발생 가능, 폴백 폰트와 크기 차이 최소화 필요 */
}
```

**font-display 전략 비교:**

| 옵션 | 동작 | CLS 영향 | 권장 상황 |
|------|------|----------|----------|
| `optional` | 캐시 있으면 사용, 없으면 시스템 폰트 유지 | 없음 | CLS 최우선 시 |
| `swap` | 시스템 폰트 표시 후 교체 | 있음 | 브랜드 폰트 필수 시 |
| `block` | 폰트 로드까지 텍스트 숨김 | 없음 | 비권장 (FOIT) |

**폴백 폰트 크기 조정 (swap 시 CLS 최소화):**

```css
/* 폴백 폰트를 웹폰트와 시각적으로 맞춤 */
@font-face {
  font-family: 'Pretendard-fallback';
  src: local('Apple SD Gothic Neo'), local('Malgun Gothic');
  ascent-override: 97%;
  descent-override: 22%;
  line-gap-override: 0%;
  size-adjust: 100.6%;
}
```

### 동적 콘텐츠

```css
/* 광고/배너에 최소 높이 지정 */
.ad-slot {
  min-height: 250px;
  contain: layout;
}

/* 쿠키 배너 — 상단 고정 시 콘텐츠 밀림 방지 */
.cookie-banner {
  position: fixed;
  bottom: 0;
  /* top 고정은 CLS 유발 — bottom 권장 */
}
```

---

## 측정 및 모니터링

### 실험실 vs 필드 데이터

| 구분 | 도구 | 용도 |
|------|------|------|
| 실험실 데이터 | Lighthouse, WebPageTest | 개발/디버깅, 통제 환경 |
| 필드 데이터 (RUM) | web-vitals, CrUX | SEO 순위 기준, 실사용자 환경 |

### web-vitals 라이브러리로 RUM 구현

```typescript
import { onCLS, onINP, onLCP } from 'web-vitals';

function sendToAnalytics({ name, value, id, rating }) {
  const body = JSON.stringify({
    metric: name,
    value: Math.round(name === 'CLS' ? value * 1000 : value),
    rating,   // 'good' | 'needs-improvement' | 'poor'
    id,
    url: location.href,
  });

  // sendBeacon: 페이지 언로드 중에도 전송 보장
  if (navigator.sendBeacon) {
    navigator.sendBeacon('/api/analytics', body);
  } else {
    fetch('/api/analytics', { body, method: 'POST', keepalive: true });
  }
}

onCLS(sendToAnalytics);
onINP(sendToAnalytics);
onLCP(sendToAnalytics);
```

### Chrome DevTools로 INP 측정

1. Performance 탭 → Record → 페이지 클릭/스크롤 → Stop
2. "Interactions" 트랙에서 각 상호작용의 처리 시간 확인
3. 50ms 이상 Long Task → 노란색으로 표시됨
4. PerformanceObserver로 직접 측정:

```javascript
// INP 후보 수집
const observer = new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    if (entry.interactionId) {
      console.log(`INP 후보: ${entry.duration}ms`, entry);
    }
  }
});
observer.observe({ type: 'event', buffered: true });
```
