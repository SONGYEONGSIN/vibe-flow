# AI SEO / GEO 최적화 가이드

Google AI Overviews 및 생성형 AI 인용 최적화 전략 (Generative Engine Optimization)

---

## 1. AI 인용을 유도하는 콘텐츠 구조

### 역피라미드 구조 (가장 중요)

AI는 페이지 상단의 명확한 답변을 우선 인용합니다.

```
H2: [질문형 제목] (예: "Next.js란 무엇인가요?")
  → 핵심 답변 2-3문장 (즉시 요약)
  → 상세 설명 및 예시
  → 관련 정보
```

**DO:**
```tsx
<h2>Next.js App Router와 Pages Router의 차이점은 무엇인가요?</h2>
<p>
  App Router는 React Server Components를 기반으로 하며, 서버에서 직접 데이터를
  페칭합니다. Pages Router는 getServerSideProps/getStaticProps로 데이터를
  가져옵니다. 신규 프로젝트는 App Router를 권장합니다.
</p>
```

**DON'T:**
```tsx
<h2>라우팅 시스템 비교</h2>
<p>두 라우팅 시스템은 다음과 같은 특징이 있습니다...</p>
```

### AI 친화적 콘텐츠 패턴

| 패턴 | 효과 | 구현 |
|------|------|------|
| 질문-답변 (FAQ) | AI Overview 직접 인용 | `<dl><dt><dd>` + FAQPage 스키마 |
| 숫자 리스트 | 인용 가능한 단위 | `<ol>` 구조 |
| 비교표 | 특정 질의에 노출 | `<table>` + thead/tbody |
| 정의 블록 | 용어 설명 인용 | `<dfn>` + 앞뒤 컨텍스트 |

---

## 2. 기술적 최적화

### JSON-LD가 AI 엔티티 파악에 활용되는 원리

Google은 JSON-LD의 구조화 데이터로 페이지의 주제(entity)를 파악합니다.
FAQ 스키마 → AI Overviews에서 직접 답변으로 표시될 확률 증가
HowTo 스키마 → 단계별 가이드 질의에 리치 결과 노출

```typescript
// FAQ 스키마 — AI Overviews 최적화에 가장 효과적
function faqSchemaForAI(faqs: { question: string; answer: string }[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: faqs.map((faq) => ({
      '@type': 'Question',
      name: faq.question,  // 실제 사용자 검색어와 일치시킬 것
      acceptedAnswer: {
        '@type': 'Answer',
        text: faq.answer,  // 200자 이내로 핵심 답변만
      },
    })),
  };
}

// HowTo 스키마 — "~하는 방법" 질의 최적화
function howToSchemaForAI(title: string, steps: { name: string; text: string }[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'HowTo',
    name: title,
    step: steps.map((step, i) => ({
      '@type': 'HowToStep',
      position: i + 1,
      name: step.name,
      text: step.text,
    })),
  };
}
```

### dateModified 설정 (신선도 시그널)

AI는 최신 정보를 우선합니다. 콘텐츠 수정 시 반드시 업데이트:

```typescript
// app/blog/[slug]/page.tsx
const articleSchema = {
  '@context': 'https://schema.org',
  '@type': 'Article',
  headline: post.title,
  datePublished: post.createdAt,   // ISO 8601
  dateModified: post.updatedAt,    // 수정할 때마다 업데이트 필수
  author: {
    '@type': 'Person',
    name: post.author.name,
    url: post.author.profileUrl,
  },
};
```

---

## 3. E-E-A-T 시그널 강화

E-E-A-T (Experience, Expertise, Authoritativeness, Trustworthiness)는 Google AI가 신뢰도 판단에 사용하는 기준입니다.

### 저자 Person 스키마

```typescript
const authorSchema = {
  '@context': 'https://schema.org',
  '@type': 'Person',
  name: '김철수',
  jobTitle: 'Senior Frontend Engineer',
  url: 'https://example.com/author/kim',
  sameAs: [
    'https://github.com/kim',
    'https://linkedin.com/in/kim',
  ],
  // 전문성 증명
  knowsAbout: ['Next.js', 'React', 'SEO', 'TypeScript'],
  affiliation: {
    '@type': 'Organization',
    name: '소속 회사명',
  },
};
```

### 출처 마크업 (cite, blockquote)

```tsx
// 외부 연구/통계 인용
<blockquote cite="https://web.dev/articles/inp">
  <p>INP(Interaction to Next Paint)는 페이지의 모든 클릭, 탭, 키 누르기를 측정합니다.</p>
  <footer>
    <cite>
      <a href="https://web.dev/articles/inp" rel="noopener">web.dev — INP 가이드</a>
    </cite>
  </footer>
</blockquote>
```

### 저자 바이오 시맨틱

```tsx
// 블로그 포스트 저자 영역
<address>
  <a href="/author/kim" rel="author">김철수</a>
  <span> — Senior Frontend Engineer, 5년 경력</span>
</address>
```

---

## 4. Google AI Overviews 최적화 체크리스트

### 콘텐츠 구조
- [ ] H2/H3가 질문형으로 작성됨 ("~란 무엇인가요?", "~하는 방법은?")
- [ ] 각 H2 직후 핵심 답변 2-3문장 (200자 이내)
- [ ] 숫자 목록, 비교표 활용
- [ ] 전문 용어에 `<dfn>` 태그 사용

### 구조화 데이터
- [ ] FAQ/HowTo JSON-LD 스키마 적용
- [ ] `dateModified` 설정 및 최신 상태 유지
- [ ] 저자 Person 스키마 구현
- [ ] Article 스키마의 `keywords` 필드 활용

### 신뢰도
- [ ] 저자 정보 (이름, 직책, 경력) 명시
- [ ] 외부 권위 있는 소스 인용 (`<cite>`)
- [ ] 정보 최신화 날짜 표시 (`<time datetime="...">최종 수정일</time>`)
- [ ] HTTPS + 안전한 페이지

### E-E-A-T
- [ ] 저자 바이오 페이지 존재
- [ ] 저자 소셜/GitHub 링크
- [ ] 회사/조직 정보 명시

---

## 5. 검증 명령어

```bash
# H2가 질문형인지 확인
grep -rn "<h2" --include="*.tsx" | grep -E "\?|하는 방법|란 무엇|어떻게"

# dateModified 설정 확인
grep -rn "dateModified" --include="*.tsx" --include="*.ts" | wc -l

# 저자 Person 스키마 확인
grep -rn '"@type": "Person"\|@type.*Person' --include="*.tsx" | wc -l

# FAQPage 스키마 확인
grep -rn "FAQPage\|HowTo" --include="*.tsx" | wc -l

# cite/blockquote 사용 확인
grep -rn "<cite\|<blockquote" --include="*.tsx" | wc -l

# dfn 태그 사용 확인
grep -rn "<dfn" --include="*.tsx" | wc -l
```

---

## Anti-patterns

| 안티패턴 | 문제 | 해결 |
|----------|------|------|
| H2가 명사형 ("라우팅 시스템") | AI가 질문 매칭 어려움 | 질문형으로 변환 ("어떻게 라우팅하나요?") |
| 핵심 답변이 본문 중간 | AI Overview 인용 불가 | H2 직후 요약 배치 |
| dateModified 고정 또는 누락 | 신선도 점수 하락 | 실제 수정일 자동 갱신 |
| 저자 익명 | E-E-A-T 불신 | Person 스키마 + 바이오 페이지 |
| 긴 FAQ 답변 (500자+) | AI 인용 비선호 | 200자 이내로 핵심만 |
| llms.txt 미제공 | LLM 크롤러가 사이트 맥락 파악 불가 | llms.txt 표준 형식으로 작성 |
| AI 크롤러 robots.txt 차단 | AI 검색 결과에서 제외 | GPTBot, ClaudeBot 등 허용 |
| Organization sameAs 불완전 | 엔터티 교차 확인 실패 | 주요 플랫폼 모두 포함 |

---

## 6. llms.txt

LLM 크롤러가 사이트를 이해할 수 있도록 제공하는 표준 텍스트 파일입니다.

### 표준 형식

```
# 사이트명

> 사이트 한 줄 요약

## 주요 페이지

- [페이지명](URL): 간단한 설명

## 기술 스택

- Next.js, TypeScript, ...

## 연락처

- 이메일, SNS 링크
```

### Next.js App Router 구현

```typescript
// app/llms.txt/route.ts
export function GET() {
  const content = `# 사이트명

> 사이트 한 줄 요약

## 주요 페이지

- [홈](https://example.com): 서비스 소개
- [블로그](https://example.com/blog): 기술 블로그
- [가격](https://example.com/pricing): 요금제 안내

## Sitemap

- https://example.com/sitemap.xml
`;

  return new Response(content, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
```

### 정적 사이트 (Hugo/Astro)

`public/llms.txt`에 직접 배치합니다.

### 포함 필수 / 불필요

| 포함 필수 | 포함 불필요 |
|-----------|-------------|
| 사이트 요약 | 상품 목록 (sitemap이 커버) |
| 주요 페이지 링크 | 동적 데이터 (가격 등) |
| sitemap 참조 | 내부 API 경로 |
| 연락처/SNS | 개인정보 |

---

## 7. AI 크롤러 접근성

AI 검색 엔진이 사이트를 크롤링할 수 있도록 robots.txt에서 차단하지 않아야 합니다.

### AI 크롤러 User-Agent 목록

| User-Agent | 서비스 |
|------------|--------|
| GPTBot | OpenAI (ChatGPT, AI Overviews) |
| ChatGPT-User | ChatGPT 브라우징 |
| ClaudeBot | Anthropic (Claude) |
| PerplexityBot | Perplexity AI |
| Google-Extended | Google AI (Gemini) |
| Applebot-Extended | Apple Intelligence |

### robots.txt 점검

위 봇들이 `Disallow`되어 있지 않은지 확인합니다. 기본적으로 허용(`Allow: /`)이 권장됩니다.

```typescript
// app/robots.ts — AI 크롤러 허용 예시
import { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/api/', '/admin/'],
      },
      // AI 크롤러를 명시적으로 차단하지 않음
      // 차단이 필요한 경우에만 개별 지정
    ],
    sitemap: 'https://example.com/sitemap.xml',
  };
}
```

**주의:** 일부 CMS/프레임워크 보일러플레이트가 AI 봇을 기본 차단하는 경우가 있습니다. 배포 전 반드시 확인하세요.

---

## 8. 엔터티 교차 연결

AI가 사이트/브랜드/인물을 하나의 엔터티로 인식하려면 구조화 데이터 간 교차 연결이 필요합니다.

### Organization sameAs 완전성

```typescript
const orgSchema = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: '회사명',
  url: 'https://example.com',
  foundingDate: '2020-01-01',  // 브랜드 신뢰 신호
  sameAs: [
    'https://twitter.com/example',
    'https://instagram.com/example',
    'https://youtube.com/@example',
    'https://github.com/example',
    'https://linkedin.com/company/example',
    // 주요 플랫폼을 빠짐없이 포함
  ],
  founder: {
    '@type': 'Person',
    name: '홍길동',
    sameAs: 'https://example.com/about',
  },
};
```

### 점검 포인트

- `foundingDate` 포함 여부
- `sameAs`에 활성 플랫폼 모두 나열 (웹사이트, SNS, YouTube, GitHub 등)
- 동일 Person이 `author`, `creator`, `founder`에 일관되게 사용되는지
- Person 스키마의 `sameAs`와 Organization의 `sameAs`가 혼동되지 않는지

### 검증 명령어

```bash
# llms.txt 존재 확인
ls app/llms.txt/route.ts public/llms.txt 2>/dev/null

# robots.txt AI 봇 차단 여부
grep -E "GPTBot|ClaudeBot|PerplexityBot|Google-Extended" app/robots.ts

# Organization sameAs 개수
grep -c "sameAs" components/**/StructuredData.tsx 2>/dev/null

# foundingDate 존재
grep -rn "foundingDate" --include="*.tsx" --include="*.ts"

# Person 일관성 (author, creator, founder)
grep -rn '"@type": "Person"' --include="*.tsx" --include="*.ts"
```
