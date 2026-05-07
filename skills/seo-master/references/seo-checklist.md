# SEO Checklist

Next.js App Router 프로젝트 SEO 상세 체크리스트

---

## 1. 메타데이터

### 정적 메타데이터 (layout.tsx / page.tsx)

```typescript
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: '페이지 제목 | 사이트명',
  description: '페이지 설명 (150-160자 권장)',
  // ⚠️ keywords: Google은 2009년부터 무시. 경쟁사에 전략 노출 위험. 생략 권장
  authors: [{ name: '작성자명' }],
  creator: '사이트명',
  publisher: '사이트명',

  // Open Graph
  openGraph: {
    type: 'website',
    locale: 'ko_KR',
    url: 'https://example.com/page',
    siteName: '사이트명',
    title: '페이지 제목',
    description: '페이지 설명',
    images: [
      {
        url: 'https://example.com/og-image.png',
        width: 1200,
        height: 630,
        alt: '이미지 설명',
      },
    ],
  },

  // Twitter
  twitter: {
    card: 'summary_large_image',
    title: '페이지 제목',
    description: '페이지 설명',
    images: ['https://example.com/og-image.png'],
  },

  // 기타
  robots: {
    index: true,
    follow: true,
  },
  alternates: {
    canonical: 'https://example.com/page',
  },
}
```

### 동적 메타데이터 (generateMetadata)

```typescript
import type { Metadata } from 'next'

type Props = {
  params: Promise<{ slug: string }>
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const data = await fetchData(slug)

  return {
    title: `${data.title} | 사이트명`,
    description: data.description,
    openGraph: {
      title: data.title,
      description: data.description,
      images: [data.image || '/default-og.png'],
    },
  }
}
```

---

## 2. 루트 레이아웃 기본 설정

`app/layout.tsx` 필수 설정:

```typescript
import type { Metadata } from 'next'

const siteConfig = {
  name: '사이트명',
  description: '사이트 설명',
  url: 'https://example.com',
  ogImage: 'https://example.com/og.png',
}

export const metadata: Metadata = {
  metadataBase: new URL(siteConfig.url),
  title: {
    default: siteConfig.name,
    template: `%s | ${siteConfig.name}`,
  },
  description: siteConfig.description,
  openGraph: {
    type: 'website',
    locale: 'ko_KR',
    url: siteConfig.url,
    siteName: siteConfig.name,
    images: [siteConfig.ogImage],
  },
  twitter: {
    card: 'summary_large_image',
  },
  robots: {
    index: true,
    follow: true,
  },
}
```

---

## 3. sitemap.ts

`app/sitemap.ts`:

```typescript
import { MetadataRoute } from 'next'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const baseUrl = 'https://example.com'

  // 정적 페이지
  const staticPages = [
    '',
    '/about',
    '/contact',
    '/products',
  ].map((route) => ({
    url: `${baseUrl}${route}`,
    lastModified: new Date(),
    changeFrequency: 'monthly' as const,
    priority: route === '' ? 1 : 0.8,
  }))

  // 동적 페이지 (DB에서 fetch)
  const posts = await fetchAllPosts()
  const dynamicPages = posts.map((post) => ({
    url: `${baseUrl}/blog/${post.slug}`,
    lastModified: new Date(post.updatedAt),
    changeFrequency: 'weekly' as const,
    priority: 0.6,
  }))

  return [...staticPages, ...dynamicPages]
}
```

---

## 4. robots.ts

`app/robots.ts`:

```typescript
import { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  const baseUrl = 'https://example.com'

  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/admin/', '/api/', '/private/'],
      },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
  }
}
```

---

## 5. 구조화 데이터 (JSON-LD)

### 조직/회사 정보

```typescript
export function OrganizationSchema() {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: '회사명',
    url: 'https://example.com',
    logo: 'https://example.com/logo.png',
    contactPoint: {
      '@type': 'ContactPoint',
      telephone: '+82-10-1234-5678',
      contactType: 'customer service',
    },
    sameAs: [
      'https://instagram.com/example',
      'https://twitter.com/example',
    ],
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
```

### 상품 정보

```typescript
export function ProductSchema({ product }: { product: Product }) {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: product.name,
    description: product.description,
    image: product.image,
    offers: {
      '@type': 'Offer',
      price: product.price,
      priceCurrency: 'KRW',
      availability: 'https://schema.org/InStock',
    },
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
```

---

## 6. OG 이미지 생성

### 정적 OG 이미지
`public/og.png` (1200x630px) 배치

### 동적 OG 이미지 (next/og)

`app/api/og/route.tsx`:

```typescript
import { ImageResponse } from 'next/og'

export const runtime = 'edge'

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const title = searchParams.get('title') || '기본 제목'

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: '#000',
          color: '#fff',
          fontSize: 60,
          fontWeight: 'bold',
        }}
      >
        {title}
      </div>
    ),
    { width: 1200, height: 630 }
  )
}
```

---

## 7. Core Web Vitals

### 이미지 최적화

```typescript
import Image from 'next/image'

<Image
  src="/image.jpg"
  alt="설명"
  width={800}
  height={600}
  priority // LCP 이미지에만
/>
```

### 핵심 지표

| 지표 | 좋음 | 개선 필요 |
|------|------|----------|
| LCP | < 2.5초 | > 4초 |
| INP | < 200ms | > 500ms |
| CLS | < 0.1 | > 0.25 |

---

## 8. 테스트 도구

- **메타 태그 검증**: https://metatags.io
- **Twitter 카드**: https://cards-dev.twitter.com/validator
- **구조화 데이터**: https://search.google.com/test/rich-results
- **성능 측정**: https://pagespeed.web.dev

---

## 9. I/O 및 캐싱 최적화

### 데이터 페칭
- [ ] `next: { revalidate }` 또는 `cache: 'force-cache'` 명시
- [ ] 불필요한 `no-store`, `force-dynamic` 제거
- [ ] `revalidateTag`/`revalidatePath` On-Demand 갱신 구현

### 병렬 처리
- [ ] 독립적 데이터는 `Promise.all`로 병렬 페칭
- [ ] 순차적 워터폴 제거

### 스트리밍
- [ ] `loading.tsx`로 정적 셸 먼저 전송
- [ ] `<Suspense>`로 동적 콘텐츠 스트리밍

### 확인 명령어
```bash
# no-store 사용 확인
grep -rn "no-store\|force-dynamic" --include="*.tsx" --include="*.ts"

# loading.tsx 확인
find app -name "loading.tsx"

# revalidate 설정 확인
grep -rn "revalidate" --include="*.tsx" --include="*.ts" | head -10
```

---

## 10. 고급 구조화 데이터

### JSON-LD 스키마
- [ ] 콘텐츠에 맞는 스키마 적용 (Article, FAQ, Product 등)
- [ ] `@graph`로 다중 스키마 연결
- [ ] `@id`로 엔티티 간 관계 명시
- [ ] XSS 방지 코드 적용 (`.replace(/</g, '\\u003c')`)

### 유효성 검증
- [ ] Google Rich Results Test 통과
- [ ] Schema.org Validator 통과

### 확인 명령어
```bash
# JSON-LD 스키마 유형 확인
grep -rn "@type" --include="*.tsx" | grep -E "Article|BreadcrumbList|FAQ|LocalBusiness|HowTo"

# @graph 사용 확인
grep -rn "@graph" --include="*.tsx"
```

---

## 11. 기술적 SEO

### Canonical URL
- [ ] `metadataBase` 루트 레이아웃에 설정
- [ ] 페이지별 `alternates.canonical` 설정

### 리다이렉트
- [ ] 영구 URL 변경은 `next.config.js`에 308 리다이렉트
- [ ] 조건부 리다이렉트는 Middleware 사용

### URL 구조
- [ ] `trailingSlash` 일관성 유지
- [ ] 의미 있는 키워드 포함 URL

### 이미지 SEO
- [ ] 모든 이미지에 서술적 alt 텍스트
- [ ] 의미 있는 파일명 사용
- [ ] LCP 이미지에만 priority 적용
- [ ] width/height 명시 (CLS 방지)

### 에러 페이지
- [ ] `not-found.tsx` 커스터마이징
- [ ] `error.tsx` 커스터마이징
- [ ] 유용한 내비게이션 링크 포함

### 확인 명령어
```bash
# canonical 설정 확인
grep -rn "canonical" --include="*.tsx" --include="*.ts"

# 에러 페이지 확인
ls app/not-found.tsx app/error.tsx 2>/dev/null

# alt 속성 누락 확인
grep -rn "<Image" --include="*.tsx" | grep -v "alt="
```
