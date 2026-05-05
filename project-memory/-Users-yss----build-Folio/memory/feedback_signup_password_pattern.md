---
name: SignUp + 비밀번호 강도/일치 + Clock 패턴
description: zod 비밀번호 강도 정규식 + 실시간 인디케이터 + SSR-safe 시계 + useActionState 두 개 패턴
type: feedback
originSessionId: fa4d7468-5d81-4499-b474-305dc529d2ce
---
Folio /login features plan(2026-04-26)에서 signUp + 강도 인디케이터 + Clock 추가 시 발견한 재사용 가능 패턴.

## zod 비밀번호 강도

```ts
z.string()
  .min(8, "...")
  .regex(/[A-Z]/, "영문 대문자를 포함해야 합니다.")
  .regex(/[0-9]/, "숫자를 포함해야 합니다.")
  .regex(/[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]/, "특수문자를 포함해야 합니다.")
```

**Why:** 클라이언트 인디케이터에서 사용한 정규식과 schemas.ts의 zod regex가 동일 source-of-truth는 아니지만(중복) 토씨 일치로 유지. **How to apply:** 비밀번호 정책 변경 시 두 곳 동시 수정 — schemas.ts + page.tsx의 PasswordStrengthIndicator.

## 실시간 인디케이터

useState로 input value 캡처 → 같은 정규식을 클라이언트에서 평가 → ✓/✗ 즉각 표시. zod schema와 단일 source of truth는 아니지만 사용자 즉각 피드백 우선.

dashboard plan에서 input validation 시 동일 패턴 — 정적 zod 검증 + 실시간 클라이언트 인디케이터.

## Clock 컴포넌트 (SSR-safe)

```tsx
const [now, setNow] = useState<Date | null>(null);
useEffect(() => {
  const updateNow = () => setNow(new Date());
  updateNow();
  const id = setInterval(updateNow, 1000);
  return () => clearInterval(id);
}, []);
```

`now: Date | null`로 SSR 시 placeholder, mount 후 실 시간. cleanup 필수. ESLint react-hooks 규칙 회피 위해 helper 함수(`updateNow`)로 추출하면 깔끔.

dashboard의 statusbar / appbar 같은 곳에 시간 표시할 때 재사용.

## useActionState 두 개

같은 페이지에 두 Server Action(signIn / signUp)이 있을 때:
```tsx
const [signInState, signInAction] = useActionState<AuthState, FormData>(signIn, undefined);
const [signUpState, signUpAction] = useActionState<AuthState, FormData>(signUp, undefined);
```

각 form은 자기 action만 호출. mode 전환 시 form unmount → 입력 state는 잃지만 action state는 유지(상위 LoginPage에 있음).

**Why:** 2026-04-26 Folio /login features plan 실행에서 발견. **How to apply:** dashboard에서 다중 Server Action 페이지(예: incident report + comment) 만들 때 재사용.

## e2e selector 함정

TabNav 탭 텍스트("로그인")와 폼 제출 버튼 텍스트("로그인")가 겹치면 `getByRole("button", { name: /로그인/ })`이 ambiguous. **How to apply:** 폼 제출 버튼은 `page.locator('form button[type="submit"]')`로 명시. design-sync.mjs와 e2e/* 모두 이 패턴 사용 중.
