---
name: web-design-guidelines
description: UI 코드 완성 후 접근성, 성능, UX 규칙 준수 여부를 검사하는 감사 도구. 100+ 규칙 기반으로 file:line 형식의 위반 보고서 생성. "UI 검증", "접근성 검사", "코드 감사", "audit", "review my UI", "check accessibility" 요청 시 사용.
---

# Web Design Guidelines Audit

UI 코드가 웹 표준, 접근성, 성능, UX 규칙을 준수하는지 검증하는 감사 도구.

## 사용법

```bash
# 특정 디렉토리 검사
/web-design-guidelines src/components/

# 특정 파일 검사
/web-design-guidelines src/pages/Home.tsx

# 전체 프론트엔드 검사
/web-design-guidelines
```

## 출력 형식

```
[FAIL] src/components/Button.tsx:23 - 터치 타겟 44px 미만 (현재: 32px)
[FAIL] src/pages/Form.tsx:45 - input에 autocomplete 속성 누락
[WARN] src/components/Modal.tsx:12 - aria-hidden 누락
[PASS] src/components/Card.tsx - 모든 규칙 통과
```

---

## 검사 규칙 (130+)

### 1. 접근성 (Accessibility)

#### 시맨틱 HTML
```
[A01] <div> 클릭 가능 요소 금지 → <button> 또는 <a> 사용
[A02] heading 레벨 건너뛰기 금지 (h1→h3 금지)
[A03] <nav>, <main>, <header>, <footer> 랜드마크 필수
[A04] <ul>/<ol> 없이 리스트 구조 금지
```

> **대표 예시 (A01)**
> Bad: `<div onClick={handleClick}>삭제</div>`
> Good: `<button onClick={handleClick} type="button">삭제</button>`

#### ARIA
```
[A10] aria-label이 visible text 복제하면 금지
[A11] aria-hidden="true"인 요소 내부에 포커스 가능 요소 금지
[A12] role="button"보다 <button> 우선
[A13] aria-live 사용 시 적절한 politeness 확인 (polite/assertive)
[A14] 동적 콘텐츠에 aria-live region 필수
```

> **대표 예시 (A11)**
> Bad: `<div aria-hidden="true"><button>닫기</button></div>`
> Good: `<div aria-hidden="true"><span>장식</span></div>`

#### 키보드 & 포커스
```
[A20] outline: none 또는 outline: 0 금지 (대체 포커스 스타일 없으면)
[A21] tabindex > 0 금지
[A22] 모든 인터랙티브 요소 키보드 접근 가능 확인
[A23] 포커스 트랩 모달에서 Tab 순환 구현 확인
[A24] Skip to main content 링크 권장
```

#### WCAG 2.2 신규 기준 (2023.10 확정)
```
[A25] 포커스 가려짐 금지 — sticky/fixed 요소가 포커스된 요소를 완전히 가리면 FAIL (WCAG 2.4.11)
[A26] 드래그 대안 필수 — 드래그 기능에 클릭/탭 대안 제공 (WCAG 2.5.7)
[A27] 터치 타겟 최소 24x24px — WCAG 공식 기준. 44x44pt는 Apple HIG 권장 (WCAG 2.5.8)
[A28] 일관된 도움말 위치 — 반복되는 도움말 메커니즘 상대적 위치 일관 (WCAG 3.2.6)
[A29] 중복 입력 금지 — 이전에 입력한 정보 재요구 금지, 자동 채움 (WCAG 3.3.7)
[A30] 인지 기능 테스트 인증 금지 — CAPTCHA 대안 필수 (Passkey 등) (WCAG 3.3.8)
```

> **대표 예시 (A25)**
> Bad: sticky header가 포커스된 anchor를 가림
> Good: `scroll-padding-top: var(--header-height)` → `html { scroll-padding-top: 80px }`

#### 이미지 & 미디어
```
[A35] <img>에 alt 필수 (장식용은 alt="")
[A36] 복잡한 이미지에 aria-describedby 권장
[A37] 비디오에 자막(captions) 권장
[A38] 자동 재생 미디어 금지 (muted 예외)
```

> **대표 예시 (A35)**
> Bad: `<img src="/hero.jpg" />`
> Good: `<img src="/hero.jpg" alt="팀원들이 협업하는 모습" />`

---

### 2. 폼 (Forms)

#### 레이블 & 구조
```
[F01] 모든 input에 연결된 <label> 필수 (htmlFor/id 매칭)
[F02] placeholder만으로 레이블 대체 금지
[F03] 필수 필드에 required 또는 aria-required 필수
[F04] 관련 필드 <fieldset> + <legend>로 그룹화
```

> **대표 예시 (F01)**
> Bad: `<input type="text" placeholder="이름" />`
> Good: `<label htmlFor="name">이름</label><input id="name" type="text" />`

#### 입력 타입 & 속성
```
[F10] 이메일 필드: type="email" 필수
[F11] 전화번호: type="tel" + inputmode="tel"
[F12] 숫자: type="number" 또는 inputmode="numeric"
[F13] 비밀번호: autocomplete="current-password" 또는 "new-password"
[F14] 주소: autocomplete="street-address", "postal-code" 등
[F15] 이름: autocomplete="name", "given-name", "family-name"
```

#### 검증 & 에러
```
[F20] 클라이언트 유효성 검사 + 서버 검증 병행
[F21] 에러 메시지는 필드 근처에 표시
[F22] aria-invalid="true" + aria-describedby로 에러 연결
[F23] 실시간 유효성 검사는 blur 이벤트 후 실행
[F24] onPaste 방지 금지 (사용자 편의 저해)
```

---

### 3. 애니메이션 & 모션

```
[M01] prefers-reduced-motion 미디어쿼리 필수
[M02] transition: all 금지 → 명시적 속성만 (opacity, transform 등)
[M03] animation-duration 5초 초과 금지 (로딩 제외)
[M04] 무한 반복 애니메이션에 정지 컨트롤 제공
[M05] 깜빡임(flash) 3Hz 이상 금지 (발작 위험)
```

> **대표 예시 (M01)**
> Bad: `transition: all 0.3s ease`
> Good: `@media (prefers-reduced-motion: reduce) { * { animation: none; transition: none; } }`

---

### 4. 색상 & 테마

```
[C01] 텍스트 대비 4.5:1 이상 (WCAG AA)
[C02] 대형 텍스트(18px+ bold, 24px+) 대비 3:1 이상
[C03] 색상만으로 정보 전달 금지 (아이콘/텍스트 병행)
[C04] color-scheme: light dark 메타 태그 권장
[C05] <meta name="theme-color"> 다크모드용 media 속성 확인
[C06] prefers-color-scheme 미디어쿼리 지원 확인
```

#### 다크모드 검증
```
[C07] 다크모드 대비 검증 — 다크 배경에서도 텍스트 대비 4.5:1 확인
[C08] color-scheme CSS 속성 필수 — :root { color-scheme: light dark }
[C09] 다크모드 그림자 가시성 — 어두운 배경에서 box-shadow 대신 border 고려
[C10] 이미지/SVG 다크모드 — 밝은 로고가 다크배경에서 안 보이는 문제 확인
[C11] 시스템 테마 연동 — prefers-color-scheme 감지 + 수동 토글 모두 지원
```

> **대표 예시 (C08)**
> Bad: CSS 변수 선언에 color-scheme 없음
> Good: `:root { color-scheme: light dark; --bg: white; } @media (prefers-color-scheme: dark) { :root { --bg: #0a0a0a; } }`

---

### 5. 성능 (Performance)

#### 레이아웃 & 렌더링
```
[P01] 100+ 항목 리스트에 virtualization 권장
[P02] layout thrashing 패턴 탐지 (offsetHeight 연속 읽기/쓰기)
[P03] will-change 과용 금지 (필요한 요소에만)
[P04] transform/opacity 외 속성 애니메이션 주의
```

#### 폰트 & 이미지
```
[P10] font-display: swap 또는 optional 필수
[P11] 웹폰트 preload 권장
[P12] 이미지 width/height 명시 (CLS 방지)
[P13] loading="lazy" 뷰포트 밖 이미지에 권장
[P14] next/image 사용 시 sizes 속성 확인
```

#### 네트워크
```
[P20] 외부 도메인 preconnect 권장
[P21] 중요 리소스 preload 확인
[P22] 불필요한 동기 스크립트 경고
```

#### Core Web Vitals & 번들
```
[P23] INP 최적화 — 이벤트 핸들러 내 무거운 동기 작업 감지 (INP < 200ms 목표)
[P24] 번들 임포트 — barrel file(index.ts) 재수출 감지, 직접 임포트 권장
[P25] dynamic import — 뷰포트 밖 무거운 컴포넌트에 next/dynamic 미사용 WARN
[P26] React re-render — 인라인 객체/함수 props 패턴 감지 (매 렌더마다 새 참조)
```

> **대표 예시 (P24)**
> Bad: `import { Button } from '@/components'` (barrel)
> Good: `import { Button } from '@/components/Button'` (직접 임포트)

---

### 6. URL & 상태 관리

```
[U01] 필터/정렬 상태 URL 파라미터 반영 권장
[U02] 페이지네이션 URL 반영 필수 (?page=2)
[U03] 탭/모달 상태 URL hash 또는 파라미터 고려
[U04] 뒤로가기 시 상태 유지 확인
[U05] 딥링킹 지원 확인 (공유 가능한 URL)
```

> **대표 예시 (U02)**
> Bad: `const [page, setPage] = useState(1)` (URL 미반영)
> Good: `const page = Number(searchParams.get('page') ?? '1')`

---

### 7. 국제화 (i18n)

```
[I01] 날짜: Intl.DateTimeFormat 또는 date-fns 사용
[I02] 숫자/통화: Intl.NumberFormat 사용
[I03] 하드코딩된 날짜 포맷 (MM/DD/YYYY) 금지
[I04] RTL 레이어 지원 고려 (margin-inline-start 등)
[I05] lang 속성 <html>에 설정 확인
```

> **대표 예시 (I01)**
> Bad: `new Date().toLocaleDateString()` (로케일 미지정)
> Good: `new Intl.DateTimeFormat('ko-KR', { dateStyle: 'long' }).format(date)`

---

### 8. React/Next.js 특화

#### Hydration Safety
```
[R01] Date, Math.random() 등 서버/클라이언트 불일치 주의
[R02] useEffect 내에서만 브라우저 API 접근
[R03] suppressHydrationWarning 남용 금지
[R04] value와 onChange 항상 페어링 (controlled input)
[R05] defaultValue와 value 혼용 금지
```

#### 컴포넌트 패턴
```
[R10] key prop에 index 사용 주의 (동적 리스트)
[R11] useEffect 의존성 배열 완전성 확인
[R12] 이벤트 핸들러 인라인 함수 과용 주의
[R13] forwardRef 필요한 컴포넌트 확인
```

#### React Server Components (RSC) 경계
```
[R14] 불필요한 "use client" — 상태/이벤트 없는 컴포넌트의 use client 선언 WARN
[R15] Server Component 내 브라우저 API — window, document, localStorage 직접 접근 FAIL
[R16] Client 경계 직렬화 — Server→Client props에 함수, Date, Map 등 비직렬화 타입 FAIL
[R17] Server Actions 보안 — 'use server' 함수 내 인증/인가 검증 확인 WARN
[R18] after() API 활용 — 비차단 작업(로깅, 분석)에 after() 사용 권장 INFO
```

> **대표 예시 (R14)**
> Bad: `'use client'; export function StaticCard() { return <div>...</div> }`
> Good: Server Component로 유지 (useState/useEffect 없으면 불필요)

---

### 9. 안티패턴 (Anti-patterns)

```
[X01] user-scalable=no 금지 (접근성 위반)
[X02] maximum-scale=1 금지
[X03] -webkit-tap-highlight-color: transparent 주의
[X04] touch-action: none 전역 적용 금지
[X05] * { box-sizing } 이외 전역 * 선택자 주의
[X06] !important 과용 경고
[X07] z-index 9999+ 경고
```

> **대표 예시 (X01)**
> Bad: `<meta name="viewport" content="width=device-width, user-scalable=no">`
> Good: `<meta name="viewport" content="width=device-width, initial-scale=1">`

---

### 10. 콘텐츠 & 카피

```
[T01] 버튼/링크 텍스트 구체적으로 ("여기 클릭" 금지)
[T02] 에러 메시지 해결책 포함 권장
[T03] 빈 상태(empty state) UI 제공 확인
[T04] 긴 텍스트 truncation 시 title 또는 tooltip 제공
```

> **대표 예시 (T01)**
> Bad: `<button>클릭</button>`, `<a href="...">여기</a>`
> Good: `<button>결제 완료하기</button>`, `<a href="/pricing">요금제 보기</a>`

---

### 11. Tailwind CSS

```
[TW01] arbitrary value 감지 — text-[13px], p-[7px] 등 테마 토큰 대체 가능 시 WARN
[TW02] 모순 클래스 감지 — p-2 p-3, text-sm text-lg 같은 충돌 FAIL
[TW03] @theme 토큰 미사용 — 하드코딩 색상(bg-[#1a1a2e]) 대신 의미론적 토큰 사용 WARN
[TW04] dark: variant 누락 — 색상 관련 클래스에 dark: 대응 없으면 WARN
[TW05] outline-none 사용 시 focus-visible 대체 필수 — ring 또는 커스텀 포커스
[TW06] Tailwind className 길이 — 10개+ 유틸리티는 cva 또는 @apply 추출 권장 INFO
[TW07] 반응형 접두사 순서 — sm: → md: → lg: 순서 일관성 INFO
[TW08] container query 활용 — 컴포넌트 내부 반응형은 @container 고려 INFO
```

> **대표 예시 (TW04)**
> Bad: `<div className="bg-white text-gray-900">...</div>`
> Good: `<div className="bg-white text-gray-900 dark:bg-gray-950 dark:text-gray-100">...</div>`

---

## 검사 실행 프로세스

### Phase 1: 파일 스캔
```
1. 대상 디렉토리/파일 식별
2. .tsx, .jsx, .ts, .js, .css, .scss 파일 수집
3. node_modules, .next, dist 제외
```

### Phase 2: 규칙 검사
```
1. 각 파일에 대해 130+ 규칙 순차 적용
2. AST 기반 코드 분석 (가능한 경우)
3. 정규식 패턴 매칭 (간단한 규칙)
```

### Phase 3: 보고서 생성

#### 요약 대시보드 (필수 출력)

| 카테고리 | FAIL | WARN | INFO | 점수 |
|----------|:----:|:----:|:----:|:----:|
| 접근성 (A) | 2 | 3 | 1 | 78% |
| 폼 (F) | 0 | 1 | 0 | 95% |
| 애니메이션 (M) | 1 | 0 | 0 | 80% |
| 색상/테마 (C) | 0 | 2 | 0 | 90% |
| 성능 (P) | 1 | 3 | 1 | 75% |
| URL (U) | 0 | 1 | 0 | 90% |
| i18n (I) | 0 | 0 | 1 | 100% |
| React/Next.js (R) | 1 | 2 | 1 | 80% |
| 안티패턴 (X) | 0 | 1 | 0 | 95% |
| 콘텐츠 (T) | 0 | 1 | 0 | 90% |
| Tailwind (TW) | 1 | 4 | 2 | 72% |
| **총합** | **6** | **18** | **6** | **83%** |

점수 산출: (PASS + WARN×0.5) / 총 적용 규칙 수 × 100
- FAIL = 0점, WARN = 0.5점, PASS = 1점

```
1. 위반 사항 file:line 형식으로 수집
2. 심각도별 분류 (FAIL/WARN/INFO)
3. 수정 제안 포함
```

---

## 심각도 레벨

| 레벨 | 설명 | 예시 |
|------|------|------|
| **FAIL** | 즉시 수정 필요 (접근성/보안) | alt 누락, outline:none |
| **WARN** | 권장 수정 (UX/성능) | autocomplete 누락, virtualization 미적용 |
| **INFO** | 개선 고려 | preconnect 추가 권장 |

---

## 자동 수정 제안

검사 결과에 수정 코드 예시 포함:

```
[FAIL] src/components/Button.tsx:23
  위반: 터치 타겟 44px 미만
  현재: className="p-2" (32px)
  수정: className="p-3" (48px) 또는 min-h-[44px] min-w-[44px]

[FAIL] src/pages/Form.tsx:45
  위반: input에 autocomplete 누락
  현재: <input type="email" />
  수정: <input type="email" autocomplete="email" />
```

---

## design-master와의 관계

| 스킬 | 역할 | 사용 시점 |
|------|------|----------|
| **design-master** | 창작 가이드 | UI 생성 시 자동 적용 |
| **web-design-guidelines** | 검증 도구 | 완성 후 수동 호출 |

```
[개발 워크플로우]
1. UI 생성 → design-master 규칙 따름
2. 코드 완성 → /web-design-guidelines 실행
3. 위반 수정 → 재검사
4. 모든 규칙 통과 → 배포 준비 완료
```

---

## Troubleshooting

| 문제 | 원인 | 해결 |
|------|------|------|
| 규칙 위반이 너무 많음 (50+) | 프로젝트 초기 상태 | 점진적 도입: Critical → Major → Minor |
| outline:none 감지 안됨 | CSS-in-JS, Tailwind outline-none | className 패턴 매칭 확장 |
| 색상 대비 판정 모호 | 동적 배경색/그라데이션 | 수동 검증 + axe-core 도구 병행 |
| ARIA 규칙 과탐 | 네이티브 HTML이면 ARIA 불필요 | 네이티브 요소 우선 확인 |
| 동적 콘텐츠 감사 누락 | 정적 분석 한계 | E2E 접근성 테스트 병행 |
| 자동 수정 후 UI 깨짐 | 맥락 없는 기계적 수정 | 수정 전후 시각적 검증 |

## Anti-patterns

| 패턴 | 문제 | 대안 |
|------|------|------|
| aria-label 남발 | 네이티브 텍스트로 충분할 때 불필요 | 시맨틱 HTML 우선 |
| role="button" on div | 키보드 접근성 직접 구현 필요 | `<button>` 사용 |
| tabIndex 양수 사용 | DOM 순서와 탭 순서 불일치 | tabIndex={0} 또는 -1만 사용 |
| user-scalable=no | 시각 장애인 줌 차단 | viewport에서 제거 |
| 색상만으로 상태 표시 | 색맹 사용자 인식 불가 | 아이콘/텍스트 병행 |

## References

| 문서 | 경로 | 내용 |
|------|------|------|
| 감사 자동화 | `references/audit-automation.md` | Bash 스크립트, CI 통합, ESLint flat config |
| WCAG 레퍼런스 | `references/wcag-quick-reference.md` | WCAG 2.1 + 2.2 AA 전체, ARIA 패턴, 테스트 도구 |
| 실행 스크립트 | `scripts/audit.sh` | 즉시 실행 가능 통합 감사 스크립트 |
