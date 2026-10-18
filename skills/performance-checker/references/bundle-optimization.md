# 번들 최적화 심화 가이드

번들 크기를 줄여 로딩 성능(LCP)과 상호작용성(INP)을 개선하는 전략

---

## 번들 크기 기준 및 실측 방법

> `du -sh .next/static/chunks/`는 디스크 크기(압축 전)다. 실제 전송 크기는 gzip 기준으로 측정한다.

```bash
# 방법 1: 빌드 출력에서 First Load JS 직접 확인 (가장 신뢰할 수 있는 방법)
npm run build 2>&1 | grep -E "First Load JS| kB| MB"
# Route (app)                              Size     First Load JS
# ─────────────────────────────────────────────────────────────
# ○ /                                     5.2 kB         89 kB  <-- 이 값이 기준

# 방법 2: 청크별 gzip 실측
for f in .next/static/chunks/*.js; do
  [ -f "$f" ] && echo "$(gzip -c "$f" | wc -c) $(basename $f)"
done | sort -rn | head -10 | awk '{printf "%6d KB  %s\n", $1/1024, $2}'

# 방법 3: 총 gzip 크기
total=0
for f in .next/static/chunks/*.js; do
  [ -f "$f" ] && total=$((total + $(gzip -c "$f" | wc -c)))
done
echo "총 gzip: $((total/1024)) KB"
```

| 항목 | 목표 |
|------|------|
| First Load JS (공유 번들 포함) | < 100KB |
| 개별 청크 (gzip) | < 200KB |

---

## 1. 번들 구성 시각화

### @next/bundle-analyzer 설정

```bash
npm install @next/bundle-analyzer
```

```javascript
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});

module.exports = withBundleAnalyzer({
  // 기존 설정...
});
```

```json
// package.json
{
  "scripts": {
    "analyze": "ANALYZE=true npm run build"
  }
}
```

```bash
npm run analyze
# 브라우저에서 번들 시각화 리포트 확인
# client.html: 클라이언트 번들
# server.html: 서버 번들 (App Router RSC 포함)
```

---

## 2. Tree Shaking (트리 쉐이킹)

### DO: Named Import 사용

```typescript
import { format, parseISO } from 'date-fns';
```

### DON'T: 전체 모듈 가져오기

```typescript
import * as dateFns from 'date-fns';  // ❌
import _ from 'lodash';               // ❌ (lodash-es 또는 개별 import 사용)
```

### 트리쉐이킹 친화적 대안

| 기존 | 대안 | 크기 비교 |
|------|------|---------|
| `lodash` | `lodash-es` 또는 개별 import | 71KB → 필요한 것만 |
| `moment` | `day.js` | 67KB → 2KB |
| `axios` | `fetch` API (내장) | 13KB → 0KB |
| `uuid` | `nanoid` | 11KB → 1KB |

---

## 3. Code Splitting (코드 분할)

### next/dynamic (Next.js 권장)

```tsx
import dynamic from 'next/dynamic';

// 클라이언트에서만 로드
const DynamicMap = dynamic(() => import('../components/Map'), {
  loading: () => <div>Loading map...</div>,
  ssr: false
});

// 조건부 로딩 (어드민 전용 등)
const AdminPanel = dynamic(() => import('../components/AdminPanel'), {
  loading: () => <div>Loading...</div>,
});

function Page({ isAdmin }) {
  return (
    <div>
      <h1>Dashboard</h1>
      {isAdmin && <AdminPanel />}
    </div>
  );
}
```

### React.lazy + Suspense (App Router Server Component 경계에서)

```tsx
import { Suspense, lazy } from 'react';

const HeavyChart = lazy(() => import('./HeavyChart'));

export default function Page() {
  return (
    <Suspense fallback={<div>Loading chart...</div>}>
      <HeavyChart />
    </Suspense>
  );
}
```

### 청크 분할 기준

- **페이지별**: Next.js 자동 처리
- **기능별**: 지도, 차트, 에디터, PDF 뷰어 등 무거운 컴포넌트
- **조건별**: 어드민 전용, 프리미엄 기능, 모달 콘텐츠

---

## 4. Server/Client Component 경계 최적화

App Router에서 'use client' 남용은 불필요한 클라이언트 번들 증가의 주요 원인이다.

```tsx
// 나쁜 예: 페이지 전체를 클라이언트 컴포넌트로 만듦
'use client';

export default function ProductPage({ product }) {
  const [count, setCount] = useState(0);
  // product 데이터 렌더링 (서버에서 처리 가능)
  // count 상태 (클라이언트 필요)
  return <div>...</div>;
}

// 좋은 예: 상태가 필요한 부분만 분리
// ProductPage.tsx (Server Component)
import AddToCart from './AddToCart';  // 'use client'

export default function ProductPage({ product }) {
  return (
    <div>
      <h1>{product.name}</h1>           {/* 서버에서 렌더링 */}
      <p>{product.description}</p>     {/* 서버에서 렌더링 */}
      <AddToCart productId={product.id} />  {/* 클라이언트 */}
    </div>
  );
}

// AddToCart.tsx
'use client';
export default function AddToCart({ productId }) {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>Add ({count})</button>;
}
```

### Server Component에서 데이터 전달 시 직렬화 비용

```tsx
// 나쁜 예: 전체 객체를 직렬화하여 전달
<ClientComponent data={hugeObject} />  // ❌ 직렬화 비용 높음

// 좋은 예: 필요한 필드만 전달
<ClientComponent id={obj.id} name={obj.name} />  // 직렬화 최소화
```

---

## 5. 의존성 관리

```bash
# 미사용 의존성 탐지
npx depcheck

# 특정 패키지 번들 크기 확인 (설치 전 검토)
npx bundlephobia-cli <package-name>
# 또는 bundlephobia.com 에서 확인
```

---

## 6. 서드파티 스크립트 최적화

### next/script로 로딩 시점 제어

```tsx
import Script from 'next/script';

// 페이지 인터랙티브 후 로드 (기본값, 권장)
<Script src="https://example.com/analytics.js" strategy="afterInteractive" />

// 모든 리소스 로드 후 (비긴급 스크립트)
<Script src="https://example.com/chat.js" strategy="lazyOnload" />

// 웹 워커에서 실행 — 메인 스레드 보호 (Partytown 필요)
<Script src="https://example.com/heavy.js" strategy="worker" />
```

### 전략 옵션

| strategy | 설명 | 권장 용도 |
|----------|------|----------|
| `beforeInteractive` | 하이드레이션 전 | 거의 사용 안 함 |
| `afterInteractive` | 페이지 인터랙티브 직후 | Google Analytics, 태그매니저 |
| `lazyOnload` | 모든 리소스 로드 후 | 채팅 위젯, 비긴급 추적 |
| `worker` | 웹 워커 실행 | 메인 스레드 INP 보호 |

---

## 7. 빌드 최적화 설정

```javascript
// next.config.js (Next.js 15 App Router 기준)
module.exports = {
  // 특정 패키지의 named import를 자동 최적화 (Tree shaking 보조)
  experimental: {
    optimizePackageImports: [
      '@heroicons/react',
      'lucide-react',
      '@radix-ui/react-icons',
    ],
  },

  // 모듈 별칭으로 가벼운 버전 사용
  webpack: (config) => {
    config.resolve.alias = {
      ...config.resolve.alias,
      'lodash': 'lodash-es',
    };
    return config;
  },
};
```

> `swcMinify`는 Next.js 13부터 기본값이므로 명시하지 않아도 된다.

---

## 8. 배럴 파일(Index) 문제

배럴 파일(`index.ts`)은 트리쉐이킹을 방해하고 번들 크기를 늘릴 수 있다.

```typescript
// 나쁜 예: 배럴 파일을 통한 import
import { Button, Input, Modal } from '@/components';  // ❌

// 좋은 예: 직접 import
import { Button } from '@/components/Button';  // 필요한 것만 번들에 포함
import { Input } from '@/components/Input';
```

> `experimental.optimizePackageImports`를 사용하면 next.config에서 배럴 import를 자동 최적화할 수 있다.
