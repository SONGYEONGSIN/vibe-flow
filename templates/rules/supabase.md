# Supabase

## 기본 설정

- `@supabase/ssr` 사용 (서버/클라이언트 모두)
- 환경변수: `NEXT_PUBLIC_SUPABASE_URL` + `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- 직접 DB 연결 없음, SDK/REST API만 사용

## 인증

- Email Confirm: OFF (회원가입 시 즉시 로그인)
- 세션 갱신: `supabase.auth.getSession()` 호출 시 자동 갱신 의존, 수동 refresh 불필요
- 로그아웃: `supabase.auth.signOut()` 후 `redirect('/auth/login')` 호출

## RLS (Row Level Security)

- 모든 테이블에 RLS 활성화 필수
- `auth.uid()` 기반 정책으로 사용자 데이터 격리
- `service_role` 키는 서버 사이드에서만 사용, 클라이언트 노출 금지

### RLS 테스트 패턴 (TDD 통합)

RLS 정책 변경은 다른 코드와 동일하게 RED-GREEN-REFACTOR 적용. 정책 추가/변경 시 다음 시나리오를 먼저 테스트로 작성한다:

1. **소유자 접근 — 통과**: 본인 row select/update/delete 가능 확인
2. **타 유저 접근 — 차단**: 다른 `auth.uid()`로 시도 시 빈 결과 또는 권한 에러
3. **익명 접근 — 차단**: 미로그인 상태(`anon` role)에서 접근 차단
4. **service_role — 우회 확인**: 서버 사이드 `service_role` 키 사용 시 RLS 우회되는지 (의도적 우회만 허용)

테스트 환경: 로컬 supabase(`supabase start`) + 테스트 DB seeding. Vitest에서 두 개 supabase client(소유자/타인) 생성하여 비교.

## 에러 처리

- Supabase 쿼리 후 반드시 `error` 필드 확인:
  ```typescript
  const { data, error } = await supabase.from('table').select()
  if (error) {
    return { success: false, error: error.message }
  }
  ```
- 사용자에게 내부 DB 에러 메시지를 그대로 노출하지 않기
- `PGRST` 접두사 에러 코드는 로깅만 하고, 사용자에게는 일반 메시지 표시

## 쿼리 패턴

- SELECT: `supabase.from('table').select('col1, col2')` — 필요한 컬럼만 명시
- INSERT/UPDATE: Server Action 내에서만 수행
- 실시간 구독: 클라이언트 컴포넌트에서 `supabase.channel()` 사용, cleanup 필수
