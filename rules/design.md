---
paths:
  - "src/**/*.tsx"
  - "src/**/*.jsx"
  - "src/**/*.css"
  - "src/**/*.scss"
  - "src/lib/design-tokens.ts"
  - "tailwind.config.*"
---

# Design System

## 디자인 토큰

- 프로젝트 디자인 토큰은 `src/lib/design-tokens.ts`에 중앙 관리
- TypeScript `as const` 객체로 정의하여 타입 안전성 확보
- `tailwind.config.ts`의 `theme.extend`에서 토큰 파일을 참조하여 확장
- 새 색상/간격/폰트 추가 시 토큰 파일에 먼저 정의, 그 후 컴포넌트에서 사용

## 색상 사용 규칙

- 컴포넌트 파일(`.tsx`/`.jsx`)에서 하드코딩 색상 금지:
  - hex: `#xxx`, `#xxxxxx`, `#xxxxxxxx`
  - 함수: `rgb()`, `rgba()`, `hsl()`, `hsla()`
- 대신 Tailwind CSS 클래스 또는 디자인 토큰 상수 사용
- Tailwind arbitrary value(`bg-[#xxx]`)도 토큰 사용 권장
- 예외: `tailwind.config.ts`, `design-tokens.ts`, `globals.css`의 CSS 변수 정의부

## 공통 컴포넌트

- 동일 UI 패턴이 3회 이상 반복되면 `src/components/common/`으로 추출
- 공통 컴포넌트 후보: 검색/필터 바, 테이블 헤더, 상태 뱃지, 확인 모달, 페이지네이션
- 추출 시 Props 인터페이스 정의, barrel export(`index.ts`) 포함
- `src/components/ui/`는 원자(atom) 수준 — shadcn 기본 컴포넌트
- `src/components/common/`은 조합(molecule) 수준 — 프로젝트 공통 패턴

## 디자인 토큰 파일 구조

```typescript
// src/lib/design-tokens.ts
export const colors = {
  primary: { DEFAULT: '#3B82F6', dark: '#2563EB' },
  tableHeader: '#334155',
  inputBg: '#f3f3f5',
  // ...
} as const;

export const spacing = {
  section: '2rem',
  card: '1.5rem',
  // ...
} as const;

export const typography = {
  heading: { size: '1.5rem', weight: '700' },
  body: { size: '0.875rem', weight: '400' },
  // ...
} as const;

export const borderRadius = {
  card: '0.75rem',
  button: '0.5rem',
  badge: '9999px',
} as const;

export const shadows = {
  card: '0 1px 3px rgba(0,0,0,0.1)',
  dropdown: '0 4px 6px rgba(0,0,0,0.1)',
} as const;
```

## 안티-제네릭 가드레일

AI가 만든 듯한 뻔한 디자인을 방지한다. 모든 디자인 모드(URL/이미지/로컬 파일/자율)에 적용.

### DESIGN.md 연동

프로젝트 루트 `DESIGN.md` 또는 `design-ref/DESIGN.md`가 존재하면 ([VoltAgent/Google Stitch 9섹션 포맷](https://github.com/VoltAgent/awesome-design-md)):

- **§2 Color Palette**: `design-tokens.ts`의 우선 소스로 간주 — 아래 기본 팔레트보다 DESIGN.md §2 값이 우선한다
- **§7 Do's and Don'ts**: 아래 쿠키커터 지표 위에 프로젝트 고유 체크리스트로 추가 로드한다 — tsx/jsx 편집 시 §7 Don'ts 위반을 실시간 점검

### 쿠키커터 지표

아래 패턴 조합이 감지되면 프로젝트 고유성이 부족한 것이다:

| 패턴 | 문제 | 대안 |
| --- | --- | --- |
| `blue-600` Primary + `gray-50` 배경 + `rounded-lg` 카드 | Tailwind 기본 조합 — 어떤 프로젝트인지 알 수 없음 | Phase 0에서 결정한 프로젝트 맥락 기반 색상 사용 |
| Geist/Inter + `text-gray-600` 본문 + `bg-white` 카드 | Next.js 보일러플레이트 그대로 | Phase 0에서 결정한 폰트 페어링 적용 |
| Hero(`text-5xl font-bold`) + 3열 Feature Grid + CTA 버튼 | 범용 랜딩 페이지 템플릿 구조 | 프로젝트 콘텐츠에서 레이아웃 도출 |
| `shadow-sm` 카드 + `divide-y` 리스트 + `rounded-full` 아바타 | SaaS 대시보드 스타터킷 | 의도적인 텍스처/보더/깊이 차별화 |
| `space-y-4` + `max-w-md mx-auto` + `bg-gray-50` 폼 | 인증 페이지 기본 템플릿 | 프로젝트 브랜드가 반영된 인증 경험 |

### 디자인 검증 규칙

1. **스크린샷 테스트**: 완성된 UI에서 로고와 텍스트를 가렸을 때, 어떤 서비스인지 추측 가능해야 한다. 불가능하면 디자인이 충분히 차별화되지 않은 것이다.
2. **3초 규칙**: 처음 방문한 사용자가 3초 안에 "이건 다르다"고 느낄 요소가 최소 1개 있어야 한다 — 색상, 타이포그래피, 레이아웃, 모션 중 하나.
3. **디폴트 세금**: Tailwind/Next.js 기본값(`blue-600`, `Geist`, `rounded-lg`, `shadow-sm`)을 사용할 때마다, 왜 그것이 이 프로젝트에 최적인지 1문장으로 정당화해야 한다. 정당화 없는 사용은 디폴트 의존이다.
