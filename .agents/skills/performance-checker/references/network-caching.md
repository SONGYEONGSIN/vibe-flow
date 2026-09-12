# 네트워크 & 캐싱 전략 가이드

HTTP 캐싱, CDN, Next.js App Router의 fetch 캐싱 옵션을 체계적으로 다루는 가이드

---

## 캐싱 계층 구조

```
브라우저 캐시
    ↓ (miss)
CDN 캐시 (Vercel Edge, Cloudflare)
    ↓ (miss)
Next.js Data Cache (서버)
    ↓ (miss)
오리진 서버 / 외부 API
```

---

## 1. HTTP Cache-Control 헤더

### 기본 지시어

| 지시어 | 의미 |
|--------|------|
| `max-age=N` | N초간 캐시 유효 |
| `s-maxage=N` | CDN에서 N초간 유효 (max-age 오버라이드) |
| `stale-while-revalidate=N` | 만료 후 N초간 기존 캐시 반환하며 백그라운드 갱신 |
| `no-store` | 캐시 저장 금지 (민감 데이터) |
| `no-cache` | 매 요청 시 서버 검증 (ETag 활용) |
| `immutable` | 절대 변경되지 않음 (next/static 파일 등) |
| `public` | CDN 캐시 허용 |
| `private` | 브라우저만 캐시 (CDN 금지) |

### 상황별 권장 설정

```
# 정적 자산 (.next/static/ — Next.js 자동 설정)
Cache-Control: public, max-age=31536000, immutable

# HTML 페이지 (ISR)
Cache-Control: public, s-maxage=60, stale-while-revalidate=300

# API 응답 (공개 데이터)
Cache-Control: public, s-maxage=300, stale-while-revalidate=600

# API 응답 (사용자별 데이터)
Cache-Control: private, max-age=0, no-cache

# API 응답 (민감 데이터)
Cache-Control: no-store
```

---

## 2. Next.js App Router 캐싱

### fetch 캐시 옵션

```typescript
// 기본값: 자동 캐시 (Next.js 15에서 변경됨 — 15부터는 기본 no-cache)
const data = await fetch('/api/data');

// 캐시 비활성화 (실시간 데이터)
const data = await fetch('/api/data', {
  cache: 'no-store',
});

// 시간 기반 재검증 (ISR)
const data = await fetch('/api/data', {
  next: { revalidate: 3600 },  // 1시간마다 갱신
});

// 태그 기반 재검증 (On-demand ISR)
const data = await fetch('/api/products', {
  next: { tags: ['products'] },
});

// 태그 무효화 (Server Action 또는 Route Handler에서)
import { revalidateTag } from 'next/cache';
revalidateTag('products');
```

> Next.js 15부터 fetch 기본값이 `no-store`로 변경되었다. 캐싱이 필요하면 명시적으로 설정해야 한다.

### Route Segment Config

```typescript
// app/products/page.tsx
export const revalidate = 3600;    // 1시간 ISR
export const dynamic = 'force-static';  // 완전 정적
export const dynamic = 'force-dynamic'; // 항상 동적
```

### Route Handler 캐시 헤더

```typescript
// app/api/public-data/route.ts
export async function GET() {
  const data = await fetchPublicData();

  return Response.json(data, {
    headers: {
      'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
    },
  });
}

// 실시간 데이터 (캐시 없음)
export async function GET() {
  return Response.json(await fetchLiveData(), {
    headers: {
      'Cache-Control': 'no-store',
    },
  });
}
```

---

## 3. next.config 헤더 설정

```javascript
// next.config.js
module.exports = {
  async headers() {
    return [
      // 정적 파일 — 불변 캐시 (해시 포함된 파일명)
      {
        source: '/_next/static/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
      // 이미지
      {
        source: '/images/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=86400, stale-while-revalidate=604800',
          },
        ],
      },
      // 보안 헤더 (모든 경로)
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ];
  },
};
```

---

## 4. gzip/Brotli 압축 확인

Next.js는 기본적으로 gzip 압축을 제공한다. Vercel 배포 시 Brotli도 자동 적용된다.

```bash
# 응답 압축 여부 확인 (서버 실행 중)
curl -sI -H "Accept-Encoding: gzip, br" http://localhost:3000 | grep -i "content-encoding"
# content-encoding: br  (Brotli)
# content-encoding: gzip

# 특정 파일의 압축 효율 측정
original=$(wc -c < file.js)
gzipped=$(gzip -c file.js | wc -c)
brotli_size=$(brotli -c file.js | wc -c)
echo "원본: ${original}B / gzip: ${gzipped}B / brotli: ${brotli_size}B"
echo "gzip 압축률: $(( (original - gzipped) * 100 / original ))%"
```

```javascript
// next.config.js — 커스텀 서버 시 압축 비활성화 (CDN에서 처리)
module.exports = {
  compress: false,  // CDN이 압축 담당할 때
};
```

---

## 5. ETag & 조건부 요청

```typescript
// Route Handler에서 ETag 활용
import { createHash } from 'crypto';

export async function GET(request: Request) {
  const data = await fetchData();
  const etag = createHash('md5').update(JSON.stringify(data)).digest('hex');

  // 클라이언트가 동일한 ETag를 보내면 304 반환
  if (request.headers.get('if-none-match') === etag) {
    return new Response(null, { status: 304 });
  }

  return Response.json(data, {
    headers: {
      'ETag': etag,
      'Cache-Control': 'public, max-age=0, must-revalidate',
    },
  });
}
```

---

## 6. 점검 체크리스트

```bash
# 1. API 응답 캐시 헤더 확인 (서버 실행 중)
curl -sI http://localhost:3000/api/data | grep -i "cache-control"

# 2. 압축 확인
curl -sI -H "Accept-Encoding: gzip" http://localhost:3000 | grep -i "content-encoding"

# 3. next.config headers() 설정 확인
grep -A20 "async headers" next.config.js next.config.mjs 2>/dev/null

# 4. App Router fetch revalidate 설정 현황
grep -rn "revalidate\|cache:" --include="*.tsx" --include="*.ts" \
  app/ lib/ 2>/dev/null | grep -v node_modules | head -20

# 5. no-store 사용 현황 (캐싱 비활성화된 곳)
grep -rn "no-store\|force-dynamic" --include="*.tsx" --include="*.ts" \
  app/ 2>/dev/null | grep -v node_modules
```

---

## 7. Vercel 배포 시 캐싱 동작

| 항목 | 동작 |
|------|------|
| `_next/static/` | 자동 immutable (1년 캐시) |
| ISR 페이지 | Edge Network에서 s-maxage 기준 캐시 |
| `force-dynamic` 페이지 | 캐시 없음, 매 요청 SSR |
| Image Optimization | CDN 캐시, `minimumCacheTTL` 설정 가능 |

```javascript
// next.config.js — Image TTL 설정
module.exports = {
  images: {
    minimumCacheTTL: 86400,  // 24시간 (기본값: 60초)
  },
};
```
