# WCAG 2.1 AA Quick Reference

웹 콘텐츠 접근성 지침(WCAG) 2.1 Level AA 핵심 요약. 코드 예시 포함.

---

## 1. 인식의 용이성 (Perceivable)

### 1.1 대체 텍스트

**모든 비텍스트 콘텐츠에 대체 텍스트 제공**

```tsx
// Good: 의미 있는 이미지
<Image src="/hero.jpg" alt="팀원들이 회의실에서 브레인스토밍 중" width={800} height={400} />

// Good: 장식용 이미지
<Image src="/divider.svg" alt="" aria-hidden="true" width={100} height={2} />

// Good: 복잡한 차트
<figure>
  <Image src="/chart.png" alt="2025년 매출 추이" width={600} height={300} />
  <figcaption>
    2025년 1월~12월 매출: 1월 1,200만원에서 12월 3,400만원으로 183% 성장
  </figcaption>
</figure>

// Bad
<img src="/photo.jpg" />                    // alt 없음
<img src="/icon.svg" alt="icon" />          // 의미 없는 alt
<img src="/photo.jpg" alt="image.jpg" />    // 파일명 반복
```

### 1.2 시간 기반 미디어

```tsx
// 비디오: 자막 필수
<video controls>
  <source src="/demo.mp4" type="video/mp4" />
  <track kind="captions" src="/demo.vtt" srcLang="ko" label="한국어" default />
</video>

// 자동 재생 금지 (muted 예외)
<video autoPlay muted playsInline /> // 허용 (음소거)
<video autoPlay />                   // 금지 (소리 있음)
```

### 1.3 적응 가능

**정보와 구조를 다양한 방식으로 표현 가능하게**

```tsx
// Good: 시맨틱 구조
<main>
  <article>
    <h1>기사 제목</h1>
    <p>본문...</p>
    <aside aria-label="관련 정보">
      <h2>참고 사항</h2>
    </aside>
  </article>
</main>

// Good: 테이블 구조
<table>
  <caption>월별 매출 현황</caption>
  <thead>
    <tr>
      <th scope="col">월</th>
      <th scope="col">매출</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1월</td>
      <td>1,200만원</td>
    </tr>
  </tbody>
</table>

// Good: 입력 목적 식별
<input type="email" autoComplete="email" />
<input type="tel" autoComplete="tel" inputMode="tel" />
<input type="text" autoComplete="name" />
```

### 1.4 구분 가능

**콘텐츠를 보고 듣기 쉽게**

#### 색상 대비

```css
/* Good: 4.5:1 이상 대비 */
.text-primary {
  color: #1a1a2e;              /* 진한 네이비 */
  background-color: #ffffff;    /* 4.5:1 이상 */
}

/* Good: 대형 텍스트 3:1 이상 */
.heading-large {
  font-size: 24px;
  color: #555555;               /* 대형 텍스트는 3:1 이상 */
}

/* Bad: 대비 부족 */
.low-contrast {
  color: #999999;
  background-color: #ffffff;    /* 2.8:1 → 미달 */
}
```

#### 텍스트 크기 조절

```css
/* Good: 200% 확대해도 콘텐츠 손실 없음 */
body {
  font-size: 1rem;              /* 상대 단위 */
  line-height: 1.5;
}

.container {
  max-width: 80ch;              /* 문자 기반 너비 */
  padding: 1rem;
}

/* Bad: 고정 크기 */
body {
  font-size: 14px;              /* 절대 단위 → 확대 불가 */
  overflow: hidden;             /* 스크롤 차단 → 콘텐츠 손실 */
}
```

#### 색상만으로 정보 전달 금지

```tsx
// Good: 색상 + 아이콘 + 텍스트
<div className="flex items-center gap-2 text-red-600">
  <AlertCircle className="h-4 w-4" aria-hidden="true" />
  <span>오류: 이메일 형식이 올바르지 않습니다</span>
</div>

// Bad: 색상만 사용
<span className="text-red-600">이메일 형식이 올바르지 않습니다</span>
```

---

## 2. 운용의 용이성 (Operable)

### 2.1 키보드 접근성

```tsx
// Good: 모든 기능 키보드 사용 가능
<button onClick={handleClick}>제출</button>

// Good: 키보드 이벤트 처리
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      handleClick();
    }
  }}
>
  커스텀 버튼
</div>

// Bad: 키보드 접근 불가
<div onClick={handleClick}>클릭 전용</div>

// Good: 포커스 트랩 (모달)
function Modal({ isOpen, onClose, children }) {
  const modalRef = useRef(null);

  useEffect(() => {
    if (!isOpen) return;

    const focusable = modalRef.current?.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const first = focusable?.[0];
    const last = focusable?.[focusable.length - 1];

    function handleTab(e) {
      if (e.key !== 'Tab') return;
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last?.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first?.focus();
      }
    }

    first?.focus();
    document.addEventListener('keydown', handleTab);
    return () => document.removeEventListener('keydown', handleTab);
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div role="dialog" aria-modal="true" ref={modalRef}>
      {children}
      <button onClick={onClose}>닫기</button>
    </div>
  );
}
```

### 2.2 충분한 시간

```tsx
// Good: 세션 만료 경고
function SessionTimeout() {
  const [timeLeft, setTimeLeft] = useState(300); // 5분

  return (
    <div role="alert" aria-live="assertive">
      <p>세션이 {Math.floor(timeLeft / 60)}분 후 만료됩니다.</p>
      <button onClick={extendSession}>세션 연장</button>
    </div>
  );
}

// Good: 자동 슬라이드 정지 가능
<Carousel autoPlay pauseOnHover>
  <button aria-label="자동 재생 정지" onClick={pause}>⏸</button>
</Carousel>
```

### 2.3 발작 및 신체 반응

```css
/* Good: 깜빡임 3Hz 이하 */
@keyframes gentle-pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}

.notification {
  animation: gentle-pulse 2s ease-in-out; /* 0.5Hz → 안전 */
}

/* Bad: 빠른 깜빡임 */
@keyframes flash {
  0%, 100% { opacity: 1; }
  50% { opacity: 0; }
}

.alert {
  animation: flash 0.2s infinite; /* 5Hz → 위험! */
}
```

### 2.4 탐색 가능

```tsx
// Good: 건너뛰기 링크
<a href="#main-content" className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:bg-white focus:px-4 focus:py-2">
  본문으로 건너뛰기
</a>

// Good: 페이지 제목
export const metadata = {
  title: '가격 정책 | MyService',  // 페이지별 고유 제목
};

// Good: 포커스 순서 (자연스러운 DOM 순서)
<header>
  <nav aria-label="메인 메뉴">...</nav>
</header>
<main id="main-content">
  <h1>...</h1>
  <form>...</form>
</main>
<footer>...</footer>

// Good: 링크 목적 명확
<a href="/pricing">가격 정책 보기</a>        // 목적 명확
<a href="/docs" aria-label="API 문서 보기 (새 탭에서 열림)" target="_blank" rel="noopener">
  API 문서
</a>

// Bad: 목적 불분명
<a href="/page">여기</a>
<a href="/page">클릭</a>
<a href="/page">더 보기</a>
```

### 2.5 입력 방식

```tsx
// Good: 터치 타겟 최소 44x44px
<button className="min-h-[44px] min-w-[44px] p-3">
  제출
</button>

// Good: 제스처 대안 제공
<div
  onTouchStart={handleSwipeStart}
  onTouchEnd={handleSwipeEnd}
>
  {/* 스와이프 + 버튼 대안 */}
  <button onClick={prev} aria-label="이전">←</button>
  <button onClick={next} aria-label="다음">→</button>
</div>
```

---

## 3. 이해의 용이성 (Understandable)

### 3.1 가독성

```tsx
// Good: 언어 지정
<html lang="ko">

// Good: 부분적 다른 언어
<p>이 기능은 <span lang="en">Machine Learning</span>을 활용합니다.</p>
```

### 3.2 예측 가능

```tsx
// Good: 포커스/입력 시 예기치 않은 변경 없음
<select
  onChange={(e) => setFilter(e.target.value)}
  // 선택만으로 페이지 이동하지 않음
>
  <option value="all">전체</option>
  <option value="active">활성</option>
</select>

// Bad: 입력만으로 페이지 이동
<select onChange={(e) => router.push(`/filter/${e.target.value}`)}>
  ...
</select>
```

### 3.3 입력 지원

```tsx
// Good: 에러 식별 + 수정 제안
<div>
  <label htmlFor="email">이메일</label>
  <input
    id="email"
    type="email"
    aria-invalid={!!error}
    aria-describedby={error ? 'email-error' : undefined}
  />
  {error && (
    <p id="email-error" role="alert" className="text-red-600">
      올바른 이메일 형식을 입력하세요 (예: name@example.com)
    </p>
  )}
</div>

// Good: 필수 필드 명시
<label htmlFor="name">
  이름 <span aria-hidden="true">*</span>
  <span className="sr-only">(필수)</span>
</label>
<input id="name" required aria-required="true" />
```

---

## 4. 견고성 (Robust)

### 4.1 호환성

```tsx
// Good: 유효한 HTML
<button type="button">닫기</button>

// Good: 이름, 역할, 값
<input
  type="text"
  id="search"
  role="searchbox"
  aria-label="사이트 검색"
  value={query}
  onChange={(e) => setQuery(e.target.value)}
/>

// Good: 상태 메시지
<div aria-live="polite" aria-atomic="true">
  {results.length}개의 결과를 찾았습니다
</div>

// Bad: 잘못된 ARIA
<div role="button">...</div>          // tabIndex 없음
<div aria-expanded="true">...</div>   // role 없음
<input aria-label="이름" />
<label htmlFor="name">이름</label>    // aria-label과 label 중복
```

---

## ARIA 패턴 레퍼런스

### 탭 패널

```tsx
function Tabs({ items }) {
  const [active, setActive] = useState(0);

  return (
    <div>
      <div role="tablist" aria-label="설정 탭">
        {items.map((item, i) => (
          <button
            key={i}
            role="tab"
            aria-selected={active === i}
            aria-controls={`panel-${i}`}
            id={`tab-${i}`}
            tabIndex={active === i ? 0 : -1}
            onClick={() => setActive(i)}
          >
            {item.label}
          </button>
        ))}
      </div>
      {items.map((item, i) => (
        <div
          key={i}
          role="tabpanel"
          id={`panel-${i}`}
          aria-labelledby={`tab-${i}`}
          hidden={active !== i}
        >
          {item.content}
        </div>
      ))}
    </div>
  );
}
```

### 아코디언

```tsx
function Accordion({ items }) {
  const [open, setOpen] = useState<number | null>(null);

  return (
    <div>
      {items.map((item, i) => (
        <div key={i}>
          <h3>
            <button
              aria-expanded={open === i}
              aria-controls={`content-${i}`}
              onClick={() => setOpen(open === i ? null : i)}
            >
              {item.title}
            </button>
          </h3>
          <div
            id={`content-${i}`}
            role="region"
            aria-labelledby={`heading-${i}`}
            hidden={open !== i}
          >
            {item.content}
          </div>
        </div>
      ))}
    </div>
  );
}
```

### Toast/알림

```tsx
function ToastContainer() {
  return (
    <div
      aria-live="polite"
      aria-atomic="false"
      className="fixed bottom-4 right-4 z-50"
    >
      {toasts.map((toast) => (
        <div
          key={toast.id}
          role="status"
          className="rounded-lg bg-white p-4 shadow-lg"
        >
          <p>{toast.message}</p>
          <button
            onClick={() => dismiss(toast.id)}
            aria-label="알림 닫기"
          >
            닫기
          </button>
        </div>
      ))}
    </div>
  );
}
```

---

## 테스트 도구

| 도구 | 용도 | 자동화 수준 |
|------|------|:----------:|
| axe DevTools | 브라우저 확장 | 수동 |
| @axe-core/playwright | E2E 접근성 | 자동 |
| Lighthouse | 종합 점검 | 반자동 |
| WAVE | 시각적 분석 | 수동 |
| NVDA/VoiceOver | 스크린리더 테스트 | 수동 |
| Colour Contrast Checker | 대비 검증 | 수동 |

---

## 체크리스트 요약

| # | 항목 | WCAG 기준 | 우선순위 |
|---|------|-----------|:--------:|
| 1 | 이미지 alt 텍스트 | 1.1.1 | CRITICAL |
| 2 | 색상 대비 4.5:1 | 1.4.3 | CRITICAL |
| 3 | 키보드 접근 가능 | 2.1.1 | CRITICAL |
| 4 | 포커스 표시 | 2.4.7 | CRITICAL |
| 5 | 폼 label 연결 | 1.3.1 | HIGH |
| 6 | 에러 메시지 명확 | 3.3.1 | HIGH |
| 7 | 시맨틱 HTML | 1.3.1 | HIGH |
| 8 | 페이지 제목 고유 | 2.4.2 | MEDIUM |
| 9 | 링크 목적 명확 | 2.4.4 | MEDIUM |
| 10 | 모션 제어 | 2.3.3 | MEDIUM |

---

## WCAG 2.2 신규 기준 (2023.10 확정, AA 준수 필수)

### 목차
- [2.4.11 Focus Not Obscured](#2411-focus-not-obscured)
- [2.5.7 Dragging Movements](#257-dragging-movements)
- [2.5.8 Target Size Minimum](#258-target-size-minimum)
- [3.2.6 Consistent Help](#326-consistent-help)
- [3.3.7 Redundant Entry](#337-redundant-entry)
- [3.3.8 Accessible Authentication](#338-accessible-authentication)

---

### 2.4.11 Focus Not Obscured (AA)

**기준**: 키보드 포커스된 컴포넌트가 다른 콘텐츠에 의해 완전히 가려지지 않아야 함.

**흔한 위반 패턴**: sticky header/footer가 포커스 이동 시 해당 요소를 가림.

```css
/* Good: scroll-padding으로 sticky header 높이 확보 */
html {
  scroll-padding-top: 80px; /* header 높이와 일치 */
}

/* sticky header가 있는 레이아웃 */
header {
  position: sticky;
  top: 0;
  height: 80px;
  z-index: 100;
}
```

```tsx
// Good: IntersectionObserver로 포커스 가시성 확인
function useEnsureFocusVisible(headerHeight: number) {
  useEffect(() => {
    function handleFocus(e: FocusEvent) {
      const el = e.target as HTMLElement;
      const rect = el.getBoundingClientRect();
      if (rect.top < headerHeight) {
        window.scrollBy({ top: rect.top - headerHeight - 8, behavior: 'smooth' });
      }
    }
    document.addEventListener('focusin', handleFocus);
    return () => document.removeEventListener('focusin', handleFocus);
  }, [headerHeight]);
}
```

---

### 2.5.7 Dragging Movements (A)

**기준**: 드래그로 수행하는 모든 기능에 드래그 없이 수행할 수 있는 단일 포인터 대안 제공.

**적용 대상**: 칸반 보드, 슬라이더, 정렬 가능한 리스트, 분할 패널 등.

```tsx
// Good: dnd-kit + 키보드 대안 버튼
import { useSortable } from '@dnd-kit/sortable';

function SortableItem({ id, title, onMoveUp, onMoveDown, isFirst, isLast }) {
  const { attributes, listeners, setNodeRef, transform } = useSortable({ id });

  return (
    <div ref={setNodeRef} {...attributes}>
      {/* 드래그 핸들 */}
      <button {...listeners} aria-label={`${title} 드래그하여 순서 변경`}>
        ⠿
      </button>

      <span>{title}</span>

      {/* 키보드/클릭 대안 — WCAG 2.5.7 필수 */}
      <div role="group" aria-label="순서 변경">
        <button
          onClick={onMoveUp}
          disabled={isFirst}
          aria-label={`${title}을 위로 이동`}
        >
          ↑
        </button>
        <button
          onClick={onMoveDown}
          disabled={isLast}
          aria-label={`${title}을 아래로 이동`}
        >
          ↓
        </button>
      </div>
    </div>
  );
}
```

---

### 2.5.8 Target Size Minimum (AA)

**기준**: 포인터 입력의 타겟 크기 최소 24×24 CSS 픽셀.

> **주의**: WCAG 2.5.8(24×24px)과 Apple HIG(44×44pt), Android HIG(48×48dp)는 다른 기준.
> 프로덕션에서는 44px+ 권장, WCAG 법적 기준은 24px.

```css
/* WCAG 최소 기준 */
.interactive-min {
  min-width: 24px;
  min-height: 24px;
}

/* 권장 기준 (Apple HIG 기반) */
.interactive-recommended {
  min-width: 44px;
  min-height: 44px;
}

/* 아이콘 버튼: 시각적 크기는 작게, 터치 영역은 크게 */
.icon-button {
  position: relative;
  width: 16px;
  height: 16px;
}
.icon-button::before {
  content: '';
  position: absolute;
  inset: -14px; /* 44px 터치 영역 */
}
```

```tsx
// Good: Tailwind로 최소 터치 타겟 보장
<button className="min-h-[44px] min-w-[44px] flex items-center justify-center">
  <CloseIcon className="h-4 w-4" />
</button>
```

---

### 3.2.6 Consistent Help (A)

**기준**: 여러 페이지에서 도움말 메커니즘이 제공되면 각 페이지에서 동일한 상대적 위치에 있어야 함.

```tsx
// Good: 전역 레이아웃에서 도움말 위치 고정
export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <header>
        <nav>
          {/* 도움말 링크는 항상 nav 마지막에 위치 */}
          <a href="/help">도움말</a>
          <a href="/contact">문의하기</a>
        </nav>
      </header>
      <main>{children}</main>
      <footer>
        {/* 또는 footer에 고정 — 페이지마다 일관 */}
        <a href="/help">고객센터</a>
        <a href="tel:1588-0000">전화 문의</a>
      </footer>
    </>
  );
}

// Good: 고정 FAB (Floating Action Button) — 위치 고정으로 일관성 충족
function HelpFAB() {
  return (
    <button
      className="fixed bottom-6 right-6 z-50 rounded-full bg-blue-600 p-4 shadow-lg"
      aria-label="도움말 열기"
    >
      ?
    </button>
  );
}
```

---

### 3.3.7 Redundant Entry (A)

**기준**: 동일한 프로세스에서 이전에 입력한 정보를 다시 입력하도록 요구하지 않아야 함.

```tsx
// Good: 이전 단계 입력값 자동 채움
function CheckoutStep2({ previousData }: { previousData: ShippingData }) {
  const [billingData, setBillingData] = useState(previousData);

  return (
    <form>
      <h2>결제 정보</h2>

      {/* 배송지 = 청구지 체크박스 */}
      <label>
        <input
          type="checkbox"
          onChange={(e) => {
            if (e.target.checked) {
              setBillingData(previousData); // 이전 입력값 자동 채움
            }
          }}
        />
        배송지와 동일
      </label>

      <input
        name="name"
        defaultValue={billingData.name}
        autoComplete="billing name"
      />
      <input
        name="address"
        defaultValue={billingData.address}
        autoComplete="billing street-address"
      />
    </form>
  );
}
```

---

### 3.3.8 Accessible Authentication (AA)

**기준**: 인증 과정에서 인지 기능 테스트(CAPTCHA, 퍼즐, 암호 기억 등)를 요구하지 않거나 대안을 제공해야 함.

```tsx
// Bad: 인지 기능 테스트만 있는 인증
<form>
  <input type="text" placeholder="CAPTCHA 입력" />
  <img src="/captcha.png" alt="CAPTCHA" /> {/* 대안 없음 */}
</form>

// Good: Passkey / 매직링크 대안 제공
function AuthOptions() {
  return (
    <div>
      {/* 1순위: Passkey (인지 기능 테스트 없음) */}
      <button onClick={signInWithPasskey}>
        Passkey로 로그인
      </button>

      {/* 2순위: 이메일 매직링크 */}
      <button onClick={sendMagicLink}>
        이메일로 로그인 링크 받기
      </button>

      {/* 3순위: OAuth */}
      <button onClick={signInWithGoogle}>
        Google로 로그인
      </button>

      {/* 비밀번호 사용 시: 복사-붙여넣기 허용 필수 */}
      <input
        type="password"
        autoComplete="current-password"
        // onPaste 차단 금지 — WCAG 3.3.8 위반
      />
    </div>
  );
}
```
