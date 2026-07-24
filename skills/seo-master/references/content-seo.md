# 콘텐츠 SEO 가이드

내부 링크 전략, 콘텐츠 클러스터링, Orphan Page 방지

---

## 1. 내부 링크 전략

### 허브 & 스포크 구조

```
Pillar Page (허브)
  ├── Cluster Page 1 (스포크)
  ├── Cluster Page 2 (스포크)
  ├── Cluster Page 3 (스포크)
  └── Cluster Page 4 (스포크)
```

- **Pillar Page**: 주제 전체를 포괄하는 핵심 페이지 (예: "Next.js SEO 완전 가이드")
- **Cluster Page**: 세부 주제를 다루는 페이지들 (예: "메타태그 최적화", "sitemap 설정")
- 모든 Cluster Page는 Pillar Page를 링크해야 함
- Pillar Page는 모든 Cluster Page를 링크해야 함

### 앵커 텍스트 규칙

**DO:**
```tsx
// 키워드가 포함된 서술적 앵커 텍스트
<Link href="/blog/nextjs-seo-guide">Next.js SEO 최적화 방법</Link>
<Link href="/pricing">스타터 요금제 확인하기</Link>
```

**DON'T:**
```tsx
// 의미 없는 앵커 텍스트
<Link href="/blog/nextjs-seo-guide">여기를 클릭하세요</Link>
<Link href="/pricing">더 보기</Link>
```

### 내부 링크 배치 원칙

| 위치 | 용도 | 예시 |
|------|------|------|
| 본문 첫 단락 | 관련 핵심 페이지 | "Next.js 프로젝트 설정은 [공식 가이드]..." |
| 본문 중간 | 상세 설명 페이지 | "더 자세한 내용은 [메타태그 가이드]..." |
| 관련 글 섹션 | Cluster 간 연결 | aside 또는 section으로 구성 |
| 푸터 | 핵심 페이지 | sitemap 역할 |

---

## 2. 콘텐츠 클러스터링 전략

### Pillar Page 구조

```tsx
// app/blog/nextjs-seo/page.tsx — Pillar Page 예시
export default function NextJsSeoGuide() {
  return (
    <article>
      <h1>Next.js SEO 완전 가이드 (2025)</h1>

      {/* 목차 — 클러스터 페이지로 연결 */}
      <nav aria-label="목차">
        <ol>
          <li><a href="#metadata">메타데이터 최적화</a></li>
          <li><a href="#structured-data">구조화 데이터</a></li>
          <li><a href="#core-web-vitals">Core Web Vitals</a></li>
        </ol>
      </nav>

      {/* 각 섹션에서 Cluster Page 링크 */}
      <section id="metadata">
        <h2>메타데이터 최적화</h2>
        <p>메타데이터는 검색엔진이 페이지를 이해하는 핵심 요소입니다.</p>
        <p>
          자세한 구현 방법은{' '}
          <Link href="/blog/nextjs-metadata-guide">
            Next.js 메타데이터 완전 가이드
          </Link>
          를 참고하세요.
        </p>
      </section>
    </article>
  );
}
```

### Cluster Page 구조

```tsx
// app/blog/nextjs-metadata-guide/page.tsx — Cluster Page 예시
export default function MetadataGuide() {
  return (
    <article>
      <h1>Next.js 메타데이터 설정 방법</h1>

      {/* Pillar Page로 반드시 역링크 */}
      <p>
        이 글은{' '}
        <Link href="/blog/nextjs-seo">Next.js SEO 완전 가이드</Link>
        의 일부입니다.
      </p>

      {/* 본문 */}

      {/* 관련 Cluster Page 링크 */}
      <aside aria-label="관련 가이드">
        <h2>함께 읽으면 좋은 글</h2>
        <ul>
          <li><Link href="/blog/nextjs-sitemap">sitemap.ts 설정 방법</Link></li>
          <li><Link href="/blog/nextjs-structured-data">구조화 데이터 구현</Link></li>
        </ul>
      </aside>
    </article>
  );
}
```

---

## 3. Orphan Page 방지

Orphan Page: 다른 페이지에서 링크되지 않는 고립된 페이지. 크롤링 되지 않아 SEO 효과가 없습니다.

### Next.js에서 내부 링크 현황 분석

```bash
# 내부 링크 현황 파악
grep -rn "href=.*\"/" --include="*.tsx" | grep -v "http\|//\|#" | \
  sed 's/.*href="\(\/[^"]*\)".*/\1/' | sort | uniq -c | sort -rn | head -20

# 특정 경로가 몇 번 링크되는지 확인
grep -rn 'href="/blog/nextjs-seo"' --include="*.tsx" | wc -l

# Link 컴포넌트 사용 현황
grep -rn "from 'next/link'" --include="*.tsx" | wc -l

# href="/로 시작하는 내부 링크 전체 목록
grep -rn 'href="/' --include="*.tsx" | grep -oP '(?<=href=")[^"]+' | sort -u
```

### Orphan Page 탐지 스크립트

```bash
# 1. 모든 페이지 경로 수집 (app/ 디렉토리 기준)
find app -name "page.tsx" -not -path "*/api/*" | \
  sed 's|app/||; s|/page.tsx||; s|^|/|; s|/index$|/|' | sort > /tmp/all_pages.txt

# 2. 내부 링크 대상 수집
grep -rn 'href="/' --include="*.tsx" | \
  grep -oP '(?<=href=")[^"#?]+' | sort -u > /tmp/linked_pages.txt

# 3. 링크 안된 페이지 = Orphan
comm -23 /tmp/all_pages.txt /tmp/linked_pages.txt
```

---

## 4. 내부 링크 구현 패턴 (Next.js)

### 관련 글 섹션 컴포넌트

```tsx
// components/RelatedPosts.tsx
interface Post {
  slug: string;
  title: string;
  description: string;
}

export function RelatedPosts({ posts }: { posts: Post[] }) {
  return (
    <aside aria-label="관련 글">
      <h2>함께 읽으면 좋은 글</h2>
      <ul>
        {posts.map((post) => (
          <li key={post.slug}>
            <Link href={`/blog/${post.slug}`}>
              <strong>{post.title}</strong>
              <span>{post.description}</span>
            </Link>
          </li>
        ))}
      </ul>
    </aside>
  );
}
```

### BreadcrumbList로 계층 구조 명시

```tsx
// components/Breadcrumb.tsx
interface BreadcrumbItem {
  name: string;
  href: string;
}

export function Breadcrumb({ items }: { items: BreadcrumbItem[] }) {
  return (
    <nav aria-label="브레드크럼">
      <ol>
        {items.map((item, i) => (
          <li key={item.href}>
            {i < items.length - 1 ? (
              <Link href={item.href}>{item.name}</Link>
            ) : (
              <span aria-current="page">{item.name}</span>
            )}
          </li>
        ))}
      </ol>
    </nav>
  );
}
```

---

## 5. 체크리스트

### 내부 링크
- [ ] 모든 Cluster Page가 Pillar Page를 링크함
- [ ] Pillar Page가 모든 Cluster Page를 링크함
- [ ] 앵커 텍스트에 키워드 포함 (동일 텍스트 남용 금지)
- [ ] 관련 글 섹션 존재 (3-5개)
- [ ] BreadcrumbList 스키마 + 시각적 브레드크럼 일치

### Orphan Page 방지
- [ ] 신규 페이지 생성 시 최소 2개 이상 기존 페이지에서 링크
- [ ] sitemap.ts에 모든 페이지 등록
- [ ] 404 페이지에서 주요 카테고리로 링크

### 구조
- [ ] Pillar Page 식별 및 관리
- [ ] Cluster Page가 올바른 Pillar에 연결됨
- [ ] 카테고리 페이지가 모든 하위 페이지를 링크함

---

## Anti-patterns

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| "여기", "클릭", "더보기" 앵커 | 키워드 정보 없음 | 서술적 앵커 텍스트 |
| 동일 앵커 텍스트 남용 | 스팸 패턴 인식 | 자연스럽게 다양화 |
| Orphan Page | 크롤링 누락 | 신규 페이지마다 내부 링크 2개+ |
| 링크 과잉 (동일 페이지에 20개+) | 각 링크 가치 희석 | 핵심 링크 5-7개 이내 |
| nofollow 남용 | 내부 링크 가치 차단 | 내부 링크에 nofollow 사용 금지 |
| 하위 메뉴에만 의존 | 네비게이션 링크는 SEO 가치 낮음 | 본문 내 컨텍스트 링크 필수 |
