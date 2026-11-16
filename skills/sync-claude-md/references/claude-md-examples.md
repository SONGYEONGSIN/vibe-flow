# CLAUDE.md 예시 모음

프로젝트 규모별 CLAUDE.md 작성 예시. 실제 프로젝트 구조를 반영한 실용적 템플릿.

---

## 예시 1: 소형 프로젝트 (유틸리티 라이브러리)

```markdown
# date-utils-kr

한국어 날짜 유틸리티 라이브러리.

## 빠른 시작

- 설치: `pnpm install`
- 테스트: `pnpm test`
- 빌드: `pnpm build`
- 배포: `pnpm publish`

## 기술 스택

- TypeScript 5.7, tsup (빌드), Vitest (테스트)
- Node.js 20+ (Intl.DateTimeFormat 한국어 지원 필요)

## 프로젝트 구조

```
src/
├── format.ts    # 날짜 포맷팅 함수
├── parse.ts     # 문자열 → Date 파싱
├── relative.ts  # 상대 시간 ("3시간 전")
└── index.ts     # 배럴 export
```

## 코딩 컨벤션

- 모든 public 함수에 JSDoc 필수 (npm 문서 자동 생성)
- `Date` 대신 timestamp(number) 매개변수 우선 사용 (timezone 실수 방지)
- 에러는 `throw` 대신 `Result<T, E>` 반환 (라이브러리 사용자 친화)
- `Intl.DateTimeFormat` 기반 구현 (외부 라이브러리 의존 금지)

## 알려진 제약

- Safari 14 이하에서 `Intl.RelativeTimeFormat` 미지원 → polyfill 필요
- `ko-KR` 로케일의 `formatToParts()`에서 요일 순서 비표준 (수동 조합)
```

**분량:** ~40줄. 핵심만.

---

## 예시 2: 중형 프로젝트 (Next.js 웹앱)

```markdown
# wellness-dashboard

직장인 건강 관리 대시보드.

## 빠른 시작

- 설치: `pnpm install`
- 개발: `pnpm dev` (localhost:3000)
- 빌드: `pnpm build`
- 타입 체크: `pnpm typecheck`
- 린트: `pnpm lint`
- Supabase 로컬: `supabase start` → `pnpm db:types`

## 기술 스택

- Next.js 15, React 19, TypeScript 5.7
- Tailwind CSS 4, shadcn/ui
- Supabase (Auth + DB + Storage)
- Zustand 5 (클라이언트 상태)
- Zod 4 (스키마 검증, `z.treeifyError()` 사용)
- Recharts (차트)

## 프로젝트 구조

```
src/
├── app/           # App Router
│   ├── (public)/  # 비인증 라우트
│   ├── (auth)/    # 인증 필요 라우트
│   └── api/       # API Routes
├── components/
│   ├── ui/        # shadcn 컴포넌트
│   ├── common/    # 공용 컴포넌트
│   └── features/  # 기능별 컴포넌트
├── lib/           # 유틸리티, Supabase 클라이언트
├── services/      # 비즈니스 로직
├── repositories/  # DB 접근 레이어
├── types/         # 타입 정의
├── schemas/       # Zod 스키마
├── stores/        # Zustand 스토어
└── constants/     # 상수
```

## 코딩 컨벤션

### 타입

- `interface` 사용 (ESLint consistent-type-definitions)
- DB 타입은 `database.types.ts`에서 추론, 수동 정의 시 `Record<never, never>` 패턴
- `!` 금지 → `getClientEnv()`/`getServerEnv()` 사용

### Import 순서 (perfectionist/sort-imports)

1. 외부 패키지
2. `@/` 내부 (알파벳순)
3. 상대 경로
4. type import (같은 순서, blank line 없이)

### 패턴

- Server Action: `'use server'` + Zod 검증
- 클라이언트 이벤트: `() => void handleAsync()` (no-misused-promises)
- 환경변수: `getClientEnv()`/`getServerEnv()` (proxy.ts만 `process.env.X ?? ''`)
- JSON.parse 결과: `as Json` 캐스팅

### 네이밍

- 컴포넌트: PascalCase (`UserProfile.tsx`)
- 훅: camelCase (`useAuth.ts`)
- 유틸: camelCase (`formatDate.ts`)
- 상수: SCREAMING_SNAKE (`MAX_RETRY_COUNT`)
- 타입 파일: kebab-case (`user.types.ts`)

## 아키텍처 결정

- **Repository + Service 패턴**: DB 접근(Repository) → 비즈니스 로직(Service) → Server Action/API Route
- **OAuth만 사용**: 카카오/구글, 이메일 인증 미사용
- **Moshier ephemeris**: sweph flag=4, se1 파일 불필요 (정밀도 충분)
- **하이브리드 점사**: 룰 엔진 1차 분석 → LLM 종합 합성

## 알려진 제약

- ESLint 10 비호환 → 9 사용
- Zod 4: `.format()` deprecated → `z.treeifyError()`, `z.string().uuid()` → `z.uuid()`
- Next.js typedRoutes: 동적 경로 Link href에 `as never` 필요 (빌드 전)
- sweph: `require('sweph')` + 수동 타입 캐스팅 (consistent-type-imports 제약)
- `restrict-template-expressions`: number는 `String()` 래핑
- `toISOString().split('T')[0]!` → `.slice(0, 10)` (no-non-null-assertion)

## 개발 워크플로우

- 커밋: Conventional Commits 영어 타입 + 한국어 설명 (`feat: 소셜 로그인 구현`)
- 브랜치: `main` 직접 커밋 (1인 개발)
- 배포: Vercel (미설정)
```

**분량:** ~100줄. 중형 프로젝트의 이상적 분량.

---

## 예시 3: 대형 프로젝트 (모노레포/팀 프로젝트)

```markdown
# commerce-platform

B2C 이커머스 플랫폼 모노레포.

## 빠른 시작

### 최초 설정

```bash
pnpm install
cp .env.example .env.local  # 환경변수 복사
docker compose up -d         # Redis, PostgreSQL, MinIO
pnpm db:migrate              # DB 마이그레이션
pnpm db:seed                 # 시드 데이터
```

### 일상 개발

```bash
pnpm dev                  # 전체 워크스페이스
pnpm dev --filter=web     # 웹앱만
pnpm dev --filter=admin   # 어드민만
pnpm test                 # 전체 테스트
pnpm test:e2e             # Playwright E2E
pnpm lint                 # 전체 린트
pnpm typecheck            # 전체 타입 체크
```

### 환경변수

| 변수 | 필수 | 설명 |
|------|:----:|------|
| DATABASE_URL | O | PostgreSQL 연결 |
| REDIS_URL | O | Redis 세션/캐시 |
| STRIPE_SECRET_KEY | O | 결제 |
| STRIPE_WEBHOOK_SECRET | O | 웹훅 검증 |
| S3_ENDPOINT | O | MinIO/S3 |
| NEXT_PUBLIC_API_URL | O | API 베이스 URL |

## 기술 스택

### 코어

| 패키지 | 버전 | 비고 |
|--------|------|------|
| Next.js | 15.x | App Router |
| React | 19.x | Server Components |
| TypeScript | 5.7 | strict mode |
| Prisma | 6.x | ORM |
| tRPC | 11.x | 타입 안전 API |

### 인프라

| 서비스 | 용도 |
|--------|------|
| Vercel | 프론트엔드 배포 |
| Railway | 백엔드 + DB |
| Upstash Redis | 세션, 캐시, Rate Limit |
| Cloudflare R2 | 이미지/파일 저장 |
| Stripe | 결제 |
| Sentry | 에러 모니터링 |

## 프로젝트 구조

```
apps/
├── web/        # B2C 프론트엔드 (Next.js)
├── admin/      # 어드민 대시보드 (Next.js)
└── api/        # API 서버 (tRPC + Prisma)

packages/
├── ui/         # 공유 컴포넌트 라이브러리
├── db/         # Prisma 스키마 + 마이그레이션
├── config/     # ESLint, TypeScript 설정 공유
├── utils/      # 공유 유틸리티
└── types/      # 공유 타입 정의
```

## 코딩 컨벤션

### 필수 규칙

- `any` 금지 → `unknown` + 타입 가드
- 배럴 파일(index.ts) 금지 → 직접 import (번들 사이즈)
- `console.log` 금지 → `logger.info/warn/error`
- 하드코딩 URL 금지 → 환경변수 또는 `constants/`
- SQL 직접 작성 금지 → Prisma 쿼리

### API 레이어

```
Router (tRPC) → Service → Repository (Prisma) → DB
  ↓                ↓
Zod 검증      비즈니스 로직
```

- Router: 입력 검증 + 인증 확인만
- Service: 비즈니스 로직, 트랜잭션 관리
- Repository: DB 쿼리만 (로직 금지)

### 컴포넌트

- Server Component 기본, 클라이언트 최소화
- `'use client'`는 파일 최상단, 사유 주석 필수
- Props 인터페이스 파일과 같은 위치에 정의

### 에러 처리

- API: `AppError` 클래스 사용 (code, message, statusCode)
- 클라이언트: Error Boundary + toast
- 로깅: Sentry에 자동 전송 (logger 연동)

## 아키텍처 결정

- **모노레포**: Turborepo (빌드 캐시, 태스크 오케스트레이션)
- **tRPC**: REST 대비 타입 안전, 프론트-백 스키마 공유
- **Prisma**: 타입 자동 생성, 마이그레이션 관리
- **Server Components**: 초기 번들 최소화, SEO
- **Upstash Redis**: 서버리스 호환 (커넥션 제한 없음)

## 알려진 제약

- Prisma 6: `findUniqueOrThrow` → `findUnique` + 수동 throw (에러 타입 제어)
- tRPC 11: middleware 체이닝 순서가 실행 순서 결정 (auth → rateLimit 순)
- Next.js 15: `headers()`/`cookies()` async (await 필수)
- Vercel Edge: Prisma Client 사용 불가 → Data Proxy 필요
- Stripe webhook: raw body 필요 → `export const config = { api: { bodyParser: false } }`

## 개발 워크플로우

### 브랜치 전략

- `main`: 프로덕션
- `develop`: 통합 테스트
- `feature/*`: 기능 개발
- `hotfix/*`: 긴급 수정

### PR 규칙

- 최소 1명 리뷰 필수
- CI 통과 필수 (lint + typecheck + test)
- 커밋: Conventional Commits (`feat:`, `fix:`, `chore:` 등)

### 배포

- `develop` → Vercel Preview
- `main` → Vercel Production (auto)
- DB 마이그레이션: PR에 포함, `main` 머지 시 자동 적용
```

**분량:** ~180줄. 대형 프로젝트의 상한선.

---

## 작성 품질 체크리스트

| # | 항목 | 기준 |
|---|------|------|
| 1 | 한 줄 규칙 | 각 bullet이 한 줄에 하나의 규칙 |
| 2 | why 포함 | 비자명한 규칙에 괄호로 이유 설명 |
| 3 | 코드 예시 | 인라인 코드 또는 최소 블록 |
| 4 | 중복 없음 | 하나의 정보가 하나의 섹션에만 |
| 5 | 현재 유효 | 더 이상 해당하지 않는 항목 없음 |
| 6 | 명령형 | "사용한다", "금지한다" |
| 7 | 분량 적정 | 소형 <60줄, 중형 60~150줄, 대형 150~300줄 |
| 8 | 구조 표준 | 빠른 시작 → 스택 → 구조 → 컨벤션 → 결정 → 제약 → 워크플로우 |

---

## 섹션별 작성 팁

### 빠른 시작
- 복사-붙여넣기로 바로 실행 가능하게
- 환경변수 테이블은 대형 프로젝트에서만

### 기술 스택
- 주요 기술만 (devDependency 나열 금지)
- 버전 제약이 있는 것만 버전 표기

### 프로젝트 구조
- 2단계까지만 (깊은 구조는 해당 디렉토리의 README에)
- 각 디렉토리 한 줄 설명

### 코딩 컨벤션
- ESLint로 강제되는 것은 생략 (설정 파일이 있으므로)
- ESLint로 못 잡는 팀 컨벤션 중심

### 아키텍처 결정
- "무엇" + "왜" (대안 대비 장점)
- ADR 번호 매기기 (대형 프로젝트)

### 알려진 제약
- 라이브러리 + 버전 + 증상 + 해결책
- 해결되면 삭제 (방치 금지)

### 개발 워크플로우
- 반복되는 질문에 대한 답 (브랜치? 커밋? 배포?)
- CI/CD 파이프라인 간략 설명
