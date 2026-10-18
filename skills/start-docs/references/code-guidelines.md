# 코드 가이드라인 템플릿

## 1. 네이밍 규칙

### 1.1 파일/폴더명

| 유형 | 규칙 | 예시 |
|------|------|------|
| 컴포넌트 | PascalCase | `Button.tsx`, `UserCard.tsx` |
| 유틸리티 | camelCase | `formatDate.ts`, `useAuth.ts` |
| 상수 | kebab-case | `api-routes.ts`, `error-codes.ts` |
| 스타일 | kebab-case | `button.module.css` |
| 테스트 | 원본명.test | `Button.test.tsx` |
| 타입 파일 | kebab-case | `database.types.ts` |

### 1.2 변수/함수명

| 유형 | 규칙 | 예시 |
|------|------|------|
| 변수 | camelCase | `userName`, `isLoading` |
| 상수 | UPPER_SNAKE | `MAX_LIMIT`, `API_URL` |
| 함수 | camelCase (동사 시작) | `getUserById`, `handleSubmit` |
| 훅 | use + camelCase | `useAuth`, `useLocalStorage` |
| 컴포넌트 | PascalCase | `Button`, `UserProfile` |
| 타입/인터페이스 | PascalCase | `User`, `ApiResponse` |
| Enum | PascalCase (값도) | `UserRole.Admin` |

### 1.3 Boolean 변수

```typescript
// 좋은 예: is/has/can/should 접두사
const isLoading = true
const hasError = false
const canEdit = true
const shouldRefetch = false
const isAuthenticated = true

// 나쁜 예: 동사 없음
const loading = true
const error = false
```

### 1.4 이벤트 핸들러

```typescript
// 컴포넌트 내부: handle + 명사 + 동사
const handleButtonClick = () => {}
const handleFormSubmit = () => {}
const handleInputChange = () => {}

// Props: on + 명사 + 동사
interface Props {
  onButtonClick: () => void
  onFormSubmit: (data: FormData) => void
  onItemSelect: (id: string) => void
}
```

### 1.5 약어 사용 규칙

| 허용 약어 | 의미 | 금지 약어 |
|----------|------|-----------|
| `id` | identifier | `idx` (→ index) |
| `ref` | reference | `btn` (→ button) |
| `props` | properties | `usr` (→ user) |
| `ctx` | context | `msg` (→ message) |
| `auth` | authentication | `pwd` (→ password) |
| `env` | environment | `cnt` (→ count) |

---

## 2. 폴더 구조

```
project-root/
├── .husky/                    # Git hooks
│   ├── pre-commit
│   └── commit-msg
│
├── src/
│   ├── app/                   # Next.js App Router
│   │   ├── (auth)/           # 인증 필요 라우트 그룹
│   │   │   ├── dashboard/
│   │   │   └── settings/
│   │   ├── (marketing)/      # 퍼블릭 라우트 그룹
│   │   │   ├── about/
│   │   │   └── pricing/
│   │   ├── api/              # API Routes
│   │   │   └── v1/
│   │   ├── globals.css
│   │   ├── layout.tsx
│   │   └── page.tsx
│   │
│   ├── components/           # 컴포넌트
│   │   ├── ui/              # 기본 UI (Button, Input, Card)
│   │   ├── common/          # 공통 (Header, Footer, Layout)
│   │   ├── forms/           # 폼 관련
│   │   └── features/        # 기능별
│   │       ├── auth/
│   │       │   ├── LoginForm.tsx
│   │       │   └── index.ts
│   │       └── dashboard/
│   │
│   ├── hooks/                # 커스텀 훅
│   │   ├── use-auth.ts
│   │   ├── use-local-storage.ts
│   │   └── index.ts
│   │
│   ├── lib/                  # 라이브러리 설정
│   │   ├── supabase/
│   │   │   ├── client.ts    # 브라우저용
│   │   │   ├── server.ts    # 서버용
│   │   │   └── admin.ts     # Admin용 (서버 전용)
│   │   ├── utils.ts         # cn, formatDate 등
│   │   └── validations.ts   # Zod 스키마
│   │
│   ├── types/               # 타입 정의
│   │   ├── database.types.ts  # Supabase 생성 타입
│   │   ├── api.types.ts
│   │   └── index.ts
│   │
│   ├── constants/           # 상수
│   │   ├── routes.ts
│   │   ├── config.ts
│   │   └── messages.ts
│   │
│   └── services/            # 비즈니스 로직
│       ├── user.service.ts
│       └── auth.service.ts
│
├── public/                   # 정적 파일
│   ├── images/
│   └── fonts/
│
├── tests/                    # E2E 테스트
│   └── e2e/
│
└── scripts/                  # 유틸리티 스크립트
    └── seed.ts
```

### 2.1 Import 순서 규칙

```typescript
// 1. React/Next.js 관련
import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Image from 'next/image'

// 2. 외부 라이브러리
import { z } from 'zod'
import { toast } from 'sonner'

// 3. 내부 모듈 (@/ alias)
import { Button } from '@/components/ui/button'
import { useAuth } from '@/hooks/use-auth'
import { cn } from '@/lib/utils'

// 4. 타입 (type import)
import type { User } from '@/types'

// 5. 상대 경로 (현재 폴더)
import { helper } from './helper'
```

---

## 3. 환경 변수 관리

### 3.1 파일 구조

```
project-root/
├── .env                  # 기본값 (Git 제외, 로컬 개발)
├── .env.example          # 템플릿 (Git 포함)
├── .env.local            # 로컬 오버라이드 (Git 제외)
├── .env.development      # 개발 환경
├── .env.production       # 프로덕션 환경
└── .env.test             # 테스트 환경
```

### 3.2 네이밍 규칙

```bash
# .env.example
# ========================================
# App
# ========================================
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXT_PUBLIC_APP_NAME="My App"

# ========================================
# Supabase
# ========================================
NEXT_PUBLIC_SUPABASE_URL=your-project-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key  # 서버 전용

# ========================================
# Third-party Services
# ========================================
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
RESEND_API_KEY=re_xxx

# ========================================
# Feature Flags
# ========================================
NEXT_PUBLIC_ENABLE_ANALYTICS=false
ENABLE_EMAIL_VERIFICATION=true
```

### 3.3 타입 안전 환경 변수

```typescript
// src/lib/env.ts
import { z } from 'zod'

const envSchema = z.object({
  // Public (클라이언트 접근 가능)
  NEXT_PUBLIC_APP_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),

  // Private (서버 전용)
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),

  // Optional with defaults
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
})

// 빌드 타임 검증
export const env = envSchema.parse({
  NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL,
  NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
  STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY,
  NODE_ENV: process.env.NODE_ENV,
})
```

---

## 4. 컴포넌트 작성 규칙

### 4.1 컴포넌트 구조

```typescript
// 1. 임포트 (외부 → 내부 → 타입 순서)
import { useState, useCallback } from 'react'
import { Button } from '@/components/ui/button'
import { cn } from '@/lib/utils'
import type { User } from '@/types'

// 2. 타입 정의
interface UserCardProps {
  // 필수 props
  user: User
  onSave: (user: User) => void
  // 선택 props (기본값 있음)
  variant?: 'default' | 'compact'
  className?: string
}

// 3. 컴포넌트
export function UserCard({
  user,
  onSave,
  variant = 'default',
  className,
}: UserCardProps) {
  // 3.1 상태
  const [isEditing, setIsEditing] = useState(false)

  // 3.2 훅
  const { data, isLoading } = useQuery(...)

  // 3.3 파생 값 (useMemo 고려)
  const displayName = user.name ?? 'Unknown'

  // 3.4 이벤트 핸들러
  const handleSave = useCallback(() => {
    onSave(user)
    setIsEditing(false)
  }, [user, onSave])

  // 3.5 조기 반환 (Early return)
  if (isLoading) return <Skeleton />

  // 3.6 렌더링
  return (
    <div className={cn('p-4 rounded-lg', className)}>
      {/* ... */}
    </div>
  )
}
```

### 4.2 Props 규칙

```typescript
// 기본값은 구조분해에서 설정
export function Button({
  children,
  onClick,
  variant = 'primary',
  size = 'md',
  disabled = false,
  loading = false,
  className,
  ...props  // HTML 속성 전달
}: ButtonProps) {
  return (
    <button
      className={cn(buttonVariants({ variant, size }), className)}
      disabled={disabled || loading}
      onClick={onClick}
      {...props}
    >
      {loading ? <Spinner /> : children}
    </button>
  )
}
```

### 4.3 Compound Component 패턴

```typescript
// Card.tsx
function CardRoot({ children, className }: CardProps) {
  return <div className={cn('rounded-lg border', className)}>{children}</div>
}

function CardHeader({ children }: { children: React.ReactNode }) {
  return <div className="p-6 pb-0">{children}</div>
}

function CardContent({ children }: { children: React.ReactNode }) {
  return <div className="p-6">{children}</div>
}

// Export
export const Card = Object.assign(CardRoot, {
  Header: CardHeader,
  Content: CardContent,
})

// 사용
<Card>
  <Card.Header>Title</Card.Header>
  <Card.Content>Content</Card.Content>
</Card>
```

---

## 5. TypeScript 규칙

### 5.1 타입 정의

```typescript
// 객체 타입: interface 사용 (확장 가능)
interface User {
  id: string
  name: string
  email: string
  createdAt: Date
}

// 유니온/리터럴 타입: type 사용
type Status = 'pending' | 'success' | 'error'
type UserRole = 'admin' | 'user' | 'guest'

// 유틸리티 타입 활용
type UserPartial = Partial<User>
type UserCreate = Omit<User, 'id' | 'createdAt'>
type UserUpdate = Pick<User, 'name' | 'email'>

// API 응답 타입
interface ApiResponse<T> {
  success: boolean
  data: T
  error?: {
    code: string
    message: string
  }
}

// 페이지네이션 응답
interface PaginatedResponse<T> {
  items: T[]
  total: number
  page: number
  pageSize: number
  hasMore: boolean
}
```

### 5.2 Zod 스키마와 타입 추론

```typescript
import { z } from 'zod'

// 스키마 정의
export const userSchema = z.object({
  name: z.string().min(2, '이름은 2자 이상'),
  email: z.string().email('올바른 이메일 형식'),
  age: z.number().min(0).max(120).optional(),
})

// 타입 추론
export type UserInput = z.infer<typeof userSchema>

// 폼에서 사용
const form = useForm<UserInput>({
  resolver: zodResolver(userSchema),
})
```

### 5.3 타입 가드

```typescript
// 커스텀 타입 가드
function isUser(data: unknown): data is User {
  return (
    typeof data === 'object' &&
    data !== null &&
    'id' in data &&
    'email' in data &&
    typeof (data as User).id === 'string'
  )
}

// 사용
if (isUser(response)) {
  console.log(response.email)  // 타입 안전
}

// Discriminated Union 활용
type Result<T, E = Error> =
  | { success: true; data: T }
  | { success: false; error: E }

function handleResult<T>(result: Result<T>) {
  if (result.success) {
    return result.data  // T 타입
  } else {
    throw result.error  // E 타입
  }
}
```

---

## 6. 에러 처리

### 6.1 Error Boundary

```typescript
// src/components/error-boundary.tsx
'use client'

import { Component, type ReactNode } from 'react'
import { Button } from '@/components/ui/button'

interface Props {
  children: ReactNode
  fallback?: ReactNode
}

interface State {
  hasError: boolean
  error?: Error
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    // 에러 로깅 서비스에 전송
    console.error('ErrorBoundary caught:', error, errorInfo)
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <div className="flex flex-col items-center gap-4 p-8">
          <h2 className="text-xl font-semibold">문제가 발생했습니다</h2>
          <p className="text-muted-foreground">
            {this.state.error?.message}
          </p>
          <Button onClick={() => this.setState({ hasError: false })}>
            다시 시도
          </Button>
        </div>
      )
    }

    return this.props.children
  }
}
```

### 6.2 API 에러 처리

```typescript
// src/lib/api-error.ts
export class ApiError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode: number = 500,
    public details?: unknown
  ) {
    super(message)
    this.name = 'ApiError'
  }

  static badRequest(message: string, details?: unknown) {
    return new ApiError(message, 'BAD_REQUEST', 400, details)
  }

  static unauthorized(message = '인증이 필요합니다') {
    return new ApiError(message, 'UNAUTHORIZED', 401)
  }

  static forbidden(message = '권한이 없습니다') {
    return new ApiError(message, 'FORBIDDEN', 403)
  }

  static notFound(message = '리소스를 찾을 수 없습니다') {
    return new ApiError(message, 'NOT_FOUND', 404)
  }
}

// API Route에서 사용
export async function GET(request: Request) {
  try {
    const data = await fetchData()
    return Response.json({ data })
  } catch (error) {
    if (error instanceof ApiError) {
      return Response.json(
        { error: { code: error.code, message: error.message } },
        { status: error.statusCode }
      )
    }
    return Response.json(
      { error: { code: 'INTERNAL_ERROR', message: '서버 오류' } },
      { status: 500 }
    )
  }
}
```

### 6.3 비동기 에러 래퍼

```typescript
// 안전한 비동기 함수 래퍼
type AsyncResult<T> =
  | { data: T; error: null }
  | { data: null; error: Error }

export async function tryCatch<T>(
  promise: Promise<T>
): Promise<AsyncResult<T>> {
  try {
    const data = await promise
    return { data, error: null }
  } catch (error) {
    return { data: null, error: error as Error }
  }
}

// 사용
const { data, error } = await tryCatch(fetchUser(id))
if (error) {
  console.error('Failed:', error.message)
  return
}
console.log(data)  // User 타입
```

---

## 7. 로깅 전략

### 7.1 로그 레벨

| 레벨 | 용도 | 예시 |
|------|------|------|
| `error` | 즉시 대응 필요 오류 | DB 연결 실패, 결제 실패 |
| `warn` | 잠재적 문제 | 느린 쿼리, deprecated API |
| `info` | 주요 이벤트 | 사용자 로그인, 주문 완료 |
| `debug` | 개발 디버깅 | 변수 값, 실행 흐름 |

### 7.2 구조화된 로깅

```typescript
// src/lib/logger.ts
type LogLevel = 'error' | 'warn' | 'info' | 'debug'

interface LogContext {
  userId?: string
  requestId?: string
  action?: string
  [key: string]: unknown
}

function createLogger() {
  const log = (level: LogLevel, message: string, context?: LogContext) => {
    const timestamp = new Date().toISOString()
    const entry = {
      timestamp,
      level,
      message,
      ...context,
    }

    // 개발 환경: 콘솔 출력
    if (process.env.NODE_ENV === 'development') {
      const color = {
        error: '\x1b[31m',  // 빨강
        warn: '\x1b[33m',   // 노랑
        info: '\x1b[36m',   // 시안
        debug: '\x1b[90m',  // 회색
      }[level]
      console.log(`${color}[${level.toUpperCase()}]\x1b[0m`, message, context ?? '')
    } else {
      // 프로덕션: JSON 출력 (로그 수집 도구용)
      console.log(JSON.stringify(entry))
    }
  }

  return {
    error: (message: string, context?: LogContext) => log('error', message, context),
    warn: (message: string, context?: LogContext) => log('warn', message, context),
    info: (message: string, context?: LogContext) => log('info', message, context),
    debug: (message: string, context?: LogContext) => log('debug', message, context),
  }
}

export const logger = createLogger()

// 사용
logger.info('User logged in', { userId: 'abc123', action: 'login' })
logger.error('Payment failed', { userId: 'abc123', orderId: 'order_xxx', error: err.message })
```

---

## 8. 순환 참조 방지

### 8.1 문제 예시

```typescript
// ❌ 순환 참조 발생
// user.ts
import { Order } from './order'
export interface User {
  orders: Order[]
}

// order.ts
import { User } from './user'  // 순환!
export interface Order {
  user: User
}
```

### 8.2 해결 방법

```typescript
// ✅ 방법 1: 타입 전용 파일 분리
// types/index.ts (단일 소스)
export interface User {
  id: string
  name: string
}

export interface Order {
  id: string
  userId: string
}

export interface UserWithOrders extends User {
  orders: Order[]
}

// ✅ 방법 2: 관계 ID만 포함
// user.ts
export interface User {
  id: string
  orderIds: string[]  // ID만 저장
}

// ✅ 방법 3: 배럴 파일 주의
// components/index.ts - 순환 유발 가능
export * from './Button'
export * from './Card'  // Card가 Button import 시 순환

// 해결: 직접 import
import { Button } from '@/components/Button'  // index.ts 거치지 않음
```

### 8.3 순환 참조 감지

```bash
# madge로 순환 참조 검사
npx madge --circular src/
```

---

## 9. 코드 품질 도구

### 9.1 ESLint 설정

```javascript
// eslint.config.mjs
import { dirname } from "path"
import { fileURLToPath } from "url"
import { FlatCompat } from "@eslint/eslintrc"

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const compat = new FlatCompat({
  baseDirectory: __dirname,
})

const eslintConfig = [
  ...compat.extends(
    "next/core-web-vitals",
    "next/typescript"
  ),
  {
    rules: {
      // TypeScript
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/consistent-type-imports": ["error", { prefer: "type-imports" }],

      // React
      "react/jsx-curly-brace-presence": ["error", { props: "never", children: "never" }],
      "react/self-closing-comp": "error",

      // Import
      "import/order": ["error", {
        groups: ["builtin", "external", "internal", "parent", "sibling", "index", "type"],
        "newlines-between": "always",
        alphabetize: { order: "asc" }
      }],

      // General
      "no-console": ["warn", { allow: ["warn", "error"] }],
      "prefer-const": "error",
    }
  }
]

export default eslintConfig
```

### 9.2 Prettier 설정

```json
// .prettierrc
{
  "semi": false,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100,
  "plugins": ["prettier-plugin-tailwindcss"],
  "tailwindFunctions": ["cn", "cva"]
}
```

```text
# .prettierignore
node_modules
.next
dist
coverage
*.generated.ts
```

### 9.3 Git Hooks (Husky + lint-staged)

```bash
# 설치
npm install -D husky lint-staged
npx husky init
```

```json
// package.json
{
  "scripts": {
    "prepare": "husky"
  },
  "lint-staged": {
    "*.{ts,tsx}": [
      "eslint --fix",
      "prettier --write"
    ],
    "*.{json,md}": [
      "prettier --write"
    ]
  }
}
```

```bash
# .husky/pre-commit
npx lint-staged

# .husky/commit-msg
npx commitlint --edit $1
```

### 9.4 Commitlint 설정

```javascript
// commitlint.config.js
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat',     // 새 기능
      'fix',      // 버그 수정
      'refactor', // 리팩토링
      'style',    // 코드 스타일
      'docs',     // 문서
      'test',     // 테스트
      'chore',    // 빌드/설정
      'perf',     // 성능 개선
      'revert',   // 되돌리기
    ]],
    'subject-case': [2, 'never', ['sentence-case', 'start-case']],
  }
}
```

---

## 10. 번들 분석

### 10.1 Next.js 번들 분석

```bash
# 설치
npm install -D @next/bundle-analyzer

# 분석 실행
ANALYZE=true npm run build
```

```javascript
// next.config.mjs
import bundleAnalyzer from '@next/bundle-analyzer'

const withBundleAnalyzer = bundleAnalyzer({
  enabled: process.env.ANALYZE === 'true',
})

export default withBundleAnalyzer({
  // Next.js 설정
})
```

### 10.2 번들 크기 기준

| 유형 | 경고 | 오류 |
|------|------|------|
| 페이지 JS | > 100KB | > 200KB |
| First Load JS | > 150KB | > 300KB |
| 개별 chunk | > 50KB | > 100KB |

### 10.3 최적화 기법

```typescript
// 동적 임포트
const DynamicComponent = dynamic(() => import('./HeavyComponent'), {
  loading: () => <Skeleton />,
  ssr: false,  // 클라이언트만
})

// 조건부 임포트
if (typeof window !== 'undefined') {
  const { analytics } = await import('./analytics')
  analytics.track('page_view')
}

// 트리쉐이킹 (명시적 import)
import { format } from 'date-fns'  // ✅ 개별 함수
import * as dateFns from 'date-fns'  // ❌ 전체 임포트
```

---

## 11. 테스트 규칙

### 11.1 테스트 파일 구조

```
src/
├── components/
│   └── Button/
│       ├── Button.tsx
│       ├── Button.test.tsx    # 단위 테스트
│       └── Button.stories.tsx # Storybook
│
tests/
├── e2e/
│   └── auth.spec.ts           # E2E 테스트
└── integration/
    └── api.test.ts            # 통합 테스트
```

### 11.2 테스트 구조 (AAA 패턴)

```typescript
import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { Button } from './Button'

describe('Button', () => {
  it('클릭 시 onClick 핸들러가 호출된다', () => {
    // Arrange (준비)
    const handleClick = vi.fn()
    render(<Button onClick={handleClick}>Click me</Button>)

    // Act (실행)
    fireEvent.click(screen.getByRole('button'))

    // Assert (검증)
    expect(handleClick).toHaveBeenCalledTimes(1)
  })

  it('disabled 상태에서는 클릭이 무시된다', () => {
    // Arrange
    const handleClick = vi.fn()
    render(<Button onClick={handleClick} disabled>Click me</Button>)

    // Act
    fireEvent.click(screen.getByRole('button'))

    // Assert
    expect(handleClick).not.toHaveBeenCalled()
  })
})
```

### 11.3 테스트 네이밍

```typescript
// 좋은 예: ~하면 ~한다
describe('LoginForm', () => {
  it('유효한 자격증명으로 제출하면 로그인에 성공한다')
  it('잘못된 비밀번호를 입력하면 에러 메시지가 표시된다')
  it('이메일 형식이 올바르지 않으면 제출 버튼이 비활성화된다')
})

// 나쁜 예: 기술적 설명
describe('LoginForm', () => {
  it('should call onSubmit')
  it('test error state')
  it('button disabled')
})
```

---

## 12. 코드 리뷰 체크리스트

### 12.1 기능 검토

- [ ] 요구사항을 충족하는가?
- [ ] 엣지 케이스를 처리하는가?
- [ ] 에러 처리가 적절한가?

### 12.2 코드 품질

- [ ] 네이밍이 명확한가?
- [ ] 중복 코드가 없는가?
- [ ] 함수가 단일 책임을 가지는가?
- [ ] 복잡한 로직에 주석이 있는가?

### 12.3 성능

- [ ] 불필요한 리렌더링이 없는가?
- [ ] 메모이제이션이 적절히 사용되었는가?
- [ ] N+1 쿼리 문제가 없는가?
- [ ] 큰 번들을 동적 임포트했는가?

### 12.4 보안

- [ ] 사용자 입력을 검증하는가?
- [ ] 민감 정보가 노출되지 않는가?
- [ ] 적절한 권한 검사가 있는가?
- [ ] SQL 인젝션/XSS 방어가 되어있는가?

### 12.5 테스트

- [ ] 핵심 로직에 테스트가 있는가?
- [ ] 테스트가 실제 동작을 검증하는가?
- [ ] 엣지 케이스 테스트가 있는가?

---

## 13. Git 커밋 규칙

### 13.1 커밋 메시지 형식

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 13.2 타입

| 타입 | 설명 | 예시 |
|------|------|------|
| feat | 새로운 기능 | feat(auth): 소셜 로그인 추가 |
| fix | 버그 수정 | fix(cart): 수량 계산 오류 수정 |
| refactor | 리팩토링 | refactor(api): 에러 처리 통합 |
| style | 코드 스타일 | style: prettier 적용 |
| docs | 문서 수정 | docs: API 문서 업데이트 |
| test | 테스트 | test(auth): 로그인 테스트 추가 |
| chore | 빌드/설정 | chore: 의존성 업데이트 |
| perf | 성능 개선 | perf(image): lazy loading 적용 |

### 13.3 좋은 커밋 메시지 예시

```
feat(auth): 소셜 로그인 기능 추가

- Google OAuth 연동
- GitHub OAuth 연동
- 기존 계정과 소셜 계정 연결 기능

Closes #123
```

---

## 14. 성능 최적화

### 14.1 컴포넌트 최적화

```typescript
import { memo, useMemo, useCallback } from 'react'

// memo: 불필요한 리렌더링 방지
const ExpensiveList = memo(function ExpensiveList({ items }: Props) {
  return items.map(item => <Item key={item.id} {...item} />)
})

// useMemo: 계산 결과 캐싱
function Dashboard({ data }: { data: Sale[] }) {
  const summary = useMemo(() => {
    return data.reduce((acc, sale) => acc + sale.amount, 0)
  }, [data])

  return <div>Total: {summary}</div>
}

// useCallback: 함수 참조 유지
function Form({ onSubmit }: Props) {
  const handleSubmit = useCallback((e: FormEvent) => {
    e.preventDefault()
    onSubmit(formData)
  }, [onSubmit, formData])

  return <form onSubmit={handleSubmit}>...</form>
}
```

### 14.2 이미지 최적화

```tsx
import Image from 'next/image'

// LCP 이미지: priority 추가
<Image
  src="/hero.webp"
  alt="Hero"
  width={1200}
  height={600}
  priority
  sizes="100vw"
/>

// 일반 이미지: lazy loading (기본값)
<Image
  src="/thumbnail.webp"
  alt="Thumbnail"
  width={400}
  height={300}
  placeholder="blur"
  blurDataURL="data:image/..."
/>
```

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 1.0 | {date} | 최초 작성 | {author} |
