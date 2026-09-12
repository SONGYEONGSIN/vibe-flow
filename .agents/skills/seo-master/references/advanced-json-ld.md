# 고급 JSON-LD 스키마 가이드

리치 스니펫과 생성형 AI 인용을 위한 구조화 데이터 전략

---

## 1. Next.js에서 JSON-LD 구현

서버 컴포넌트에서 JSON-LD를 생성하고 `<script>` 태그로 삽입:

```tsx
// app/blog/[slug]/page.tsx
export default async function BlogPost({ params }) {
  const post = await getPost(params.slug)

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: post.title,
    datePublished: post.publishedAt,
    author: {
      '@type': 'Person',
      name: post.author
    }
  }

  return (
    <article>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(jsonLd).replace(/</g, '\\u003c')
        }}
      />
      <h1>{post.title}</h1>
      {/* ... */}
    </article>
  )
}
```

**XSS 방지:** `.replace(/</g, '\\u003c')`로 `<` 문자 이스케이프

---

## 2. @graph로 다중 스키마 연결

### DON'T: 여러 개의 분리된 script 태그

```tsx
// ❌ 검색 엔진이 병합하지 못할 수 있음
<script type="application/ld+json">{JSON.stringify(orgSchema)}</script>
<script type="application/ld+json">{JSON.stringify(articleSchema)}</script>
```

### DO: @graph로 하나의 연결된 그래프

```tsx
const jsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'Organization',
      '@id': 'https://example.com/#organization',
      name: '회사명',
      url: 'https://example.com',
      logo: 'https://example.com/logo.png'
    },
    {
      '@type': 'WebSite',
      '@id': 'https://example.com/#website',
      url: 'https://example.com',
      name: '사이트명',
      publisher: { '@id': 'https://example.com/#organization' }
    },
    {
      '@type': 'Article',
      headline: '글 제목',
      publisher: { '@id': 'https://example.com/#organization' },
      isPartOf: { '@id': 'https://example.com/#website' }
    }
  ]
}
```

`@id`로 엔티티를 참조하여 관계를 명확히 표현

---

## 3. 주요 스키마 코드 예시

### Article (블로그/뉴스)

```typescript
const articleSchema = {
  '@context': 'https://schema.org',
  '@type': 'Article',
  headline: '글 제목 (110자 이내)',
  author: {
    '@type': 'Person',
    name: '작성자',
    url: 'https://example.com/authors/author-name'
  },
  datePublished: '2025-01-01T09:00:00+09:00',
  dateModified: '2025-01-02T14:30:00+09:00',
  image: ['https://example.com/images/article-image.jpg'],
  publisher: {
    '@type': 'Organization',
    name: '사이트명',
    logo: {
      '@type': 'ImageObject',
      url: 'https://example.com/logo.png'
    }
  }
}
```

### BreadcrumbList (탐색 경로)

```typescript
const breadcrumbSchema = {
  '@context': 'https://schema.org',
  '@type': 'BreadcrumbList',
  itemListElement: [
    {
      '@type': 'ListItem',
      position: 1,
      name: '홈',
      item: 'https://example.com/'
    },
    {
      '@type': 'ListItem',
      position: 2,
      name: '블로그',
      item: 'https://example.com/blog'
    },
    {
      '@type': 'ListItem',
      position: 3,
      name: '현재 글 제목'
      // 마지막 항목은 item 없어도 됨
    }
  ]
}
```

### FAQPage (자주 묻는 질문)

```typescript
const faqSchema = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: [
    {
      '@type': 'Question',
      name: '질문 1?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '답변 1'
      }
    },
    {
      '@type': 'Question',
      name: '질문 2?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: '답변 2'
      }
    }
  ]
}
```

### LocalBusiness (지역 비즈니스)

```typescript
const localBusinessSchema = {
  '@context': 'https://schema.org',
  '@type': 'LocalBusiness',
  name: '가게 이름',
  image: 'https://example.com/images/store.jpg',
  address: {
    '@type': 'PostalAddress',
    streetAddress: '도로명 주소',
    addressLocality: '시/군',
    addressRegion: '구/동',
    postalCode: '우편번호'
  },
  telephone: '+82-2-1234-5678',
  openingHours: 'Mo-Sa 11:00-22:00',
  priceRange: '₩₩'
}
```

### HowTo (단계별 가이드)

```typescript
const howToSchema = {
  '@context': 'https://schema.org',
  '@type': 'HowTo',
  name: '가이드 제목',
  step: [
    {
      '@type': 'HowToStep',
      text: '1단계 설명'
    },
    {
      '@type': 'HowToStep',
      text: '2단계 설명'
    },
    {
      '@type': 'HowToStep',
      text: '3단계 설명'
    }
  ]
}
```

---

## 4. 재사용 가능한 컴포넌트

```tsx
// components/JsonLd.tsx
interface JsonLdProps {
  data: Record<string, unknown>
}

export function JsonLd({ data }: JsonLdProps) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{
        __html: JSON.stringify(data).replace(/</g, '\\u003c')
      }}
    />
  )
}

// 사용
<JsonLd data={articleSchema} />
```

---

## 5. 유효성 검사 도구

배포 전 반드시 검증:

- [Google Rich Results Test](https://search.google.com/test/rich-results)
- [Schema.org Validator](https://validator.schema.org/)

---

## 체크리스트

- [ ] 콘텐츠 유형에 맞는 스키마 적용 (Article, FAQ 등)
- [ ] `@graph`로 다중 스키마 연결
- [ ] `@id`로 엔티티 간 관계 명시
- [ ] XSS 방지 코드 적용 (`.replace(/</g, '\\u003c')`)
- [ ] Rich Results Test로 유효성 검증
