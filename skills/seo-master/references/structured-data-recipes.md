# Structured Data Recipes

업종별 JSON-LD 레시피와 동적 생성 패턴. Google Rich Results 최적화.

---

## JSON-LD 기본 패턴 (Next.js App Router)

JSON-LD 스크립트를 페이지에 삽입하는 컴포넌트:

```typescript
// components/JsonLd.tsx
type Props = { data: Record<string, unknown> };

export function JsonLd({ data }: Props) {
  return (
    <script
      type="application/ld+json"
      // ⚠️ .replace(/</g, '\u003c') 필수 — JSON.stringify만으로는 </script> 인젝션을 막지 못함
      {...{ dangerouslySetInnerHTML: { __html: JSON.stringify(data).replace(/</g, '\u003c') } }}
    />
  );
}
```

> Note: `.replace(/</g, '\\u003c')` 필수 — `JSON.stringify` 단독으로는 `{"key":"</script><script>xss"}` 패턴을 막지 못합니다.

---

## Recipe 1: SaaS / 소프트웨어 제품

```typescript
const saasSchema = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'AppName',
  applicationCategory: 'BusinessApplication',
  operatingSystem: 'Web',
  offers: {
    '@type': 'AggregateOffer',
    lowPrice: '0',
    highPrice: '99',
    priceCurrency: 'USD',
    offerCount: '3',
    offers: [
      { '@type': 'Offer', name: 'Free', price: '0', priceCurrency: 'USD' },
      { '@type': 'Offer', name: 'Pro', price: '29', priceCurrency: 'USD', priceValidUntil: '2025-12-31' },
      { '@type': 'Offer', name: 'Enterprise', price: '99', priceCurrency: 'USD', priceValidUntil: '2025-12-31' },
    ],
  },
  aggregateRating: {
    '@type': 'AggregateRating',
    ratingValue: '4.8',
    reviewCount: '2300',
    bestRating: '5',
  },
};
```

---

## Recipe 2: 이커머스 제품

```typescript
function productSchema(product: Product) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: product.name,
    image: product.images,
    description: product.description,
    sku: product.sku,
    brand: { '@type': 'Brand', name: product.brand },
    offers: {
      '@type': 'Offer',
      url: `https://example.com/products/${product.slug}`,
      priceCurrency: 'KRW',
      price: product.price,
      priceValidUntil: '2025-12-31',
      availability: product.inStock
        ? 'https://schema.org/InStock'
        : 'https://schema.org/OutOfStock',
      seller: { '@type': 'Organization', name: 'ShopName' },
    },
    aggregateRating: product.reviewCount > 0
      ? {
          '@type': 'AggregateRating',
          ratingValue: product.avgRating,
          reviewCount: product.reviewCount,
        }
      : undefined,
    review: product.reviews?.slice(0, 5).map((r) => ({
      '@type': 'Review',
      author: { '@type': 'Person', name: r.authorName },
      datePublished: r.createdAt,
      reviewBody: r.content,
      reviewRating: { '@type': 'Rating', ratingValue: r.rating, bestRating: '5' },
    })),
  };
}
```

---

## Recipe 3: 블로그 / 아티클

```typescript
function articleSchema(post: BlogPost, author: Author) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: post.title,
    description: post.excerpt,
    image: post.coverImage,
    datePublished: post.publishedAt,
    dateModified: post.updatedAt,
    author: { '@type': 'Person', name: author.name, url: author.profileUrl },
    publisher: {
      '@type': 'Organization',
      name: 'SiteName',
      logo: { '@type': 'ImageObject', url: 'https://example.com/logo.png' },
    },
    mainEntityOfPage: {
      '@type': 'WebPage',
      '@id': `https://example.com/blog/${post.slug}`,
    },
    wordCount: post.wordCount,
    articleSection: post.category,
    keywords: post.tags.join(', '),
  };
}
```

---

## Recipe 4: 레스토랑 / 로컬 비즈니스

```typescript
const restaurantSchema = {
  '@context': 'https://schema.org',
  '@type': 'Restaurant',
  name: '식당명',
  image: ['https://example.com/photo1.jpg'],
  address: {
    '@type': 'PostalAddress',
    streetAddress: '서울시 강남구 테헤란로 123',
    addressLocality: '서울',
    addressRegion: '서울특별시',
    postalCode: '06130',
    addressCountry: 'KR',
  },
  geo: { '@type': 'GeoCoordinates', latitude: 37.5012, longitude: 127.0396 },
  telephone: '+82-2-1234-5678',
  servesCuisine: '한식',
  priceRange: 'WW',
  openingHoursSpecification: [
    {
      '@type': 'OpeningHoursSpecification',
      dayOfWeek: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      opens: '11:00', closes: '22:00',
    },
    {
      '@type': 'OpeningHoursSpecification',
      dayOfWeek: ['Saturday', 'Sunday'],
      opens: '11:00', closes: '21:00',
    },
  ],
  acceptsReservations: 'True',
  aggregateRating: { '@type': 'AggregateRating', ratingValue: '4.6', reviewCount: '580' },
};
```

---

## Recipe 5: 이벤트

```typescript
function eventSchema(event: EventData) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Event',
    name: event.title,
    description: event.description,
    startDate: event.startDate,  // ISO 8601: '2025-03-15T09:00:00+09:00'
    endDate: event.endDate,
    eventStatus: 'https://schema.org/EventScheduled',
    eventAttendanceMode: event.isOnline
      ? 'https://schema.org/OnlineEventAttendanceMode'
      : 'https://schema.org/OfflineEventAttendanceMode',
    location: event.isOnline
      ? { '@type': 'VirtualLocation', url: event.streamUrl }
      : {
          '@type': 'Place', name: event.venueName,
          address: { '@type': 'PostalAddress', streetAddress: event.address, addressCountry: 'KR' },
        },
    organizer: { '@type': 'Organization', name: event.organizerName, url: event.organizerUrl },
    offers: {
      '@type': 'Offer',
      price: event.price, priceCurrency: 'KRW',
      availability: event.soldOut ? 'https://schema.org/SoldOut' : 'https://schema.org/InStock',
      url: event.ticketUrl,
    },
    image: event.coverImage,
  };
}
```

---

## Recipe 6: FAQ 페이지

```typescript
function faqSchema(faqs: { question: string; answer: string }[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: faqs.map((faq) => ({
      '@type': 'Question',
      name: faq.question,
      acceptedAnswer: { '@type': 'Answer', text: faq.answer },
    })),
  };
}
```

---

## Recipe 7: HowTo (단계별 가이드)

```typescript
function howToSchema(howTo: HowToData) {
  return {
    '@context': 'https://schema.org',
    '@type': 'HowTo',
    name: howTo.title,
    description: howTo.description,
    totalTime: howTo.duration,  // 'PT15M' (ISO 8601)
    step: howTo.steps.map((step, i) => ({
      '@type': 'HowToStep',
      position: i + 1,
      name: step.title,
      text: step.description,
      image: step.image,
      url: `${howTo.url}#step-${i + 1}`,
    })),
  };
}
```

---

## Recipe 8: 리뷰 / 평점

```typescript
function reviewSchema(review: ReviewData) {
  return {
    '@context': 'https://schema.org',
    '@type': 'Review',
    itemReviewed: { '@type': review.itemType, name: review.itemName },
    author: { '@type': 'Person', name: review.authorName },
    datePublished: review.publishedAt,
    reviewBody: review.content,
    reviewRating: { '@type': 'Rating', ratingValue: review.rating, bestRating: '5', worstRating: '1' },
  };
}
```

---

## Recipe 9: BreadcrumbList

```typescript
function breadcrumbSchema(items: { name: string; url: string }[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, i) => ({
      '@type': 'ListItem', position: i + 1, name: item.name, item: item.url,
    })),
  };
}
```

---

## Recipe 10: 조직 (Organization)

```typescript
const organizationSchema = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: '회사명',
  url: 'https://example.com',
  logo: 'https://example.com/logo.png',
  foundingDate: '2019',
  contactPoint: {
    '@type': 'ContactPoint',
    telephone: '+82-2-1234-5678',
    contactType: 'customer service',
    availableLanguage: ['Korean', 'English'],
  },
  sameAs: [
    'https://twitter.com/company',
    'https://github.com/company',
  ],
};
```

---

## @graph 패턴: 다중 스키마 연결

한 페이지에 여러 스키마를 연결:

```typescript
function pageSchema(page: PageData) {
  return {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Organization',
        '@id': 'https://example.com/#org',
        name: '회사명',
        url: 'https://example.com',
      },
      {
        '@type': 'WebSite',
        '@id': 'https://example.com/#website',
        url: 'https://example.com',
        name: '사이트명',
        publisher: { '@id': 'https://example.com/#org' },
      },
      {
        '@type': 'WebPage',
        '@id': `${page.url}/#webpage`,
        url: page.url,
        name: page.title,
        isPartOf: { '@id': 'https://example.com/#website' },
        datePublished: page.createdAt,
        dateModified: page.updatedAt,
      },
      {
        '@type': 'BreadcrumbList',
        '@id': `${page.url}/#breadcrumb`,
        itemListElement: page.breadcrumbs.map((b, i) => ({
          '@type': 'ListItem', position: i + 1, name: b.name, item: b.url,
        })),
      },
    ],
  };
}
```

### @id 참조 구조

```
Organization (@id: /#org)
    ^ publisher
WebSite (@id: /#website)
    ^ isPartOf
WebPage (@id: /page/#webpage)
    ^ mainEntityOfPage
Article (@id: /blog/post/#article)
```

---

## 동적 JSON-LD 생성 (Supabase 연동)

```typescript
// app/products/[slug]/page.tsx
import { createClient } from '@/lib/supabase/server';
import { JsonLd } from '@/components/JsonLd';

export default async function ProductPage({ params }: Props) {
  const { slug } = await params;
  const supabase = await createClient();

  const { data: product } = await supabase
    .from('products')
    .select('*, reviews(rating, content, author_name, created_at)')
    .eq('slug', slug)
    .single();

  if (!product) notFound();

  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: product.name,
    description: product.description,
    image: product.image_url,
    offers: {
      '@type': 'Offer',
      price: product.price,
      priceCurrency: 'KRW',
      availability: product.stock > 0
        ? 'https://schema.org/InStock'
        : 'https://schema.org/OutOfStock',
    },
    aggregateRating: product.reviews.length > 0
      ? {
          '@type': 'AggregateRating',
          ratingValue: (
            product.reviews.reduce((sum, r) => sum + r.rating, 0) /
            product.reviews.length
          ).toFixed(1),
          reviewCount: product.reviews.length,
        }
      : undefined,
  };

  return (
    <>
      <JsonLd data={schema} />
      {/* 페이지 컨텐츠 */}
    </>
  );
}
```

---

## Google Rich Results 검증

### 검증 도구

1. **Rich Results Test**: https://search.google.com/test/rich-results
2. **Schema Markup Validator**: https://validator.schema.org/
3. **Google Search Console**: 개선사항 > 리치 리절트

### 개발 중 검증

```bash
# 페이지에서 JSON-LD 추출
curl -s http://localhost:3000/products/sample | \
  grep -oP '<script type="application/ld\+json">.*?</script>' | \
  sed 's/<[^>]*>//g' | python3 -m json.tool

# 모든 페이지의 JSON-LD 존재 확인
for url in / /about /blog /products; do
  count=$(curl -s "http://localhost:3000${url}" | grep -c "application/ld+json")
  echo "${url}: ${count}개 JSON-LD"
done
```

### 검증 체크리스트

- [ ] 모든 필수 속성 포함 (Google 문서 기준)
- [ ] URL이 실제 접근 가능한 경로
- [ ] 이미지 URL이 유효하고 접근 가능
- [ ] 날짜 형식 ISO 8601 (YYYY-MM-DD)
- [ ] 가격 정보가 실제 가격과 일치
- [ ] 평점 범위가 올바름 (1-5)
- [ ] @graph 사용 시 @id 참조가 모두 유효

---

## Anti-patterns

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| 모든 페이지에 동일한 JSON-LD | 중복 콘텐츠 시그널 | 페이지별 고유 데이터 |
| 허위 평점/리뷰 | 수동 페널티 | 실제 데이터만 사용 |
| 보이지 않는 콘텐츠에 스키마 | 스팸 판정 | 렌더링된 콘텐츠와 일치 |
| 과도한 스키마 중첩 | 파싱 실패 | 3단계 이내 중첩 |
| 하드코딩된 날짜 | 구식 정보 | DB/CMS에서 동적 생성 |
