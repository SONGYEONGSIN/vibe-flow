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
