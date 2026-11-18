# International SEO Guide

Next.js App Router 기반 다국어/다지역 SEO 구현 가이드.

---

## 1. URL 전략 비교

| 전략 | 예시 | 장점 | 단점 |
|------|------|------|------|
| 서브디렉토리 | example.com/ko/ | 도메인 권한 공유, 관리 용이 | 지역 타겟팅 약함 |
| 서브도메인 | ko.example.com | 지역별 서버 분리 가능 | 도메인 권한 분산 |
| ccTLD | example.kr | 지역 신뢰도 최고 | 비용, 개별 관리 필요 |

**권장:** 대부분의 SaaS/웹앱은 **서브디렉토리** 방식 사용. Next.js App Router와 가장 자연스럽게 통합됨.

---

## 2. Next.js App Router 다국어 라우팅

### 디렉토리 구조

```
app/
├── [locale]/
│   ├── layout.tsx
│   ├── page.tsx
│   ├── about/
│   │   └── page.tsx
│   └── blog/
│       └── [slug]/
│           └── page.tsx
├── layout.tsx          # Root layout
└── middleware.ts       # Locale detection & redirect
```

### middleware.ts - 로케일 감지 및 리다이렉트

```typescript
import { NextRequest, NextResponse } from 'next/server';
import { match } from '@formatjs/intl-localematcher';
import Negotiator from 'negotiator';

const locales = ['ko', 'en', 'ja'];
const defaultLocale = 'ko';

function getLocale(request: NextRequest): string {
  const headers = { 'accept-language': request.headers.get('accept-language') || '' };
  const languages = new Negotiator({ headers }).languages();
  return match(languages, locales, defaultLocale);
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // 로케일이 이미 포함된 경로인지 확인
  const pathnameHasLocale = locales.some(
    (locale) => pathname.startsWith(`/${locale}/`) || pathname === `/${locale}`
  );

  if (pathnameHasLocale) return;

  // 로케일 감지 후 리다이렉트
  const locale = getLocale(request);
  request.nextUrl.pathname = `/${locale}${pathname}`;
  return NextResponse.redirect(request.nextUrl);
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)'],
};
```

### [locale]/layout.tsx - 로케일별 메타데이터

```typescript
import { notFound } from 'next/navigation';

const locales = ['ko', 'en', 'ja'];

type Props = {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
};

export async function generateMetadata({ params }: Props) {
  const { locale } = await params;

  const meta = {
    ko: { title: '서비스명 - 설명', description: '한국어 설명' },
    en: { title: 'Service - Description', description: 'English description' },
    ja: { title: 'サービス - 説明', description: '日本語の説明' },
  }[locale];

  return {
    ...meta,
    alternates: {
      canonical: `https://example.com/${locale}`,
      languages: {
        ko: 'https://example.com/ko',
        en: 'https://example.com/en',
        ja: 'https://example.com/ja',
        'x-default': 'https://example.com/ko',
      },
    },
  };
}

export default async function LocaleLayout({ children, params }: Props) {
  const { locale } = await params;
  if (!locales.includes(locale)) notFound();

  return (
    <html lang={locale}>
      <body>{children}</body>
    </html>
  );
}
```

---

## 3. hreflang 태그 구현

### 자동 생성 패턴 (generateMetadata)

```typescript
// Before: hreflang 없음
export const metadata = {
  title: '페이지 제목',
};

// After: alternates.languages로 자동 hreflang 생성
export async function generateMetadata({ params }: Props) {
  const { locale, slug } = await params;

  return {
    title: getTitle(locale, slug),
    alternates: {
      canonical: `https://example.com/${locale}/blog/${slug}`,
      languages: Object.fromEntries([
        ...locales.map(l => [l, `https://example.com/${l}/blog/${slug}`]),
        ['x-default', `https://example.com/${defaultLocale}/blog/${slug}`],
      ]),
    },
  };
}
```

Next.js가 자동으로 생성하는 HTML:

```html
<link rel="alternate" hreflang="ko" href="https://example.com/ko/blog/hello" />
<link rel="alternate" hreflang="en" href="https://example.com/en/blog/hello" />
<link rel="alternate" hreflang="ja" href="https://example.com/ja/blog/hello" />
<link rel="alternate" hreflang="x-default" href="https://example.com/ko/blog/hello" />
```

### hreflang 필수 규칙

1. **양방향 참조**: A → B 링크가 있으면 B → A도 반드시 존재
2. **자기 참조**: 각 페이지는 자기 자신의 hreflang도 포함
3. **x-default 필수**: 매칭되지 않는 로케일의 기본 페이지 지정
4. **URL 완전 일치**: canonical과 hreflang URL이 정확히 일치해야 함

---

## 4. 다국어 sitemap.xml

### app/sitemap.ts

```typescript
import { MetadataRoute } from 'next';

const locales = ['ko', 'en', 'ja'];
const baseUrl = 'https://example.com';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  // 정적 페이지
  const staticPages = ['', '/about', '/pricing'];

  // DB에서 동적 페이지 가져오기
  const posts = await getAllPosts(); // [{slug: 'hello', updatedAt: '2024-01-01'}]

  const staticEntries = staticPages.flatMap((page) =>
    locales.map((locale) => ({
      url: `${baseUrl}/${locale}${page}`,
      lastModified: new Date(),
      changeFrequency: 'weekly' as const,
      priority: page === '' ? 1.0 : 0.8,
      alternates: {
        languages: Object.fromEntries(
          locales.map((l) => [l, `${baseUrl}/${l}${page}`])
        ),
      },
    }))
  );

  const blogEntries = posts.flatMap((post) =>
    locales.map((locale) => ({
      url: `${baseUrl}/${locale}/blog/${post.slug}`,
      lastModified: new Date(post.updatedAt),
      changeFrequency: 'monthly' as const,
      priority: 0.6,
      alternates: {
        languages: Object.fromEntries(
          locales.map((l) => [l, `${baseUrl}/${l}/blog/${post.slug}`])
        ),
      },
    }))
  );

  return [...staticEntries, ...blogEntries];
}
```

생성되는 XML:

```xml
<url>
  <loc>https://example.com/ko</loc>
  <lastmod>2024-01-01</lastmod>
  <xhtml:link rel="alternate" hreflang="ko" href="https://example.com/ko"/>
  <xhtml:link rel="alternate" hreflang="en" href="https://example.com/en"/>
  <xhtml:link rel="alternate" hreflang="ja" href="https://example.com/ja"/>
</url>
```

---

## 5. 지역별 메타데이터 분리 패턴

### 번역 파일 구조

```
messages/
├── ko.json
├── en.json
└── ja.json
```

### 메타데이터 번역 유틸리티

```typescript
// lib/seo.ts
type LocaleMeta = {
  title: string;
  description: string;
  ogTitle: string;
  ogDescription: string;
};

const seoMessages: Record<string, Record<string, LocaleMeta>> = {
  home: {
    ko: {
      title: '서비스명 | 핵심 가치 설명',
      description: '한국어 메타 설명 120자 이내',
      ogTitle: '서비스명 - OG 타이틀',
      ogDescription: '공유 시 보이는 한국어 설명',
    },
    en: {
      title: 'ServiceName | Core Value',
      description: 'English meta description under 160 chars',
      ogTitle: 'ServiceName - OG Title',
      ogDescription: 'English description for sharing',
    },
  },
};

export function getSeoMeta(page: string, locale: string) {
  return seoMessages[page]?.[locale] ?? seoMessages[page]?.['ko'];
}
```

---

## 6. 일반적인 실수 및 해결법

### 실수 1: hreflang 양방향 누락

```
# Bad: ko 페이지에서만 en을 참조
ko/page → hreflang="en" href="/en/page"
en/page → (hreflang 없음)                  ← 누락!

# Good: 양방향 참조
ko/page → hreflang="en" href="/en/page"
en/page → hreflang="ko" href="/ko/page"    ← 양쪽 모두
```

### 실수 2: x-default 미설정

```typescript
// Bad: x-default 없음
alternates: {
  languages: { ko: '/ko', en: '/en' },
}

// Good: x-default 포함
alternates: {
  languages: { ko: '/ko', en: '/en', 'x-default': '/ko' },
}
```

### 실수 3: canonical과 hreflang URL 불일치

```
# Bad: canonical은 www, hreflang은 www 없음
canonical: https://www.example.com/ko/page
hreflang: https://example.com/ko/page        ← 불일치!

# Good: 동일한 URL 형식
canonical: https://example.com/ko/page
hreflang: https://example.com/ko/page
```

### 실수 4: 로케일 없는 기본 경로 처리 안됨

```typescript
// Bad: /about에 접근하면 404
// Good: middleware에서 /about → /ko/about 리다이렉트
```

### 실수 5: 번역되지 않은 페이지에 hreflang 설정

```typescript
// Bad: 일본어 번역이 없는데 hreflang 설정
languages: { ko: '/ko/page', en: '/en/page', ja: '/ja/page' }

// Good: 번역된 페이지만 포함
const availableLocales = await getAvailableTranslations(slug);
languages: Object.fromEntries(
  availableLocales.map(l => [l, `/${l}/page`])
)
```

---

## 7. 검증 체크리스트

```bash
# hreflang 검증
curl -s https://example.com/ko | grep -o 'hreflang="[^"]*"' | sort

# 모든 로케일 페이지 접근 가능 여부
for locale in ko en ja; do
  curl -s -o /dev/null -w "%{http_code} /${locale}\n" "https://example.com/${locale}"
done

# sitemap에서 hreflang 확인
curl -s https://example.com/sitemap.xml | grep "xhtml:link" | head -10

# robots.txt에서 sitemap 참조
curl -s https://example.com/robots.txt | grep -i sitemap
```

### Google Search Console 확인 사항

1. **hreflang 태그** 페이지에서 오류 없는지 확인
2. **사이트맵** 제출 후 모든 로케일 URL 인덱싱 확인
3. **국제 타겟팅** 설정에서 국가 지정 확인
4. **크롤링 통계**에서 로케일별 크롤링 빈도 확인

---

## 8. next-intl 통합 (추천 라이브러리)

```bash
npm install next-intl
```

### 기본 설정

```typescript
// i18n/request.ts
import { getRequestConfig } from 'next-intl/server';

export default getRequestConfig(async ({ requestLocale }) => {
  const locale = await requestLocale;
  return {
    locale,
    messages: (await import(`../messages/${locale}.json`)).default,
  };
});
```

### generateMetadata와 통합

```typescript
import { getTranslations } from 'next-intl/server';

export async function generateMetadata({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: 'Metadata' });

  return {
    title: t('title'),
    description: t('description'),
  };
}
```
