---
paths:
  - "src/**/*.ts"
  - "src/**/*.tsx"
  - "src/**/*.js"
  - "src/**/*.jsx"
  - "src/**/*.css"
---

# Don'ts

> 일반 작업 discipline(설계 선행 / Surgical / 완료 기준 / 합리화 방지 / 컨텍스트 보호)은 `rules/discipline.md`(글로벌 상시로드)로 분리. 이 파일은 TS/React 특화 don'ts만 담으며 `src/**` 편집 시에만 로드된다.

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
- 폴백 로직 금지 — graceful degradation, backwards-compatibility shim 작성하지 않는다. 실패하면 근본 원인을 수정한다. (예외: 훅의 `|| true`는 비차단 설계이므로 허용)
