---
name: Supabase 마이그레이션 운영 함정
description: SQL Editor 사용 시 자주 발생하는 부분 적용 / RLS / GRANT / cache 문제와 해결 패턴
type: feedback
originSessionId: f1dae096-5cba-4988-9e0e-8dc18bebf09f
---
## SQL Editor에 한국어 안내문 paste 금지

**Why:** 사용자가 마이그레이션 SQL과 함께 한국어 안내문을 통째 paste하면 PostgreSQL이 syntax error로 거부 (예: `42601: syntax error at or near "마지막"`).

**How to apply:** 사용자에게 SQL 보낼 땐 깔끔한 SQL 블록만 별도로 제공. 한국어 안내는 `--` 주석 또는 SQL 외부에 둠. 또는 한 번에 여러 statement 보낼 때 명확히 분리.

## RLS 정책만으론 부족 — GRANT도 필요

**Why:** RLS 정책(`create policy ... to authenticated`)만 있고 PostgreSQL `GRANT ... TO authenticated`가 없으면 `42501 permission denied`. RLS는 정책 위에서 동작하지 GRANT를 대체하지 않음.

**How to apply:** 새 테이블 마이그레이션엔 항상 두 세트 모두 포함:
```sql
-- RLS 정책
alter table public.foo enable row level security;
create policy "foo_select" on public.foo for select to authenticated using (true);

-- GRANT (필수)
grant usage on schema public to authenticated;
grant select, insert, update on public.foo to authenticated;
```
service_role 스크립트는 별도 GRANT 필요 (`GRANT ALL ... TO service_role`).

## PostgREST schema cache는 자동 reload 안 될 때가 있음

**Why:** ALTER TABLE로 컬럼 추가했는데 Supabase JS client가 `Could not find the 'X' column ... in the schema cache` 반환. PostgREST의 OpenAPI cache stale.

**How to apply:** 마이그레이션 끝에 `NOTIFY pgrst, 'reload schema';` 한 줄 추가. 또는 Dashboard → API → Reload schema 버튼. 컬럼 add + reload를 한 트랜잭션에 두면 안전.

## 마이그레이션 부분 실행 위험

**Why:** Supabase SQL Editor에서 사용자가 일부 statement만 select 후 RUN하면 마이그레이션이 부분 적용됨. `IF NOT EXISTS`/`IF EXISTS` 가드는 idempotent라 안전하지만 `DROP CONSTRAINT` + `ADD CONSTRAINT`처럼 짝을 이루는 부분은 한쪽만 실행되면 enum 변경이 부분 반영.

**How to apply:** 사용자 요청 SQL은 한 블록에 모두 넣고 "전체 선택 후 RUN" 안내. 부분 실행 의심 시 `pg_get_constraintdef`나 `information_schema.columns`로 실제 상태 확인. CONSTRAINT 변경 같은 짝 statement는 트랜잭션(BEGIN/COMMIT)으로 묶기.

## SQL Editor의 `language sql` + `$$` dollar-quote 파서 버그

**Why:** Supabase SQL Editor가 `create function ... language sql ... as $$ <multi-line SELECT> $$;` 패턴에서 dollar-quote 본문의 newline을 statement separator로 오인. 결과: `42601 syntax error` 또는 `42804 argument of AND must be type boolean, not type integer` (본문의 `select 1`이 standalone statement로 실행되며 다음 줄과 결합 평가). `language plpgsql`은 영향 없음 — BEGIN/END 블록을 정상 인식.

**How to apply:** SQL function은 가능하면 `language plpgsql` + `begin / return ... ; end;` 패턴으로 작성. SQL이 단순해도 RLS helper처럼 운영 SQL Editor로 paste하는 함수는 plpgsql 권장. `language sql`을 꼭 써야 하면 named dollar-quote(`$func$ ... $func$`) 시도 → 그래도 실패하면 plpgsql로 전환.

```sql
-- ❌ Supabase SQL Editor에서 실패하기 쉬움
create function is_admin() returns boolean language sql stable security definer as $$
  select exists (select 1 from operators where ...);
$$;

-- ✅ plpgsql 패턴 (이 프로젝트의 set_updated_at trigger와 동일 컨벤션)
create function is_admin() returns boolean language plpgsql stable security definer as $$
begin
  return exists (select 1 from operators where ...);
end;
$$;
```

## RLS policy `case ... when ... else ... end` 표현식 syntax error

**Why:** Supabase SQL Editor가 RLS `using (...)` / `with check (...)` 안의 `case ... when ... end` 표현식을 잘못 파싱해서 `42601 syntax error at or near "using"` 또는 case 분기 줄에서 에러를 낸다. PostgreSQL 자체는 정상 지원하지만 Editor의 statement separator 인식이 case 표현식과 충돌.

**How to apply:** RLS 분기는 항상 OR 조건으로 풀어쓴다. case 문 대신 `(domain = 'X' and ...) or (domain = 'Y' and ...)` 패턴.

```sql
-- ❌ Editor에서 fail
using (
  case domain
    when 'notice' then public.is_admin()
    else (public.is_admin() or author_email = (auth.jwt() ->> 'email'))
  end
)

-- ✅ OR 패턴 (의미 동일)
using (
  public.is_admin()
  or (domain = 'feedback' and author_email = (auth.jwt() ->> 'email'))
)
```

도메인 enum별 정책을 별도 정책으로 분리하는 것도 대안이지만 OR 패턴이 가장 단순.

## service_role도 GRANT 누락 시 permission denied

**Why:** Supabase에서 새 테이블을 만들 때 `service_role`은 RLS bypass 자동 적용되지만 PostgreSQL의 GRANT는 자동 적용되지 않음. `grant ... to authenticated` + RLS만 작성하고 `grant ... to service_role`을 빠뜨리면, 서버 스크립트(`scripts/*.mjs` 같은 service-role key 사용 도구)가 `permission denied for table X` (42501)로 실패. RLS가 우회되므로 0 rows 가 아니라 에러로 즉시 차단.

**How to apply:** 새 테이블 마이그레이션엔 RLS + GRANT to authenticated + GRANT to service_role 세 세트 모두 포함:

```sql
alter table public.foo enable row level security;
create policy ... on public.foo to authenticated using (...);

-- authenticated (UI/app)
grant select, insert, update, delete on public.foo to authenticated;

-- service_role (server scripts) — 누락하면 42501
grant all on public.foo to service_role;
```

기존 테이블에 service_role GRANT 누락이 발견되면 별도 마이그레이션 한 줄(`grant all on public.foo to service_role; notify pgrst, 'reload schema';`)로 즉시 보강.
