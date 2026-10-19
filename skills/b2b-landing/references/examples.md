# B2B SaaS Landing Page — Before/After Examples

나쁜 랜딩과 좋은 랜딩의 비교 예시 3가지.

---

## Example 1: Hero Section

### Before (C등급)

```html
<div class="hero">
  <div class="hero-left">
    <h1>혁신적인 AI 기반 협업 플랫폼</h1>
    <p>강력한 기능으로 팀의 생산성을 높여보세요.</p>
    <form>
      <input type="text" placeholder="이름" />
      <input type="email" placeholder="이메일" />
      <button>시작하기</button>
    </form>
  </div>
  <div class="hero-right">
    <img src="abstract-illustration.svg" />
  </div>
</div>
```

**문제점:**
- `<div>` 남용 (시맨틱 HTML 미사용)
- "혁신적인", "강력한" → 모호한 표현
- "AI 기반" → AI는 수단, 결과가 없음
- 입력 폼 → B2C 패턴, 진입 장벽
- 추상적 일러스트 → 제품이 뭔지 알 수 없음
- `img`에 `alt` 없음
- 안심 문구 없음

### After (S등급)

```html
<section class="hero" aria-labelledby="hero-heading">
  <div class="container hero-grid">
    <div class="hero-content">
      <h1 id="hero-heading" class="hero-title">
        매주 8시간을 돌려받으세요
      </h1>
      <p class="hero-subtitle">
        TeamFlow가 팀 보고서를 자동으로 취합하고,
        실시간 대시보드로 보여드립니다.
      </p>
      <div class="hero-cta">
        <a href="/signup" class="btn btn-primary" role="button">
          무료로 시작하기
        </a>
        <p class="reassurance-text">
          카드 등록 없이 14일 무료 체험
        </p>
      </div>
    </div>
    <div class="hero-image">
      <img
        src="/images/dashboard-preview.webp"
        alt="TeamFlow 대시보드에서 팀 보고서가 자동으로 취합되는 화면"
        loading="eager"
        width="600"
        height="400"
      />
    </div>
  </div>
</section>
```

**개선점:**
- `<section>`, `aria-labelledby` → 시맨틱 + 접근성
- "매주 8시간을 돌려받으세요" → 구체적 결과
- 서비스명 + 구체적 기능 설명
- CTA 버튼만 (폼 제거)
- 안심 문구 추가
- 실제 제품 스크린샷 사용
- `alt`, `width`, `height`, `loading` 속성

---

## Example 2: Pain Point Section

### Before (C등급)

```html
<div class="problems">
  <h2>😤 이런 문제가 있으신가요?</h2>
  <div class="problem-card">
    <div class="icon">📊</div>
    <h3>데이터 관리</h3>
    <p>데이터 관리가 어렵습니다.</p>
  </div>
  <div class="problem-card">
    <div class="icon">⏰</div>
    <h3>시간 부족</h3>
    <p>시간이 부족합니다.</p>
  </div>
  <div class="problem-card">
    <div class="icon">💸</div>
    <h3>비용 증가</h3>
    <p>비용이 계속 늘어납니다.</p>
  </div>
</div>
```

**문제점:**
- 이모지 남발 (비전문적, AI slop)
- "데이터 관리가 어렵습니다" → 구체성 0
- `<div>` 남용
- 공감 요소 없음, 정량화 없음
- Pain Point가 너무 일반적

### After (S등급)

```html
<section class="problem" aria-labelledby="problem-heading">
  <div class="container">
    <h2 id="problem-heading" class="section-title">
      이런 문제, 겪고 계시죠?
    </h2>
    <div class="problem-grid">
      <article class="pain-point">
        <h3>매주 반복되는 수작업 보고</h3>
        <p>
          매주 금요일, 팀원 5명의 보고서를 수작업으로 취합하고 계신가요?
          평균 3시간을 보고서 정리에 쓰고 있다면,
          연간 150시간을 낭비하고 있는 겁니다.
        </p>
      </article>
      <article class="pain-point">
        <h3>흩어진 정보, 느린 의사결정</h3>
        <p>
          Slack, 이메일, 스프레드시트에 정보가 분산되어 있으면
          의사결정에 평균 2.5일이 더 걸립니다.
          한곳에서 모든 정보를 볼 수 있다면요?
        </p>
      </article>
      <article class="pain-point">
        <h3>놓치는 이상 신호</h3>
        <p>
          KPI 이상 징후를 발견했을 때는 이미 늦은 경우가 대부분입니다.
          실시간 모니터링 없이는 문제를 사후에야 알게 됩니다.
        </p>
      </article>
    </div>
  </div>
</section>
```

**개선점:**
- 이모지 제거, `<article>` 시맨틱 태그
- 구체적 상황 묘사 ("매주 금요일, 팀원 5명의...")
- 정량화 ("3시간", "150시간", "2.5일")
- 질문형 공감 유도 ("~하고 계신가요?")
- 각 Pain Point가 다른 각도 (시간, 정보, 리스크)

---

## Example 3: FAQ Section

### Before (C등급)

```html
<div class="faq">
  <h2>FAQ</h2>
  <div class="faq-item" onclick="toggleFaq(this)">
    <div class="question">
      <span>Q.</span> TeamFlow는 무엇인가요?
      <span class="arrow">▼</span>
    </div>
    <div class="answer" style="display:none">
      TeamFlow는 혁신적인 팀 협업 도구입니다.
    </div>
  </div>
  <div class="faq-item" onclick="toggleFaq(this)">
    <div class="question">
      <span>Q.</span> 어떤 기능이 있나요?
      <span class="arrow">▼</span>
    </div>
    <div class="answer" style="display:none">
      다양한 기능을 제공합니다.
    </div>
  </div>
</div>

<script>
function toggleFaq(el) {
  const answer = el.querySelector('.answer');
  answer.style.display = answer.style.display === 'none' ? 'block' : 'none';
}
</script>
```

**문제점:**
- JS로 아코디언 구현 → `<details>/<summary>`로 대체 가능
- `onclick` 인라인 핸들러
- `style="display:none"` 인라인 스타일
- "TeamFlow는 무엇인가요?" → 랜딩 페이지에서 불필요한 질문
- "다양한 기능을 제공합니다" → 정보 가치 없음
- 마케팅 질문이 아닌 실제 구매 장벽 질문이어야 함

### After (S등급)

```html
<section class="faq" aria-labelledby="faq-heading">
  <div class="container">
    <h2 id="faq-heading" class="section-title">자주 묻는 질문</h2>
    <div class="faq-list">
      <details>
        <summary>가격은 어떻게 되나요?</summary>
        <p>
          팀 규모와 사용량에 따라 맞춤 견적을 제공합니다.
          기본 플랜은 팀원 1인당 월 15,000원부터 시작하며,
          50인 이상 팀은 별도 할인을 적용합니다.
          <a href="/contact">무료 상담</a>을 통해 정확한 가격을 안내받으실 수 있습니다.
        </p>
      </details>
      <details>
        <summary>기존에 사용하는 도구와 연동이 되나요?</summary>
        <p>
          Slack, Notion, Jira, Google Workspace 등 20개 이상의
          협업 도구와 기본 연동을 지원합니다.
          REST API와 Webhook을 통해 커스텀 연동도 가능합니다.
        </p>
      </details>
      <details>
        <summary>데이터 보안은 어떻게 관리되나요?</summary>
        <p>
          모든 데이터는 AES-256 암호화로 저장되며,
          AWS 서울 리전에서 운영됩니다.
          ISO 27001 인증을 보유하고 있으며,
          연 1회 외부 보안 감사를 받고 있습니다.
        </p>
      </details>
      <details>
        <summary>도입까지 얼마나 걸리나요?</summary>
        <p>
          기본 설정은 30분이면 완료됩니다.
          팀 규모에 따라 전담 매니저가 2주간 온보딩을 지원합니다.
          기존 데이터 마이그레이션도 무료로 도와드립니다.
        </p>
      </details>
      <details>
        <summary>해지는 어떻게 하나요?</summary>
        <p>
          약정이 없으며, 설정에서 언제든 해지할 수 있습니다.
          해지 후에도 30일간 데이터를 보관하며,
          CSV 형식으로 전체 데이터 내보내기가 가능합니다.
        </p>
      </details>
    </div>
  </div>
</section>
```

**개선점:**
- `<details>/<summary>` → JS 없이 네이티브 아코디언
- 실제 구매 장벽 질문 (가격, 연동, 보안, 도입, 해지)
- 구체적 수치 포함 답변 ("15,000원", "20개 이상", "30분")
- 격식체 답변, 행동 유도 링크 포함
- `aria-labelledby`로 접근성 확보

---

## 공통 체크리스트

모든 섹션에서 확인해야 할 항목:

### HTML/접근성
- [ ] `<div>` 대신 시맨틱 태그 (`section`, `article`, `nav`, `header`, `footer`)
- [ ] 모든 `<section>`에 `aria-labelledby` + 대응하는 `<h2>` id
- [ ] 모든 `<img>`에 의미 있는 `alt` 텍스트
- [ ] 모든 링크/버튼에 명확한 텍스트 또는 `aria-label`
- [ ] `outline: none` 사용하지 않음
- [ ] 탭 순서가 논리적 (Tab 키로 이동 가능)

### 스타일
- [ ] CSS 변수 사용 (하드코딩 색상 없음)
- [ ] 모바일 퍼스트 (기본 = 모바일, `min-width` 미디어 쿼리)
- [ ] 다크 모드 대응 (`prefers-color-scheme: dark`)
- [ ] `prefers-reduced-motion` 존중
- [ ] 보라색 그라데이션 없음
- [ ] 이모지 없음

### 카피
- [ ] 헤드라인은 결과/변화 중심 (기능 설명 아님)
- [ ] CTA는 구체적 행동 + 안심 문구
- [ ] "혁신적인", "강력한" 등 모호한 표현 없음
- [ ] 격식체/비격식체 일관성 유지
- [ ] 숫자는 아라비아 숫자
