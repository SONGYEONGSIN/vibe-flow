---
name: SSO + remember 14일 + 비밀번호 찾기 패턴
description: Supabase OAuth + cookie maxAge override + reset password 흐름 + /auth/callback route handler
type: feedback
originSessionId: fa4d7468-5d81-4499-b474-305dc529d2ce
---
Folio /login extras plan(2026-04-26)에서 SSO + remember + 비밀번호 찾기 추가 시 발견한 재사용 가능 패턴.

## Cookie maxAge override (이 기기 기억)

Supabase ssr `createServerClient`의 cookies setAll callback에서 maxAge를 정책에 따라 override:

```ts
export async function createClient(options?: { rememberMe?: boolean }) {
  const cookieStore = await cookies();
  return createServerClient(URL, KEY, {
    cookies: {
      getAll() { return cookieStore.getAll(); },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value, options: cookieOptions }) => {
          const finalOptions =
            options?.rememberMe === true
              ? { ...cookieOptions, maxAge: 14 * 24 * 3600 }
              : options?.rememberMe === false
                ? { ...cookieOptions, maxAge: undefined }
                : cookieOptions;
          cookieStore.set(name, value, finalOptions);
        });
      },
    },
  });
}
```

**Why:** "이 기기 기억" 체크박스 동작을 cookie 만료 시간으로 표현. 미체크 = session cookie(브라우저 닫으면 만료).
**How to apply:** 다른 도메인에서도 "이 기기 기억" / "자동 로그인" 정책 만들 때 동일 패턴. `rememberMe` 미지정 시 Supabase 기본 동작 보존하도록 fallback 필수 (middleware, dashboard 등 일반 호출자 호환).

## /auth/callback route handler

OAuth code 교환 + next 파라미터로 redirect 분기. SSO와 비밀번호 reset 두 흐름의 단일 진입점.

```ts
export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";
  const oauthError = searchParams.get("error");

  if (oauthError) return NextResponse.redirect(`${origin}/login?error=oauth_failed`);
  if (!code) return NextResponse.redirect(`${origin}/login?error=missing_code`);

  const supabase = await createClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) return NextResponse.redirect(`${origin}/login?error=exchange_failed`);
  return NextResponse.redirect(`${origin}${next}`);
}
```

**How to apply:** Supabase 다른 OAuth provider(Google, GitHub 등) 추가 시 동일 callback 재사용. middleware의 PUBLIC_PATHS에 `/auth/callback` 등록 필수.

## resetPasswordForEmail enumeration 방지

가입 여부와 무관하게 동일 info 반환:
```ts
await supabase.auth.resetPasswordForEmail(email, { redirectTo });
return { info: "재설정 링크를 발송했습니다. 메일함을 확인해주세요." };
```

미가입 이메일이라도 동일 메시지 — 이메일 enumeration 공격 방지. resetPasswordForEmail 응답을 await 후 그 결과 무시.

**Why:** 보안 베스트 프랙티스. **How to apply:** 비밀번호 reset / 가입 확인 / 계정 검색 등 모든 이메일 input 흐름에 적용.

## SSO 버튼 클라이언트 호출 (Server Action 아님)

OAuth signIn은 클라이언트(브라우저)에서 호출. signInWithOAuth가 브라우저 redirect를 트리거하기 때문.

```tsx
const handleSSO = async () => {
  const { createBrowserClient } = await import("@supabase/ssr");
  const supabase = createBrowserClient(URL, KEY);
  await supabase.auth.signInWithOAuth({
    provider: "azure",
    options: { redirectTo: `${window.location.origin}/auth/callback` },
  });
};
```

**Why:** Server Action에서 호출 시 redirect URL을 server → client로 전달하는 추가 hop 필요. 클라이언트 호출이 더 직관적.
**How to apply:** SSO/OAuth 버튼은 항상 클라이언트 컴포넌트 + onClick handler. dynamic import로 createBrowserClient 호출하면 번들 크기 영향 최소.

## 임시 session 가드 (reset-password 페이지)

`createBrowserClient` + `getUser()`로 마운트 시 session 체크. 이미 로그인된 사용자도 user가 있으니 통과 (의도된 허용).

```tsx
type GuardState = "checking" | "ok" | "no-session";
const [guard, setGuard] = useState<GuardState>("checking");

useEffect(() => {
  const supabase = createBrowserClient(URL, KEY);
  supabase.auth.getUser().then(({ data, error }) => {
    setGuard(error || !data.user ? "no-session" : "ok");
  });
}, []);

if (guard === "checking") return <AuthShell><p>세션 확인 중…</p></AuthShell>;
if (guard === "no-session") return <AuthShell><h2>잘못된 접근입니다</h2>...</AuthShell>;
// guard === "ok" → 폼 렌더
```

**How to apply:** 임시 session 의존 페이지 (이메일 확인, OAuth 재인증 등) 어디서나.

## SearchParams Suspense (Next.js 16)

`useSearchParams`를 LoginPage에서 직접 호출 — Next.js 16 App Router에서 Suspense boundary 자동 처리됨 (별도 wrap 필요 없음). dev/build 둘 다 정상 동작.

```tsx
const searchParams = useSearchParams();
const errorParam = searchParams.get("error");
```

**How to apply:** 페이지 component 안에서 useSearchParams 호출 가능. 단 SSR 페이지 (Server Component)에서는 prop으로 받기.

## TDD 셈플 — 다중 Server Action 검증

`createClient`가 옵션 받는지 검증할 때 mockCreate.toHaveBeenCalledWith({rememberMe: ...}) 패턴:

```ts
mockCreate.mockResolvedValue({
  auth: { signInWithPassword: vi.fn().mockResolvedValue({ error: null }) },
});
const fd = new FormData();
fd.set("email", "a@b.com");
fd.set("password", "right");
fd.set("remember", "on");
await expect(signIn(undefined, fd)).rejects.toThrow("REDIRECT:/dashboard");
expect(mockCreate).toHaveBeenCalledWith({ rememberMe: true });
```

**How to apply:** 인프라(server.ts 등)가 옵션 받는지 검증 시 mockCreate.toHaveBeenCalledWith로 직접 확인. 비동기 redirect도 rejects.toThrow로.
