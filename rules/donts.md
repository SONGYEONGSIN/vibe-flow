# Don'ts

## 코드 품질

- `console.log` 남기지 않기 (디버깅 후 반드시 제거)
- `any` 타입 사용 금지 (`unknown` + 타입 가드 사용)
- `@ts-ignore`, `@ts-expect-error` 사용 금지
- `eslint-disable` 주석 금지 (규칙 자체를 수정하거나 코드를 고칠 것)
- 미사용 import, 변수, 함수 남기지 않기

## 보안

- 하드코딩된 시크릿(API Key, 패스워드, 토큰) 금지
- `NEXT_PUBLIC_` 접두사에 민감한 값 노출 금지

## 패턴

- 직접 DOM 조작 금지 (`document.querySelector` 등 → React ref 사용)
- 직접 객체 뮤테이션 금지 (spread operator로 불변성 유지)
- `useEffect` 내에서 데이터 fetch 금지 (Server Action 또는 Server Component 사용)
- 인라인 스타일 금지 (Tailwind CSS 클래스 사용)
- 컴포넌트에서 하드코딩 색상 금지 (`#xxx`, `rgb()`, `hsl()` → 토큰 또는 Tailwind 사용)

## 완료 기준

- 테스트 없이 완료 선언 금지
- TypeScript 에러가 있는 상태로 커밋 금지
- ESLint 경고가 있는 상태로 커밋 금지
