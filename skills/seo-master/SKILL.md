---
name: seo-master
description: This skill should be used for Next.js App Router SEO optimization. Use when creating new pages, before deployment, or when the user requests "SEO 점검", "메타태그 확인", "검색엔진 최적화", "시멘틱 HTML 점검", "접근성 점검", "GEO 점검", "AI 검색 최적화", "llms.txt", "AI 인용 최적화", "생성형 검색".
---

# SEO Master

Next.js App Router 프로젝트의 SEO 최적화 점검 스킬

---

## Quick Checklist

### 새 페이지 생성 시
- [ ] metadata 또는 generateMetadata 설정
- [ ] Open Graph 이미지 (1200x630)
- [ ] 페이지별 고유한 title, description
- [ ] sitemap.ts에 페이지 추가

### 배포 전 점검
- [ ] /sitemap.xml 접근 가능
- [ ] /robots.txt 접근 가능
- [ ] OG 이미지 미리보기 테스트
- [ ] Core Web Vitals (INP, LCP, CLS) 점수 확인

---

## Workflow

### Step 1: 기본 설정 확인

```bash
# metadataBase 확인
grep -n "metadataBase" app/layout.tsx

# sitemap, robots 존재 확인
ls app/sitemap.ts app/robots.ts 2>/dev/null
```

### Step 2: OG 이미지 확인

```bash
# OG 이미지 파일 확인
ls public/og.png 2>/dev/null || ls app/opengraph-image.* 2>/dev/null

# openGraph 설정 확인
grep -n "openGraph" app/layout.tsx
```

### Step 3: 구조화 데이터 확인

```bash
# JSON-LD 사용 여부
grep -rn "application/ld+json" --include="*.tsx" | wc -l
```

### Step 4: favicon 확인

```bash
ls app/icon.tsx public/favicon.ico 2>/dev/null
```

### Step 5: I/O 및 캐싱 최적화 점검

SEO 성능에 직결되는 캐싱 전략을 확인합니다.

**체크리스트:**
- [ ] 데이터 페칭 시 `next: { revalidate }` 또는 `cache: 'force-cache'` 사용
- [ ] 불필요한 `cache: 'no-store'` 남용 여부
- [ ] On-Demand Revalidation (`revalidateTag`, `revalidatePath`) 구현
- [ ] 병렬 데이터 페칭 (`Promise.all`) 적용
- [ ] `loading.tsx` 및 `<Suspense>` 활용

```bash
# no-store 남용 확인
grep -rn "no-store\|force-dynamic" --include="*.tsx" --include="*.ts" | wc -l

# loading.tsx 존재 확인
find app -name "loading.tsx" | wc -l

# revalidate 설정 확인
grep -rn "revalidate" --include="*.tsx" --include="*.ts" | head -10
```

### Step 6: 고급 SEO 및 구조화 데이터 점검

리치 스니펫을 위한 고급 SEO 요소를 확인합니다.

**체크리스트:**
- [ ] 고급 JSON-LD 스키마 적용 (Article, BreadcrumbList, FAQ 등)
- [ ] `@graph`로 다중 스키마 연결
- [ ] Canonical URL 설정 (`alternates.canonical`)
- [ ] 리다이렉트 처리 (next.config.js `redirects`)
- [ ] 이미지 alt 텍스트 및 priority 설정
- [ ] 에러 페이지 커스터마이징 (not-found.js, error.js)

```bash
# JSON-LD 스키마 유형 확인
grep -rn "@type" --include="*.tsx" | grep -E "Article|BreadcrumbList|FAQ|LocalBusiness|HowTo"

# Canonical URL 설정 확인
grep -rn "canonical" --include="*.tsx" --include="*.ts" | head -5

# 에러 페이지 확인
ls app/not-found.tsx app/error.tsx 2>/dev/null
```

### Step 7: 시멘틱 HTML 구조 점검

SEO와 접근성에 직결되는 시멘틱 마크업을 확인합니다.

**체크리스트:**

#### 언어 설정
- [ ] `<html lang="ko">` (또는 적절한 언어 코드) — Google 언어 인식 및 스크린리더 기본

#### Heading 구조
- [ ] 페이지당 `<h1>` 태그 1개 존재
- [ ] h1 → h2 → h3 순차적 계층 유지 (건너뛰기 금지)
- [ ] heading에 페이지 핵심 키워드 포함 (단, 키워드 스터핑 금지)

#### 랜드마크 태그
- [ ] `<header>` - 헤더 영역
- [ ] `<nav aria-label="...">` - 네비게이션 (여러 개일 경우 각각 구분)
- [ ] `<main>` - 메인 콘텐츠 (페이지당 1개)
- [ ] `<aside aria-label="...">` - 사이드바, 관련 콘텐츠
- [ ] `<section aria-label="...">` - 논리적 섹션 구분 (반드시 내부에 `h2~h6` 포함, heading 없으면 시맨틱 의미 없음)
- [ ] `<article>` - 독립적 콘텐츠 (블로그 포스트, 카드 등)
- [ ] `<footer>` - 푸터 영역

#### 콘텐츠 시맨틱 태그
- [ ] `<time datetime="YYYY-MM-DD">` - 날짜/시간 표현 (Google이 발행일 인식에 사용)
- [ ] `<figure>` + `<figcaption>` - 이미지+캡션 묶음 (`alt`와 별개로 맥락 제공)
- [ ] `<dl>` / `<dt>` / `<dd>` - FAQ, 용어 정의 (`<div>` 대신 사용)
- [ ] `<address>` - 연락처 정보 (이메일, 주소, 전화번호)

#### 인터랙션 시맨틱
- [ ] 액션(submit, open, toggle): `<button>` 사용
- [ ] 네비게이션(페이지 이동): `<a href="...">` 사용
- [ ] `<div onClick>` / `<span onClick>` 패턴 없음 (키보드 접근 불가)

#### ARIA 속성
- [ ] 제목이 있는 섹션: `aria-labelledby` 사용
- [ ] 제목이 없는 섹션: `aria-label` 사용
- [ ] 아이콘 버튼: `aria-label` 필수
- [ ] 장식용 요소: `aria-hidden="true"`
- [ ] 외부 링크 아이콘: `aria-hidden="true"` (텍스트와 중복 방지)
- [ ] 시맨틱 태그로 해결 가능한 곳에 `role=` 남용 금지

```bash
# html lang 속성 확인
grep -rn "lang=" --include="*.tsx" app/layout.tsx

# h1 태그 존재 확인
grep -rn "<h1" --include="*.tsx" app/ components/ | head -10

# heading 계층 전체 확인 (h1~h3)
grep -rn "<h[1-3]" --include="*.tsx" app/ components/ | sort

# nav, main, aside 태그 사용 확인
grep -rn "<nav\|<main\|<aside" --include="*.tsx" app/ components/

# time 태그 사용 현황
grep -rn "<time" --include="*.tsx" | wc -l

# figure/figcaption 사용 현황
grep -rn "<figure\|<figcaption" --include="*.tsx" | wc -l

# dl/dt/dd 시맨틱 목록 사용 여부
grep -rn "<dl\|<dt\|<dd" --include="*.tsx" | wc -l

# div/span onClick 안티패턴 탐지
grep -rn "<div.*onClick\|<span.*onClick" --include="*.tsx" | wc -l

# aria-label 사용 현황
grep -rn "aria-label" --include="*.tsx" | wc -l

# role 속성 사용 현황 (남용 여부 검토)
grep -rn " role=" --include="*.tsx" | grep -Ev "role=\"(main|navigation|complementary|contentinfo|banner|search|form|dialog|alert)\""
```

### Step 8: AI SEO / GEO 점검

Google AI Overviews 및 생성형 AI 인용 최적화를 확인합니다. (`references/ai-geo.md` 상세 참조)

**체크리스트:**
- [ ] H2/H3가 질문형으로 작성됨 ("~란 무엇인가요?", "~하는 방법")
- [ ] FAQ/HowTo JSON-LD 스키마 적용
- [ ] 저자 Person 스키마 + `dateModified` 설정
- [ ] 핵심 답변이 H2 직후 2-3문장으로 요약됨 (역피라미드 구조)
- [ ] `<cite>` / `<blockquote>` 출처 마크업
- [ ] llms.txt 존재 및 형식 준수
- [ ] robots.txt에서 AI 크롤러 미차단 (GPTBot, ClaudeBot 등)
- [ ] Organization sameAs에 주요 플랫폼 포함
- [ ] foundingDate 설정
- [ ] 동일 Person이 author/creator/founder에 일관 사용

```bash
# H2가 질문형인지 확인
grep -rn "<h2" --include="*.tsx" | grep -E "\?|하는 방법|란 무엇"

# dateModified 설정 확인
grep -rn "dateModified" --include="*.tsx" --include="*.ts" | wc -l

# 저자 Person 스키마 확인
grep -rn '"@type": "Person"' --include="*.tsx" | wc -l

# llms.txt 존재 확인
ls app/llms.txt/route.ts public/llms.txt 2>/dev/null || echo "llms.txt 없음"

# AI 크롤러 차단 여부
grep -E "Disallow.*GPTBot|Disallow.*ClaudeBot|Disallow.*PerplexityBot" app/robots.ts && echo "AI 봇 차단됨"

# sameAs 플랫폼 수
grep -A 20 "sameAs" --include="*.tsx" -r | grep "https://" | wc -l

# foundingDate 존재
grep -rn "foundingDate" --include="*.tsx" --include="*.ts"
```

---

## Automated Checks

Lighthouse 기반 자동화 검증 명령어 모음:

```bash
# 1. Lighthouse SEO 점수 로컬 측정
npx lighthouse http://localhost:3000 --only-categories=seo --output=json | \
  node -e "const d=require('fs').readFileSync('/dev/stdin','utf8'); console.log('SEO:', JSON.parse(d).categories.seo.score * 100)"

# 2. JSON-LD 존재 여부 일괄 검증
for path in / /about /blog /pricing; do
  count=$(curl -s "http://localhost:3000${path}" | grep -c "application/ld+json" || echo 0)
  echo "${path}: ${count}개 JSON-LD"
done

# 3. sitemap.xml 상태 확인
curl -o /dev/null -s -w "sitemap.xml: HTTP %{http_code}\n" http://localhost:3000/sitemap.xml
curl -o /dev/null -s -w "robots.txt: HTTP %{http_code}\n" http://localhost:3000/robots.txt

# 4. OG 이미지 메타 태그 추출
curl -s http://localhost:3000 | grep -oP 'property="og:image" content="\K[^"]+' | head -5

# 5. alt 누락 이미지 탐지
grep -rn "<img\|<Image" --include="*.tsx" | grep -v 'alt=' | grep -v 'aria-hidden'

# 6. no-store 남용 현황
echo "no-store 사용 수: $(grep -rn "no-store\|force-dynamic" --include="*.tsx" --include="*.ts" | wc -l)"
```

---

## Report Format

> 심각도: 🔴 CRITICAL (즉시 수정) | 🟡 WARNING (1주 내) | 🔵 INFO (권장)

```markdown
# SEO Check Report

## 🔴 CRITICAL — SEO 점수 직접 하락, 크롤링/인덱싱 실패
- metadataBase: ✅/❌
- sitemap.ts: ✅/❌
- robots.ts: ✅/❌
- h1 태그 (1개): ✅/❌
- html lang: ✅/❌
- Canonical URL: ✅/❌

## 🟡 WARNING — 리치 결과 미노출, 성능 저하
- OG 이미지 (1200x630): ✅/❌
- openGraph 설정: ✅/❌
- JSON-LD: ✅/❌ (N개)
- no-store 남용: ✅없음/❌있음
- Heading 계층 (h1→h2→h3): ✅/❌
- loading.tsx: ✅/❌
- 에러 페이지 (not-found, error): ✅/❌
- 이미지 alt: ✅/❌

## 🟡 GEO — AI 검색 최적화
- llms.txt: ✅/❌
- AI 크롤러 접근: ✅/❌
- Organization sameAs (N개 플랫폼): ✅/❌
- foundingDate: ✅/❌
- Person 일관성 (author=creator=founder): ✅/❌

## 🔵 INFO — 접근성/시멘틱 개선, 모범 사례
- figure/figcaption: ✅/❌
- time datetime: ✅/❌
- dl/dt/dd (FAQ): ✅/❌
- nav/aside aria-label: ✅/❌
- @graph 연결: ✅/❌
- 병렬 페칭: ✅/❌

## 권장 조치 (우선순위 순)
1. 🔴 ...
2. 🟡 ...
3. 🔵 ...
```

---

## Troubleshooting

### OG 미리보기 안됨
- **원인:** OG 이미지 URL이 절대 경로가 아니거나 metadataBase 미설정
- **해결:** `metadataBase: new URL('https://example.com')` 설정 확인. OG 디버거로 테스트: https://developers.facebook.com/tools/debug/

### sitemap 크롤링 실패
- **원인:** sitemap.ts에서 동적 데이터 fetch 실패, 또는 빌드 시 DB 연결 불가
- **해결:** sitemap 빌드 시 에러 핸들링 추가. `curl -s https://example.com/sitemap.xml | head -20` 으로 확인

### CLS 점수 높음 (>0.1)
- **원인:** 이미지 width/height 미지정, 폰트 FOUT, 동적 콘텐츠 삽입
- **해결:** `next/image`에 width/height 필수 지정. `next/font`로 폰트 최적화. Skeleton UI 적용

### 페이지별 metadata 미적용
- **원인:** 상위 layout.tsx의 metadata가 하위 page를 덮어씀
- **해결:** 각 page.tsx에서 `generateMetadata` 또는 `metadata` export 확인

### JSON-LD 리치 결과 미표시
- **원인:** 필수 속성 누락, 또는 Google에서 아직 크롤링 안됨
- **해결:** Rich Results Test (https://search.google.com/test/rich-results) 로 검증. 크롤링 후 최대 2주 소요

### h1이 여러 개 탐지됨
- **원인:** 공통 layout.tsx에 h1이 있고 각 page.tsx에도 h1을 추가한 경우
- **해결:** layout에서 h1 제거, 각 페이지의 핵심 제목만 h1로 지정

### 스크린리더가 nav/section을 구별 못함
- **원인:** `<nav>` 또는 `<section>`에 `aria-label`이 없어 동일 랜드마크가 여러 개일 때 구분 불가
- **해결:** 모든 `<nav aria-label="주 메뉴">`, `<nav aria-label="푸터 메뉴">` 형태로 고유 레이블 부여

### section이 접근성 트리에서 generic으로 표시됨
- **원인:** `<section>` 내부에 heading(`h2~h6`)이 없음
- **해결:** section 내에 heading 추가 또는 `aria-label` 부여. heading 없이 레이아웃 목적이라면 `<div>` 사용이 적절

---

## Quick Fix Recipes

```tsx
// 1. metadataBase 설정 (layout.tsx)
export const metadata = {
  metadataBase: new URL('https://example.com'),
};

// 2. 페이지별 동적 metadata
export async function generateMetadata({ params }) {
  const { slug } = await params;
  return { title: `${slug} | SiteName`, description: '...' };
}

// 3. OG 이미지: app/opengraph-image.tsx 파일 생성 -> 자동 OG 이미지

// 4. sitemap.ts 기본 템플릿
export default function sitemap() {
  return [{ url: 'https://example.com', lastModified: new Date() }];
}

// 5. robots.ts 기본 템플릿
export default function robots() {
  return { rules: { userAgent: '*', allow: '/' }, sitemap: 'https://example.com/sitemap.xml' };
}

// 6. JSON-LD 컴포넌트 -> references/structured-data-recipes.md 참조

// 7. Canonical URL
export const metadata = { alternates: { canonical: 'https://example.com/page' } };

// 8. 404 페이지: app/not-found.tsx 생성

// 9. 이미지 alt 일괄 검사
// grep -rn "<img" --include="*.tsx" | grep -v "alt="

// 10. loading.tsx 추가 (Streaming SSR)
// app/[route]/loading.tsx -> Suspense 자동 적용

// 11. html lang 설정 (app/layout.tsx)
export default function RootLayout({ children }) {
  return <html lang="ko">{children}</html>;
}

// 12. time 태그로 날짜 마크업
<time dateTime="2025-01-15">2025년 1월 15일</time>

// 13. figure/figcaption으로 이미지+캡션
<figure>
  <Image src="/hero.png" alt="서비스 대시보드 화면" width={800} height={500} />
  <figcaption>실시간 데이터 현황을 한눈에 파악할 수 있는 대시보드</figcaption>
</figure>

// 14. FAQ에 dl/dt/dd 사용
<dl>
  <dt>무료 체험 기간은 얼마인가요?</dt>
  <dd>14일 동안 모든 기능을 무료로 사용할 수 있습니다.</dd>
  <dt>신용카드 없이 시작할 수 있나요?</dt>
  <dd>네, 체험 기간에는 카드 등록이 필요하지 않습니다.</dd>
</dl>

// 15. aside로 관련 콘텐츠 영역
<aside aria-label="관련 아티클">
  <h2>관련 글</h2>
  {relatedPosts.map(post => <a href={post.href}>{post.title}</a>)}
</aside>

// 16. button vs a 구분
// 액션 → button
<button type="button" onClick={openModal}>자세히 보기</button>
// 페이지 이동 → a
<a href="/pricing">요금제 확인하기</a>
```

---

## Anti-patterns

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| 모든 페이지 동일 title/description | 중복 콘텐츠 | 페이지별 고유 metadata |
| OG 이미지 없음 | SNS 공유 시 미리보기 없음 | 1200x630 OG 이미지 필수 |
| sitemap에 404 페이지 포함 | 크롤링 예산 낭비 | 동적 sitemap + 정기 검증 |
| no-store 남용 | 서버 부하, 느린 TTFB | ISR/SSG 우선 적용 |
| heading 계층 건너뛰기 | SEO/접근성 악화 | h1>h2>h3 순차 구조 |
| `<html lang>` 누락 | 언어 인식 실패, 스크린리더 오작동 | `<html lang="ko">` 명시 |
| `<div class="nav">` 등 클래스로 역할 표현 | 시맨틱 정보 손실 | `<nav>`, `<aside>` 등 시맨틱 태그 사용 |
| `<div onClick>` / `<span onClick>` | 키보드 접근 불가, 접근성 위반 | `<button>` (액션) / `<a href>` (이동) |
| `role="button"` + `<div>` | 시맨틱 태그 사용 가능한데 role로 우회 | `<button>` 직접 사용 |
| FAQ에 `<div>` 나열 | 질문-답변 관계 시맨틱 없음 | `<dl><dt><dd>` 구조 사용 |
| 날짜를 텍스트로만 표현 (`2024년 1월`) | Google이 날짜 인식 불가 | `<time datetime="2024-01-01">` 래핑 |
| 이미지 캡션을 `<p>` 또는 `<span>` | 이미지와 캡션 관계 시맨틱 없음 | `<figure><img /><figcaption>` |
| heading에 키워드 과잉 삽입 | 스패밍으로 인식, SEO 패널티 | 자연스러운 문장 구조 유지 |

---

## Impact Metrics

| 항목 | 미적용 | 적용 후 | 개선폭 |
|------|:------:|:------:|:------:|
| Lighthouse SEO 점수 | 60~70 | 95~100 | +30pt |
| 크롤링 커버리지 | 40~60% | 95%+ | +40% |
| 리치 결과 노출 | 0 | 5~10 유형 | 클릭률 +20~30% |
| Core Web Vitals (LCP) | 3~5s | <2.5s | 이탈률 -15% |
| OG 미리보기 | 미표시 | 완전 표시 | 공유 클릭률 +40% |

---

## References

- `references/seo-checklist.md` - 상세 체크리스트 (메타데이터, CWV, 구조화 데이터)
- `references/technical-seo.md` - Canonical, 리다이렉트, 이미지 SEO
- `references/structured-data-recipes.md` - 업종별 JSON-LD 레시피 (XSS 이스케이프 포함)
- `references/advanced-json-ld.md` - @graph 다중 스키마, 엔티티 연결
- `references/io-optimization.md` - ISR/SSG 캐싱 전략, Streaming SSR
- `references/international-seo.md` - hreflang, 다국어/다지역 SEO
- `references/ai-geo.md` - AI Overviews + GEO 최적화 (llms.txt, AI 크롤러, E-E-A-T, 엔터티 연결)
- `references/content-seo.md` - 내부 링크 전략, 콘텐츠 클러스터링
