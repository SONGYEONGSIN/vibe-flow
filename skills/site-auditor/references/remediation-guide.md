# Remediation Guide

Site Auditor에서 발견된 문제별 즉시 적용 가능한 해결 코드와 우선순위 가이드.

---

## 우선순위 결정 매트릭스

| 우선순위 | 기준 | 예시 | 예상 효과 |
|----------|------|------|-----------|
| P0 (즉시) | 빌드 실패, 보안 취약점 | TS 에러, env 노출 | 서비스 불가 → 정상화 |
| P1 (당일) | 접근성 Critical, SEO 치명적 | alt 누락 50%+, sitemap 없음 | 등급 2단계 상향 가능 |
| P2 (1주) | 성능 저하, UX 문제 | 번들 5MB+, 키보드 접근 불가 | 등급 1단계 상향 |
| P3 (2주) | 최적화, 모니터링 | 이미지 미최적화, Sentry 미설정 | 점진적 개선 |
| P4 (백로그) | Minor 개선 | 코드 정리, 미사용 의존성 | 유지보수성 향상 |

---

## Phase 1: Performance 해결 가이드

### P0: 빌드 실패 해결

#### TypeScript 에러

```typescript
// Before: 타입 에러
const user = data.user;  // 'user' does not exist on type '{}'

// After: 타입 안전하게 수정
interface ApiResponse {
  user?: {
    id: string;
    name: string;
  };
}

const response = data as ApiResponse;
const user = response.user;
```

**빠른 진단:**
```bash
# 빌드 에러 목록 추출
npm run build 2>&1 | grep "error TS" | sort | uniq -c | sort -rn

# 가장 많은 에러 유형 확인
npm run build 2>&1 | grep -oP 'TS\d+' | sort | uniq -c | sort -rn | head -5
```

#### 빌드 의존성 문제

```bash
# 의존성 충돌 확인
npm ls --depth=0 2>&1 | grep "UNMET"

# 해결
rm -rf node_modules package-lock.json
npm install
```

### P1: 번들 크기 최적화

#### 번들 분석

```bash
# Next.js 번들 분석
ANALYZE=true npm run build

# 수동 크기 확인
du -sh .next/static/chunks/ 2>/dev/null
find .next/static -name "*.js" -exec du -k {} + | sort -rn | head -20
```

#### 대용량 라이브러리 교체

| 라이브러리 | 크기 | 대안 | 대안 크기 | 절감 |
|-----------|:----:|------|:--------:|:----:|
| moment.js | 72KB | dayjs | 2KB | 97% |
| lodash | 72KB | lodash-es (tree-shake) | ~5KB | 93% |
| date-fns (전체) | 75KB | date-fns (개별) | ~3KB | 96% |
| axios | 13KB | fetch (내장) | 0KB | 100% |
| classnames | 1KB | clsx | 0.5KB | 50% |

```typescript
// Before: 전체 lodash import
import _ from 'lodash';
const sorted = _.sortBy(items, 'name');

// After: 개별 함수 import
import sortBy from 'lodash-es/sortBy';
const sorted = sortBy(items, 'name');

// Best: 직접 구현 (간단한 경우)
const sorted = [...items].sort((a, b) => a.name.localeCompare(b.name));
```

#### Dynamic Import 적용

```typescript
// Before: 정적 import (번들에 항상 포함)
import { Chart } from 'chart.js';
import MonacoEditor from '@monaco-editor/react';

// After: 동적 import (필요할 때만 로드)
import dynamic from 'next/dynamic';

const Chart = dynamic(() => import('chart.js').then(m => m.Chart), {
  ssr: false,
  loading: () => <div className="h-64 animate-pulse bg-gray-100 rounded" />,
});

const MonacoEditor = dynamic(() => import('@monaco-editor/react'), {
  ssr: false,
  loading: () => <div className="h-96 animate-pulse bg-gray-100 rounded" />,
});
```

### P2: 이미지 최적화

```typescript
// Before: HTML img 태그
<img src="/hero.png" width={1200} height={600} />

// After: Next.js Image 컴포넌트
import Image from 'next/image';

<Image
  src="/hero.png"
  width={1200}
  height={600}
  alt="히어로 배너 이미지"
  priority  // LCP 이미지에만
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 1200px"
/>
```

**일괄 변환 스크립트:**
```bash
# img 태그 사용 위치 찾기
grep -rn '<img ' src/ --include="*.tsx" --include="*.jsx" | grep -v 'node_modules'
```

### P3: 미사용 의존성 제거

```bash
# depcheck으로 미사용 의존성 찾기
npx depcheck --ignores="@types/*,eslint-*,prettier*,postcss*,tailwindcss,autoprefixer"

# 결과 예시:
# Unused dependencies
# * @heroicons/react
# * framer-motion
# * react-hot-toast

# 제거
npm uninstall @heroicons/react framer-motion react-hot-toast
```

---

## Phase 2: UI/Accessibility 해결 가이드

### P0: 이미지 alt 속성

```typescript
// Before: alt 누락
<Image src="/profile.jpg" width={48} height={48} />

// After: 의미있는 alt 추가
<Image
  src="/profile.jpg"
  width={48}
  height={48}
  alt="사용자 프로필 사진"
/>

// 장식용 이미지: 빈 alt
<Image
  src="/decorative-line.svg"
  width={100}
  height={2}
  alt=""
  aria-hidden="true"
/>
```

**일괄 탐지:**
```bash
# alt 없는 이미지 찾기
grep -rn '<Image\|<img' src/ --include="*.tsx" | grep -v 'alt='
```

### P0: 키보드 접근성

```css
/* Before: outline 제거 (접근성 위반) */
*:focus {
  outline: none;
}

/* After: 커스텀 포커스 스타일 */
*:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
  border-radius: 2px;
}

/* 마우스 클릭 시에는 숨기고, 키보드만 표시 */
*:focus:not(:focus-visible) {
  outline: none;
}
```

```typescript
// Before: div로 만든 버튼
<div onClick={handleClick} className="btn">
  클릭하세요
</div>

// After: 시맨틱 버튼
<button
  onClick={handleClick}
  className="btn"
  type="button"
>
  클릭하세요
</button>

// 커스텀 요소에 키보드 접근성 추가
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      handleClick();
    }
  }}
>
  클릭하세요
</div>
```

### P1: 폼 접근성

```typescript
// Before: label 미연결
<span>이메일</span>
<input type="email" name="email" />

// After: label 연결
<label htmlFor="email-input">이메일</label>
<input
  id="email-input"
  type="email"
  name="email"
  autoComplete="email"
  aria-required="true"
  aria-describedby="email-error"
/>
{error && (
  <p id="email-error" role="alert" className="text-red-600 text-sm">
    {error}
  </p>
)}
```

### P1: ARIA 적절 사용

```typescript
// 모달 다이얼로그
<dialog
  ref={dialogRef}
  aria-labelledby="modal-title"
  aria-describedby="modal-desc"
  aria-modal="true"
>
  <h2 id="modal-title">계정 삭제</h2>
  <p id="modal-desc">이 작업은 되돌릴 수 없습니다.</p>
  <button onClick={onConfirm}>삭제</button>
  <button onClick={onCancel} autoFocus>취소</button>
</dialog>

// 로딩 상태
<div aria-live="polite" aria-busy={isLoading}>
  {isLoading ? (
    <div role="status">
      <span className="sr-only">로딩 중...</span>
      <Spinner />
    </div>
  ) : (
    <DataTable data={data} />
  )}
</div>

// 탭 인터페이스
<div role="tablist" aria-label="설정 카테고리">
  {tabs.map((tab) => (
    <button
      key={tab.id}
      role="tab"
      aria-selected={activeTab === tab.id}
      aria-controls={`panel-${tab.id}`}
      id={`tab-${tab.id}`}
      onClick={() => setActiveTab(tab.id)}
    >
      {tab.label}
    </button>
  ))}
</div>
{tabs.map((tab) => (
  <div
    key={tab.id}
    role="tabpanel"
    id={`panel-${tab.id}`}
    aria-labelledby={`tab-${tab.id}`}
    hidden={activeTab !== tab.id}
  >
    {tab.content}
  </div>
))}
```

### P2: 안티패턴 제거

```html
<!-- Before: user-scalable=no (줌 금지) -->
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no" />

<!-- After: 줌 허용 -->
<meta name="viewport" content="width=device-width, initial-scale=1" />
```

```typescript
// Before: 움직임 설정 무시
const fadeIn = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.5 },
};

// After: prefers-reduced-motion 존중
const fadeIn = {
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.5 },
};

// CSS에서 처리
// @media (prefers-reduced-motion: reduce) {
//   * { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
// }

// 또는 JS에서
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const animationConfig = prefersReducedMotion
  ? { initial: {}, animate: {}, transition: { duration: 0 } }
  : fadeIn;
```

---

## Phase 3: SEO 해결 가이드

### P0: 메타데이터 설정

```typescript
// app/layout.tsx - 글로벌 메타데이터
import type { Metadata } from 'next';

export const metadata: Metadata = {
  metadataBase: new URL('https://example.com'),
  title: {
    default: '서비스명 - 한 줄 설명',
    template: '%s | 서비스명',
  },
  description: '서비스에 대한 150자 이내 설명',
  openGraph: {
    type: 'website',
    locale: 'ko_KR',
    url: 'https://example.com',
    siteName: '서비스명',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: '서비스명 - 소개 이미지',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    creator: '@handle',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
};
```

```typescript
// app/page.tsx - 페이지별 메타데이터
export const metadata: Metadata = {
  title: '기능 소개',
  description: '이 페이지만의 고유한 설명 150자 이내',
  openGraph: {
    title: '기능 소개 | 서비스명',
    description: '이 페이지만의 고유한 설명',
  },
};
```

### P0: Sitemap / Robots

```typescript
// app/sitemap.ts
import type { MetadataRoute } from 'next';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  // 정적 페이지
  const staticPages = [
    { url: 'https://example.com', lastModified: new Date(), priority: 1.0 },
    { url: 'https://example.com/about', lastModified: new Date(), priority: 0.8 },
    { url: 'https://example.com/pricing', lastModified: new Date(), priority: 0.8 },
  ];

  // 동적 페이지 (DB에서)
  const posts = await fetchPosts();
  const dynamicPages = posts.map((post) => ({
    url: `https://example.com/blog/${post.slug}`,
    lastModified: new Date(post.updated_at),
    priority: 0.6,
  }));

  return [...staticPages, ...dynamicPages];
}

// app/robots.ts
import type { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/api/', '/admin/', '/_next/'],
      },
    ],
    sitemap: 'https://example.com/sitemap.xml',
  };
}
```

### P1: 구조화 데이터 (JSON-LD)

```typescript
// app/components/JsonLd.tsx
interface JsonLdProps {
  data: Record<string, unknown>;
}

export function JsonLd({ data }: JsonLdProps) {
  const jsonString = JSON.stringify(data);

  return (
    <script
      type="application/ld+json"
      // JSON-LD를 안전하게 주입
      {...{ dangerouslySetInnerHTML: { __html: jsonString } }}
    />
  );
}

// 사용 예시
// app/page.tsx
export default function HomePage() {
  const orgData = {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: '서비스명',
    url: 'https://example.com',
    logo: 'https://example.com/logo.png',
    sameAs: [
      'https://twitter.com/handle',
      'https://github.com/handle',
    ],
  };

  return (
    <>
      <JsonLd data={orgData} />
      <main>{/* 페이지 내용 */}</main>
    </>
  );
}
```

### P1: 시맨틱 HTML

```typescript
// Before: div 남용
<div className="header">
  <div className="nav">...</div>
</div>
<div className="content">
  <div className="title">페이지 제목</div>
  <div className="text">본문 텍스트...</div>
</div>
<div className="footer">...</div>

// After: 시맨틱 태그
<header>
  <nav aria-label="메인 내비게이션">...</nav>
</header>
<main>
  <article>
    <h1>페이지 제목</h1>
    <p>본문 텍스트...</p>
  </article>
</main>
<footer>...</footer>
```

### P2: 에러 페이지

```typescript
// app/not-found.tsx
export default function NotFound() {
  return (
    <main className="flex min-h-screen items-center justify-center">
      <div className="text-center">
        <h1 className="text-6xl font-bold">404</h1>
        <p className="mt-4 text-lg text-gray-600">페이지를 찾을 수 없습니다</p>
        <a
          href="/"
          className="mt-6 inline-block rounded bg-black px-6 py-3 text-white"
        >
          홈으로 돌아가기
        </a>
      </div>
    </main>
  );
}

// app/error.tsx
'use client';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <main className="flex min-h-screen items-center justify-center">
      <div className="text-center">
        <h1 className="text-6xl font-bold">오류</h1>
        <p className="mt-4 text-lg text-gray-600">문제가 발생했습니다</p>
        <button
          onClick={reset}
          className="mt-6 rounded bg-black px-6 py-3 text-white"
        >
          다시 시도
        </button>
      </div>
    </main>
  );
}
```

---

## Phase 4: Backend Safety 해결 가이드

### P0: 환경변수 검증

```typescript
// env.ts (t3-env 패턴)
import { createEnv } from '@t3-oss/env-nextjs';
import { z } from 'zod';

export const env = createEnv({
  server: {
    DATABASE_URL: z.string().url(),
    SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
    STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
    SENTRY_DSN: z.string().url().optional(),
  },
  client: {
    NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
    NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
  },
  runtimeEnv: {
    DATABASE_URL: process.env.DATABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
    STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY,
    SENTRY_DSN: process.env.SENTRY_DSN,
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  },
});
```

### P1: Sentry 설정

```typescript
// sentry.client.config.ts
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
  environment: process.env.NODE_ENV,
  integrations: [
    Sentry.replayIntegration(),
    Sentry.browserTracingIntegration(),
  ],
});
```

```bash
# Sentry 설치
npx @sentry/wizard@latest -i nextjs
```

### P2: API 타임아웃 / 재시도

```typescript
// lib/fetch-with-retry.ts
interface FetchOptions extends RequestInit {
  timeout?: number;
  retries?: number;
  retryDelay?: number;
}

export async function fetchWithRetry(
  url: string,
  options: FetchOptions = {},
): Promise<Response> {
  const { timeout = 5000, retries = 3, retryDelay = 1000, ...fetchOptions } = options;

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), timeout);

      const response = await fetch(url, {
        ...fetchOptions,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok && attempt < retries && response.status >= 500) {
        await new Promise((r) => setTimeout(r, retryDelay * (attempt + 1)));
        continue;
      }

      return response;
    } catch (error) {
      if (attempt === retries) throw error;
      await new Promise((r) => setTimeout(r, retryDelay * (attempt + 1)));
    }
  }

  throw new Error('Max retries exceeded');
}
```

### P3: Rate Limiting

```typescript
// middleware.ts (간단한 IP 기반)
import { NextResponse, type NextRequest } from 'next/server';

const rateLimitMap = new Map<string, { count: number; timestamp: number }>();
const WINDOW_MS = 60_000; // 1분
const MAX_REQUESTS = 60;

export function middleware(request: NextRequest) {
  if (!request.nextUrl.pathname.startsWith('/api/')) {
    return NextResponse.next();
  }

  const ip = request.headers.get('x-forwarded-for') ?? 'unknown';
  const now = Date.now();
  const record = rateLimitMap.get(ip);

  if (!record || now - record.timestamp > WINDOW_MS) {
    rateLimitMap.set(ip, { count: 1, timestamp: now });
    return NextResponse.next();
  }

  record.count++;

  if (record.count > MAX_REQUESTS) {
    return NextResponse.json(
      { error: 'Too many requests' },
      { status: 429, headers: { 'Retry-After': '60' } },
    );
  }

  return NextResponse.next();
}
```

---

## 해결 우선순위 체크리스트

### 즉시 조치 (1시간 이내)

- [ ] 빌드 에러 수정 (TS 에러 해결)
- [ ] 환경변수 검증 로직 추가
- [ ] 보안 취약점 패치 (env 노출 등)

### 당일 조치

- [ ] alt 속성 추가 (전체 이미지)
- [ ] outline:none 제거, focus-visible 적용
- [ ] sitemap.ts, robots.ts 생성
- [ ] 메타데이터 설정 (title, description, OG)

### 1주 이내

- [ ] 번들 크기 최적화 (dynamic import, 라이브러리 교체)
- [ ] 이미지 최적화 (next/image 전환)
- [ ] 폼 접근성 (label, autocomplete)
- [ ] Sentry 설정

### 2주 이내

- [ ] 구조화 데이터 추가 (JSON-LD)
- [ ] 시맨틱 HTML 리팩토링
- [ ] Rate limiting 구현
- [ ] 미사용 의존성 제거

---

## 트러블슈팅: 자주 발생하는 실패

| 문제 | 원인 | 해결 |
|------|------|------|
| 빌드 성공했는데 점수 낮음 | 번들 크기, 이미지 미최적화 | P1/P2 항목 우선 |
| alt 추가했는데 감점 | 의미 없는 alt ("image", "photo") | 콘텐츠 설명하는 alt |
| sitemap 있는데 인식 안됨 | robots.txt에 sitemap 미등록 | robots.ts에 sitemap URL 추가 |
| OG 이미지 미리보기 안됨 | 상대 경로, metadataBase 미설정 | 절대 URL + metadataBase |
| Sentry 설정했는데 감지 안됨 | DSN 미설정, 환경변수 누락 | .env에 SENTRY_DSN 확인 |
| 환경변수 검증 통과했는데 런타임 에러 | 빌드 타임 vs 런타임 차이 | t3-env runtimeEnv 확인 |
| 번들 줄였는데 여전히 큼 | 트리쉐이킹 안되는 라이브러리 | 대안 라이브러리 교체 |
| 접근성 점수 안오름 | ARIA 오용 (role 남발) | 네이티브 HTML 우선 |

---

## 점수 개선 시뮬레이션

```
현재: 52점 (C등급)
  Performance: 12/25 (빌드 성공, TS 에러 3개, 번들 3MB)
  UI/A11y: 10/25 (alt 30%, outline:none, label 미연결)
  SEO: 15/25 (메타데이터 일부, sitemap 없음)
  Backend: 15/25 (env 검증 없음, Sentry 없음)

P0+P1 조치 후: 74점 (B등급) → +22점
  Performance: 18/25 (TS 에러 수정, 번들 1MB)
  UI/A11y: 18/25 (alt 100%, focus-visible, label 연결)
  SEO: 21/25 (메타데이터 완전, sitemap 추가)
  Backend: 17/25 (env 검증 추가)

P2+P3 조치 후: 89점 (B등급 상위) → +15점
  Performance: 23/25 (이미지 최적화, 의존성 정리)
  UI/A11y: 23/25 (ARIA 적절, 안티패턴 제거)
  SEO: 23/25 (JSON-LD, 시맨틱 HTML)
  Backend: 20/25 (Sentry, 타임아웃, Rate Limit)

전체 조치 후: 94점 (A등급) → +5점
  미세 조정으로 A등급 안정 진입
```
