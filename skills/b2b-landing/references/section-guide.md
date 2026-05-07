# B2B SaaS Landing Page — Section Guide

10개 섹션의 상세 구현 가이드. HTML 구조, 스타일 전략, 콘텐츠 방향 포함.

---

## 0. CSS 변수 및 기본 스타일

페이지 생성 전, 반드시 CSS 변수를 정의한다.

### 필수 변수

```css
:root {
  /* 브랜드 색상 (최대 3색) */
  --color-primary: /* 사용자 브랜드 색상 */;
  --color-primary-hover: /* primary의 10% 어두운 변형 */;
  --color-secondary: /* 보조 색상 */;
  --color-accent: /* 강조 색상 (CTA 등) */;

  /* 중립색 */
  --color-bg: #FFFFFF;
  --color-bg-alt: #F9FAFB;
  --color-text: #111827;
  --color-text-secondary: #6B7280;
  --color-border: #E5E7EB;

  /* 타이포그래피 */
  --font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, sans-serif;
  --font-size-base: 1rem;       /* 16px */
  --font-size-lg: 1.125rem;     /* 18px */
  --font-size-xl: 1.25rem;      /* 20px */
  --font-size-2xl: 1.5rem;      /* 24px */
  --font-size-3xl: 1.875rem;    /* 30px */
  --font-size-4xl: 2.25rem;     /* 36px */
  --font-size-hero: 3rem;       /* 48px, 모바일에서 2rem */

  /* 간격 */
  --spacing-section: 5rem;      /* 섹션 간 간격 */
  --spacing-inner: 2rem;        /* 섹션 내부 간격 */
  --max-width: 1200px;          /* 콘텐츠 최대 너비 */

  /* 애니메이션 */
  --transition-fast: 0.2s ease-in-out;
  --transition-normal: 0.3s ease-in-out;

  /* 반경 */
  --radius-sm: 0.375rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
}

/* 다크 모드 */
@media (prefers-color-scheme: dark) {
  :root {
    --color-bg: #0F172A;
    --color-bg-alt: #1E293B;
    --color-text: #F1F5F9;
    --color-text-secondary: #94A3B8;
    --color-border: #334155;
  }
}

/* 모션 감소 */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

### 기본 스타일

```css
* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: var(--font-family);
  font-size: var(--font-size-base);
  color: var(--color-text);
  background: var(--color-bg);
  line-height: 1.6;
  -webkit-font-smoothing: antialiased;
}

.container {
  max-width: var(--max-width);
  margin: 0 auto;
  padding: 0 1.5rem;
}

section {
  padding: var(--spacing-section) 0;
}

/* 포커스 스타일 (접근성 필수) */
:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}
```

---

## 1. Header

### 역할
브랜드 인식 + 신뢰 신호 제공. 스크롤 시 고정(sticky).

### HTML 구조

```html
<header role="banner">
  <nav class="container header-nav" aria-label="Main navigation">
    <a href="/" class="logo" aria-label="[서비스명] 홈">
      <!-- 로고 이미지 또는 텍스트 -->
    </a>
    <div class="trust-badges" aria-label="인증 및 수상">
      <!-- Trust Badge 1~3개 -->
    </div>
  </nav>
</header>
```

### 콘텐츠 전략
- 로고는 좌측, Trust Badges는 우측
- Trust Badges 예시: "ISO 27001 인증", "2024 서비스 대상", "SOC 2 Type II"
- 네비게이션 링크는 최소화 (랜딩 페이지는 단일 CTA 집중)
- 스크롤 시 배경에 미세한 블러/그림자 추가 (backdrop-filter)

### 스타일 포인트
- `position: sticky; top: 0; z-index: 100;`
- 높이 60~72px
- 배경: `var(--color-bg)` + 스크롤 시 그림자

---

## 2. Hero Section

### 역할
첫인상. 3초 안에 "이 서비스가 나에게 필요한 이유"를 전달.

### HTML 구조

```html
<section class="hero" aria-labelledby="hero-heading">
  <div class="container hero-grid">
    <div class="hero-content">
      <h1 id="hero-heading" class="hero-title">
        <!-- 대형 헤드라인: 고객의 결과/변화 중심 -->
      </h1>
      <p class="hero-subtitle">
        <!-- 서브헤딩: 1~2문장으로 구체적 설명 -->
      </p>
      <div class="hero-cta">
        <a href="#cta" class="btn btn-primary" role="button">
          <!-- CTA 문구: "무료로 시작하기", "데모 신청하기" -->
        </a>
        <p class="reassurance-text">
          <!-- 안심 문구: "카드 등록 없이 14일 무료", "설치 없이 바로 시작" -->
        </p>
      </div>
    </div>
    <div class="hero-image">
      <img src="..." alt="[서비스명] 대시보드 화면" loading="eager" />
    </div>
  </div>
</section>
```

### 콘텐츠 전략
- 헤드라인: 고객의 결과/변화 ("매주 8시간을 돌려받으세요", "팀 보고서, 자동으로 완성하세요")
- 서브헤딩: 구체적 설명 1~2문장
- CTA 버튼: 한 개만. 명확한 행동 ("무료로 시작하기")
- 안심 문구: CTA 바로 아래 ("카드 등록 없이", "3분이면 충분합니다")
- 이미지: 실제 제품 스크린샷 또는 목업

### 레이아웃
- 데스크탑: 좌측 텍스트 (55%) + 우측 이미지 (45%) 그리드
- 모바일: 텍스트 → 이미지 수직 배치
- Hero 높이: 최소 `calc(100vh - 72px)` 또는 자연 높이

### 금지 사항
- Name/Email 입력 폼 넣지 않기 (B2C 패턴)
- 슬라이드쇼/캐러셀 넣지 않기
- 다중 CTA 버튼 (혼란)

---

## 3. The Problem

### 역할
고객의 Pain Point를 정확히 짚어 공감 유도. "이 서비스가 내 문제를 알고 있다"는 인상.

### HTML 구조

```html
<section class="problem" aria-labelledby="problem-heading">
  <div class="container">
    <h2 id="problem-heading" class="section-title">이런 문제, 겪고 계시죠?</h2>
    <div class="problem-grid">
      <article class="pain-point">
        <h3><!-- Pain Point 1 --></h3>
        <p><!-- 구체적 상황 설명 --></p>
      </article>
      <article class="pain-point">
        <h3><!-- Pain Point 2 --></h3>
        <p><!-- 구체적 상황 설명 --></p>
      </article>
      <article class="pain-point">
        <h3><!-- Pain Point 3 --></h3>
        <p><!-- 구체적 상황 설명 --></p>
      </article>
    </div>
  </div>
</section>
```

### 콘텐츠 전략
- Pain Point 3개 (3의 법칙)
- 의사결정자 관점: 비용, 시간, 리스크 중심
- 구체적 상황 묘사 ("매주 금요일, 팀원 5명의 보고서를 수작업으로 취합하고 계신가요?")
- 감정 유발 후 해결책 섹션으로 자연스러운 전환

### 레이아웃
- 3열 그리드 (데스크탑) → 1열 (모바일)
- 각 카드에 미세한 보더 또는 배경색 구분
- 배경색: `var(--color-bg-alt)` 로 이전 섹션과 구분

---

## 4. How We Solve This (Solution)

### 역할
Problem 섹션의 직접적 해답. "이렇게 해결합니다"를 기능이 아닌 혜택으로 전달.

### HTML 구조

```html
<section class="solution" aria-labelledby="solution-heading">
  <div class="container">
    <h2 id="solution-heading" class="section-title">이렇게 해결합니다</h2>
    <div class="solution-grid">
      <article class="feature-benefit">
        <h3><!-- 혜택 중심 제목 --></h3>
        <p><!-- 기능이 어떻게 혜택을 제공하는지 --></p>
      </article>
      <!-- x3 -->
    </div>
  </div>
</section>
```

### 콘텐츠 전략
- Pain Point와 1:1 매핑 (문제1 → 해결1)
- 기능이 아닌 혜택 중심 ("실시간 동기화" → "팀 전체가 항상 같은 정보를 봅니다")
- 가능하면 수치 포함 ("보고서 작성 시간 80% 단축")

### 레이아웃
- Problem과 동일한 3열 그리드
- 배경색: `var(--color-bg)` (Problem과 교차)

---

## 5. Trusted By (Social Proof)

### 역할
사회적 증거. "이미 검증된 서비스"라는 신뢰감.

### HTML 구조

```html
<section class="social-proof" aria-labelledby="social-proof-heading">
  <div class="container">
    <h2 id="social-proof-heading" class="section-title">
      <!-- "1,200개 팀이 선택했습니다" 또는 "신뢰하는 기업들" -->
    </h2>
    <div class="logo-grid" role="list" aria-label="고객 기업 목록">
      <div role="listitem"><img src="..." alt="[기업명] 로고" loading="lazy" /></div>
      <!-- x5~8 -->
    </div>
  </div>
</section>
```

### 콘텐츠 전략
- 수치 + 로고 조합이 최선 ("1,200개 팀이 선택했습니다" + 로고 5~8개)
- 대기업 로고가 있으면 효과 극대화
- 로고가 없으면 수치만: "2019년부터 서비스", "50,000명이 선택", "4.8점 (리뷰 2,300개)"
- 로고는 그레이스케일로 통일 (시각적 일관성)

### 레이아웃
- 로고 가로 나열, 간격 균등
- 모바일: 2~3열 그리드
- 구분선으로 상하 섹션과 분리

---

## 6. How It Works

### 역할
사용 방법을 단순화하여 "쉽게 시작할 수 있다"는 인식.

### HTML 구조

```html
<section class="how-it-works" aria-labelledby="how-heading">
  <div class="container">
    <h2 id="how-heading" class="section-title">3단계로 시작하세요</h2>
    <ol class="steps">
      <li class="step">
        <span class="step-number" aria-hidden="true">1</span>
        <h3><!-- 단계 제목 --></h3>
        <p><!-- 간단한 설명 --></p>
      </li>
      <li class="step">
        <span class="step-number" aria-hidden="true">2</span>
        <h3><!-- 단계 제목 --></h3>
        <p><!-- 간단한 설명 --></p>
      </li>
      <li class="step">
        <span class="step-number" aria-hidden="true">3</span>
        <h3><!-- 단계 제목 --></h3>
        <p><!-- 간단한 설명 --></p>
      </li>
    </ol>
  </div>
</section>
```

### 콘텐츠 전략
- 반드시 3단계 (인지 부하 최소화)
- 첫 단계는 최대한 쉽게 ("가입하고 팀 초대")
- 마지막 단계는 결과/혜택 ("자동 리포트 받기")
- 화살표/커넥터로 단계 간 흐름 시각화

### 레이아웃
- 데스크탑: 가로 배치 + 단계 간 화살표
- 모바일: 세로 배치 + 단계 간 연결선
- 배경색: `var(--color-bg-alt)`

---

## 7. Product Detail

### 역할
제품의 구체적 모습 + 핵심 혜택 요약.

### HTML 구조

```html
<section class="product-detail" aria-labelledby="product-heading">
  <div class="container product-grid">
    <div class="product-image">
      <img src="..." alt="[서비스명] 주요 기능 화면" loading="lazy" />
    </div>
    <div class="product-benefits">
      <h2 id="product-heading">왜 [서비스명]인가요?</h2>
      <ul class="benefit-list">
        <li><!-- Key Benefit --></li>
        <li><!-- Key Advantage --></li>
        <li><!-- Why Choose Us --></li>
      </ul>
    </div>
  </div>
</section>
```

### 콘텐츠 전략
- 좌측 제품 이미지(스크린샷/목업) + 우측 체크리스트
- 체크리스트 3~5개 항목
- 경쟁사 대비 차별점 강조
- 항목은 "결과" 형태로 작성 ("보고서 자동 생성" 보다 "보고서 작성 시간 80% 절약")

### 레이아웃
- 데스크탑: 좌측 이미지 (50%) + 우측 텍스트 (50%)
- 모바일: 이미지 → 텍스트 수직 배치

---

## 8. FAQ

### 역할
구매 장벽 해소. 실제 고객이 묻는 질문으로 구성.

### HTML 구조

```html
<section class="faq" aria-labelledby="faq-heading">
  <div class="container">
    <h2 id="faq-heading" class="section-title">자주 묻는 질문</h2>
    <div class="faq-list">
      <details>
        <summary><!-- 질문 --></summary>
        <p><!-- 답변 --></p>
      </details>
      <!-- x3~5 -->
    </div>
  </div>
</section>
```

### 콘텐츠 전략
- `<details>/<summary>`로 JS 없이 아코디언 구현 (시맨틱 + 성능)
- 질문 3~5개, 실제 구매 장벽 순서:
  1. 가격/비용 관련
  2. 기존 도구 연동/마이그레이션
  3. 데이터 보안/개인정보
  4. 도입 기간/지원
  5. 해지/환불 정책
- 답변은 격식체 (합니다)
- 답변 끝에 CTA 링크 포함 가능 ("더 궁금하신 점이 있으시면 문의해 주세요")

### 스타일 포인트
- `details[open] summary` 스타일 변경
- 보더 아래쪽으로 구분
- summary에 +/- 아이콘 (CSS로 구현)
- 배경색: `var(--color-bg-alt)`

---

## 9. Final CTA

### 역할
마지막 전환 기회. 페이지 전체 내용을 요약하고 행동 유도.

### HTML 구조

```html
<section class="final-cta" aria-labelledby="final-cta-heading">
  <div class="container final-cta-content">
    <h2 id="final-cta-heading">시작할 준비가 되셨나요?</h2>
    <a href="#" class="btn btn-primary btn-lg" role="button">
      <!-- Hero와 동일한 CTA 문구 -->
    </a>
    <p class="reassurance-text">
      <!-- 안심 문구: "약정 없이, 언제든 해지 가능합니다" -->
    </p>
  </div>
</section>
```

### 콘텐츠 전략
- 헤드라인: "시작할 준비가 되셨나요?" 또는 결과 재강조
- CTA 버튼: Hero와 동일한 문구 (일관성)
- 안심 문구: "약정 없이, 언제든 해지 가능합니다", "카드 등록 없이 시작"
- 배경색으로 시각적 강조 (Primary 색상 배경 + 흰색 텍스트)

### 레이아웃
- 중앙 정렬, 텍스트 중심
- CTA 버튼 크기 확대 (Hero보다 크게)

---

## 10. Footer

### 역할
법적 필수 정보 + 보조 네비게이션.

### HTML 구조

```html
<footer role="contentinfo">
  <div class="container footer-content">
    <div class="footer-logo">
      <a href="/" aria-label="[서비스명] 홈"><!-- 로고 --></a>
    </div>
    <nav class="footer-links" aria-label="Footer navigation">
      <a href="/privacy">개인정보 처리방침</a>
      <a href="/terms">이용약관</a>
      <a href="/contact">문의하기</a>
    </nav>
    <p class="copyright">&copy; 2024 [서비스명]. All rights reserved.</p>
  </div>
</footer>
```

### 콘텐츠 전략
- 최소한의 링크: 개인정보 처리방침, 이용약관, 문의하기
- 사업자 정보 (한국 법적 요구사항에 따라)
- SNS 링크는 선택

### 레이아웃
- 단순 중앙 정렬 또는 3열
- 배경색: `var(--color-bg-alt)` 또는 어두운 색상
- 상단 보더로 구분

---

## 반응형 브레이크포인트

```css
/* 모바일 퍼스트: 기본 스타일은 모바일 */

/* 태블릿 */
@media (min-width: 768px) {
  .hero-grid { grid-template-columns: 1fr 1fr; }
  .problem-grid { grid-template-columns: repeat(3, 1fr); }
  .solution-grid { grid-template-columns: repeat(3, 1fr); }
  .steps { flex-direction: row; }
  .product-grid { grid-template-columns: 1fr 1fr; }
}

/* 데스크탑 */
@media (min-width: 1024px) {
  :root {
    --font-size-hero: 3.5rem;
    --spacing-section: 6rem;
  }
}
```

## CTA 버튼 스타일

```css
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 44px;      /* 터치 타겟 최소 */
  min-width: 44px;
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: var(--radius-md);
  font-size: var(--font-size-lg);
  font-weight: 600;
  text-decoration: none;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-primary {
  background: var(--color-primary);
  color: #FFFFFF;
}

.btn-primary:hover {
  background: var(--color-primary-hover);
  transform: translateY(-1px);
}

.btn-primary:active {
  transform: scale(0.98);
}

.btn-lg {
  padding: 1rem 2rem;
  font-size: var(--font-size-xl);
}
```
