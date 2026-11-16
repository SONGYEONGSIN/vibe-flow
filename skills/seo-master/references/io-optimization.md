# I/O 최적화 가이드

Next.js App Router의 캐시 우선 아키텍처를 활용한 성능 극대화 전략

---

## 1. Network I/O 최적화

### 리소스 힌트: preconnect 및 dns-prefetch

외부 도메인 연결을 미리 설정하여 폰트, API, CDN 로딩 지연을 줄입니다.

```tsx
// app/layout.tsx
import { preconnect, prefetchDNS } from 'react-dom'

export default function RootLayout({ children }) {
  preconnect('https://fonts.googleapis.com')
  prefetchDNS('https://api.example.com')

  return (
    <html>
      <body>{children}</body>
    </html>
  )
}
```

### Vercel CDN 및 API 캐싱

Next.js ISR 페이지는 `Cache-Control: s-maxage=<초>, stale-while-revalidate` 헤더를 자동 생성합니다.

**fetch 옵션:**

```typescript
// 캐시됨, 60초마다 재검증
fetch(url, { next: { revalidate: 60 } })

// 영구 캐시
fetch(url, { cache: 'force-cache' })

// 캐시 안 함 (주의: 동적 렌더링으로 전환됨)
fetch(url, { cache: 'no-store' })
```

### DON'T: no-store 남용

```typescript
// ❌ 모든 페이지에서 사용하면 TTFB 증가, 서버 부하 가중
fetch(url, { cache: 'no-store' })
export const dynamic = 'force-dynamic'
```

`no-store`는 **사용자별 개인화 데이터**나 **실시간성 필수** 경우에만 제한적으로 사용

---

## 2. Disk/DB I/O 최적화

### ISR 및 Revalidation 전략

**경로 레벨 ISR:**
```typescript
// app/blog/page.tsx
export const revalidate = 60 // 60초마다 재검증
```

**fetch 레벨 ISR:**
```typescript
const data = await fetch(url, { next: { revalidate: 60 } })
```

### On-Demand Revalidation

CMS 업데이트 시 특정 캐시만 즉시 갱신:

```typescript
// app/api/revalidate/route.ts
import { revalidateTag, revalidatePath } from 'next/cache'

export async function POST(request: Request) {
  const { tag, path } = await request.json()

  if (tag) revalidateTag(tag)
  if (path) revalidatePath(path)

  return Response.json({ revalidated: true })
}
```

```typescript
// 데이터 페칭 시 태그 지정
fetch(url, { next: { tags: ['posts'] } })
```

### 병렬 데이터 페칭

**DO: Promise.all로 병렬 처리**
```typescript
// 동시에 요청하여 총 로딩 시간 단축
const [posts, categories, user] = await Promise.all([
  fetchPosts(),
  fetchCategories(),
  fetchUser()
])
```

**DON'T: 순차적 페칭 (워터폴)**
```typescript
// ❌ 하나씩 기다리므로 느림
const posts = await fetchPosts()
const categories = await fetchCategories()
const user = await fetchUser()
```

### 고급 캐싱: use cache와 cacheLife (Next.js 16.1+)

```typescript
'use cache'

import { cacheLife } from 'next/cache'

async function getProducts() {
  cacheLife('hours') // 1시간 캐시
  return await db.query('SELECT * FROM products')
}
```

**cacheLife 프로필:**

| 프로필 | Stale | Revalidate | Expire | 유스케이스 |
|--------|-------|------------|--------|-----------|
| `seconds` | 30초 | 1초 | 1분 | 실시간 점수 |
| `minutes` | 5분 | 1분 | 1시간 | 뉴스 피드 |
| `hours` | 5분 | 1시간 | 1일 | 상품 재고 |
| `days` | 5분 | 1일 | 1주 | 블로그 포스트 |
| `weeks` | 5분 | 1주 | 30일 | 주간 보고서 |
| `max` | 5분 | 30일 | 1년 | 정적 문서 |

---

## 3. Memory 최적화

### Server Components 활용

서버 컴포넌트는 클라이언트 JS 번들에 포함되지 않아 초기 로드 크기 감소:

```tsx
// app/products/page.tsx (기본 서버 컴포넌트)
export default async function ProductsPage() {
  const products = await fetchProducts() // 서버에서만 실행
  return <ProductList products={products} />
}
```

### Streaming SSR

`loading.tsx`로 정적 셸을 먼저 전송하고 동적 콘텐츠 스트리밍:

```tsx
// app/dashboard/loading.tsx
export default function Loading() {
  return <DashboardSkeleton />
}

// app/dashboard/page.tsx
export default async function Dashboard() {
  const data = await fetchDashboardData() // 로딩 중 스켈레톤 표시
  return <DashboardContent data={data} />
}
```

**Suspense로 세밀한 제어:**
```tsx
import { Suspense } from 'react'

export default function Page() {
  return (
    <main>
      <h1>Dashboard</h1>
      <Suspense fallback={<ChartSkeleton />}>
        <Charts />
      </Suspense>
      <Suspense fallback={<TableSkeleton />}>
        <DataTable />
      </Suspense>
    </main>
  )
}
```

### Dynamic Imports

클라이언트 컴포넌트를 필요 시점에 로드:

```tsx
import dynamic from 'next/dynamic'

const HeavyChart = dynamic(() => import('@/components/HeavyChart'), {
  loading: () => <p>Loading chart...</p>,
  ssr: false
})
```

---

## 체크리스트

### I/O 최적화 점검

- [ ] `next: { revalidate }` 또는 `cache: 'force-cache'` 명시적 사용
- [ ] `no-store`, `force-dynamic` 불필요한 사용 없음
- [ ] `revalidateTag`/`revalidatePath`로 On-Demand 갱신 구현
- [ ] 독립적 데이터는 `Promise.all`로 병렬 페칭
- [ ] `loading.tsx`와 `<Suspense>`로 스트리밍 적용
- [ ] 무거운 클라이언트 컴포넌트는 `dynamic import` 사용
