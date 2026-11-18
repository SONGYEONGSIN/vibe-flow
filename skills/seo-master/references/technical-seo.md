# 기술적 SEO 최적화 가이드

Canonical URL, 리다이렉트, 이미지 SEO, 에러 페이지 최적화

---

## 1. Canonical URL 전략

### 중요성

여러 URL로 접근 가능한 동일 콘텐츠의 대표 URL을 지정하여 SEO 점수 분산 방지

예: `example.com/products`, `example.com/products?sort=new`, `www.example.com/products`

### generateMetadata로 동적 설정

```typescript
// app/products/[id]/page.tsx
import type { Metadata } from 'next'

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params  // Next.js 15+: params는 Promise
  return {
    alternates: {
      canonical: `https://www.example.com/products/${id}`,
    },
  }
}
```

### metadataBase로 자동화

루트 레이아웃에서 설정하면 모든 페이지에 자동 적용:

```typescript
// app/layout.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  metadataBase: new URL('https://www.example.com'),
  alternates: {
    canonical: './', // 현재 경로를 canonical로 사용
  },
}
```

---

## 2. 리다이렉트 처리

### 방법별 선택 가이드

| 시나리오 | 방법 | 상태 코드 |
|---------|------|----------|
| 영구 URL 변경 | `next.config.js` redirects | 308 |
| 인증 기반 조건부 | Middleware | 307 |
| 서버 액션 후 이동 | `redirect()` 함수 | 303 |

### next.config.js (정적, 가장 빠름)

```javascript
// next.config.js
module.exports = {
  async redirects() {
    return [
      {
        source: '/old-page',
        destination: '/new-page',
        permanent: true, // 308 영구 리다이렉트
      },
      {
        source: '/blog/:slug',
        destination: '/posts/:slug',
        permanent: true,
      },
    ]
  },
}
```

### Middleware (동적 조건부)

```typescript
// middleware.ts
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const isLoggedIn = request.cookies.get('token')

  if (!isLoggedIn && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
}

export const config = {
  matcher: '/dashboard/:path*',
}
```

### redirect() 함수 (서버 액션)

```typescript
// app/actions.ts
'use server'

import { redirect } from 'next/navigation'

export async function createPost(formData: FormData) {
  const post = await savePost(formData)
  redirect(`/posts/${post.id}`) // 303 리다이렉트
}
```

---

## 3. URL 구조 최적화

### Trailing Slash 일관성

```javascript
// next.config.js
module.exports = {
  trailingSlash: false, // /about (권장)
  // trailingSlash: true, // /about/
}
```

### URL 모범 사례

**DO:**
- `/products/blue-running-shoes` (의미 있는 키워드)
- `/blog/2025/01/nextjs-seo-guide` (계층 구조)

**DON'T:**
- `/products?id=12345` (의미 없는 파라미터)
- `/p/abc123` (짧지만 의미 없음)

---

## 4. 이미지 SEO

### next/image 필수 설정

```tsx
import Image from 'next/image'

<Image
  src="/hero-banner.jpg"
  alt="Next.js로 구축된 대시보드를 보여주는 노트북 화면"
  width={1200}
  height={630}
  priority // LCP 이미지에만 사용
/>
```

### alt 텍스트 작성법

**DON'T:**
```tsx
alt="이미지"
alt="banner"
alt="" // 장식용이 아닌 경우
```

**DO:**
```tsx
alt="Next.js 로고와 함께 노트북에서 코딩하는 개발자의 뒷모습"
alt="2024년 신제품 블루 러닝화 측면 이미지"
```

### 파일명 규칙

**DON'T:** `IMG_1234.jpg`, `photo.png`

**DO:** `nextjs-seo-guide-thumbnail.jpg`, `blue-running-shoes-side-view.jpg`

### priority 속성

- 페이지당 **1-2개**의 LCP 이미지에만 사용
- 남용 시 대역폭 경쟁으로 성능 저하

```tsx
// 히어로 배너에만 priority
<Image src="/hero.jpg" priority />

// 나머지 이미지는 기본 lazy loading
<Image src="/product-1.jpg" />
```

---

## 5. 에러 페이지 최적화

### 404 페이지 (not-found.tsx)

```tsx
// app/not-found.tsx
import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen">
      <h1 className="text-4xl font-bold">404</h1>
      <p className="mt-4 text-gray-600">페이지를 찾을 수 없습니다</p>

      <nav className="mt-8 space-x-4">
        <Link href="/" className="text-blue-600 hover:underline">
          홈으로
        </Link>
        <Link href="/products" className="text-blue-600 hover:underline">
          상품 목록
        </Link>
        <Link href="/contact" className="text-blue-600 hover:underline">
          문의하기
        </Link>
      </nav>
    </div>
  )
}
```

### 500 페러 페이지 (error.tsx)

```tsx
// app/error.tsx
'use client'

export default function Error({
  error,
  reset,
}: {
  error: Error
  reset: () => void
}) {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen">
      <h1 className="text-4xl font-bold">오류 발생</h1>
      <p className="mt-4 text-gray-600">
        일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.
      </p>

      <button
        onClick={reset}
        className="mt-8 px-4 py-2 bg-blue-600 text-white rounded"
      >
        다시 시도
      </button>
    </div>
  )
}
```

### 에러 페이지 포함 요소

- [ ] 사이트 로고/브랜딩
- [ ] 메인 내비게이션 링크
- [ ] 검색창 (선택)
- [ ] 인기 콘텐츠 링크
- [ ] 연락처/문의 링크

---

## 체크리스트

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
