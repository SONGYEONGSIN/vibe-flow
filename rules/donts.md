---
paths:
  - "src/**/*.ts"
  - "src/**/*.tsx"
  - "src/**/*.js"
  - "src/**/*.jsx"
  - "src/**/*.css"
---

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
- 폴백 로직 금지 — graceful degradation, backwards-compatibility shim 작성하지 않는다. 실패하면 근본 원인을 수정한다. (예외: 훅의 `|| true`는 비차단 설계이므로 허용)

## Surgical Change (작업 범위)

- **무관한 dead code 발견 시 언급만 하고 삭제하지 마라** — 별도 PR/이슈로 분리. drive-by 정리는 리뷰 부담만 키운다.
- **본인 변경이 만든 orphan만 정리** — import/변수/함수가 이번 변경으로 미사용이 됐다면 제거. 기존부터 dead였던 것은 건드리지 않는다.
- **인접 코드 "개선" 금지** — 안 깨진 거 리팩토링하지 않는다. 변경된 모든 줄이 사용자 요청에 직접 연결돼야 한다.

## 완료 기준

- 테스트 없이 완료 선언 금지
- 테스트를 구현 코드보다 나중에 작성 금지 (test-last 금지, `rules/tdd.md` 참조)
- 항상 통과하는 테스트 작성 금지 (RED 단계를 거치지 않은 테스트는 무의미)
- TypeScript 에러가 있는 상태로 커밋 금지
- ESLint 경고가 있는 상태로 커밋 금지
- "should work" / "아마 될 거다" 금지 — 실행 결과 증거 필수
- `/verify` 실행 없이 완료 선언 금지
- 에러 발생 시 찍어맞추기(guess-and-check) 금지 (`rules/debugging.md` 참조)

## 합리화 방지

규칙을 회피하기 위한 합리화는 금지한다. 아래 패턴을 인식하고 차단할 것.

| 합리화 | 진실 |
|--------|------|
| "이건 간단한 변경이라 설계 안 해도 됨" | 간단해 보이는 변경이 가장 위험하다. 예외 없음 |
| "테스트 나중에 추가하면 됨" | 나중은 오지 않는다. 지금 작성한다 |
| "시간이 없어서 검증 생략" | 검증 없는 코드는 코드가 아니다 |
| "이전에 비슷한 걸 해봤으니 됨" | 경험은 증거가 아니다. 실행해서 확인한다 |
| "타입 에러인데 기능은 됨" | TypeScript 에러가 있는 코드는 커밋 불가 |
| "리팩토링이라 테스트 안 해도 됨" | 리팩토링이야말로 테스트가 필수다 |
| "설정 파일만 바꿨으니 괜찮음" | 설정 변경이 빌드를 깨뜨린 사례는 수없이 많다 |
| "한 줄만 바꿨는데 뭘" | 한 줄이 프로덕션을 멈출 수 있다 |
| "force push로 지난 커밋 정리할게" | Force push는 협업자 작업을 silently 덮어씌운다. rebase 후에도 `--force-with-lease`만 허용 |
| "이 테스트만 잠깐 skip할게" | `test.skip`/`it.skip`은 GREEN을 가짜로 만든다. 삭제하거나 고친다 |
| "복잡한 타입이라 `as any`/`!` 한 번만" | 타입 단언은 컴파일러 보호를 끈다. `unknown` + 가드 또는 제네릭으로 해결한다 |
| "이 부분은 `@ts-ignore` 빼고 못 짠다" | 못 짜는 게 아니라 설계가 잘못된 것. 타입을 다시 모델링한다 |
| "긴급 핫픽스니 TDD는 다음에" | 일반 버그/이슈는 RED→GREEN 강제. **단 production incident with active customer impact는 예외**: 수정→배포 가능, 다만 **24시간 내 회귀 테스트 + 인시던트 회고 필수** (`rules/tdd.md` 예외 섹션 참조) |
