# Breaking Change 분석 체크리스트

## 일반 분석 절차

### 1. 정보 수집
```bash
# GitHub 릴리스 노트 확인
npm info <package> repository.url

# 버전 간 변경사항 (Current → Latest)
# GitHub: /releases 또는 /blob/main/CHANGELOG.md
```

### 2. Breaking Changes 영향 분석

각 breaking change에 대해:

| 항목 | 확인 내용 |
|------|----------|
| **API 변경** | 함수 시그니처, 반환 타입 변경 → `Grep`으로 사용처 검색 |
| **삭제된 API** | deprecated → removed 항목 → `Grep`으로 사용 여부 확인 |
| **설정 변경** | config 파일 형식/키 변경 → 설정 파일 확인 |
| **peer 요구사항** | 새로운 peer dependency 또는 버전 범위 변경 |
| **Node.js 최소 버전** | engines 필드 확인 |
| **TypeScript 버전** | 최소 TS 버전 상향 여부 |

### 3. 영향 코드 검색

```bash
# deprecated API 사용처 검색 예시
# Grep 도구로 패턴 검색 (rg 문법)
pattern: "deprecatedFunction|oldApiName|removedMethod"
glob: "*.{ts,tsx,js,jsx}"
```

## 주요 프레임워크별 마이그레이션 포인트

### Next.js (Major 업그레이드)
- `next.config.js` → `next.config.ts` 전환 여부
- App Router / Pages Router 변경사항
- `Image` 컴포넌트 props 변경
- Middleware API 변경
- 빌트인 폰트 변경
- `next/headers`, `next/cookies` API 변경

### React (Major 업그레이드)
- 새로운 JSX Transform 적용 여부
- Concurrent 기능 변경
- deprecated lifecycle 메서드 제거
- StrictMode 동작 변경
- `createRoot` vs `render` 전환

### Tailwind CSS (Major 업그레이드)
- 설정 파일 형식 변경
- 유틸리티 클래스 이름 변경/삭제
- 플러그인 API 변경
- `@apply` 동작 변경
- content 경로 설정 변경

### TypeScript (Major 업그레이드)
- 새로운 strict 옵션 기본값 변경
- 타입 추론 변경 (기존 코드 빌드 실패 가능)
- `tsconfig.json` 새 옵션

### Supabase (Major 업그레이드)
- Client SDK API 변경 (`createClient` 옵션)
- Auth API 변경 (session 처리)
- Realtime API 변경
- RLS 정책 동작 변경

## 안전한 업그레이드 순서

1. **타입 정의 먼저**: `@types/*` 패키지
2. **빌드 도구**: TypeScript, ESLint, Prettier
3. **프레임워크 코어**: React → Next.js (React가 peer)
4. **UI 라이브러리**: Tailwind, shadcn/ui 등
5. **데이터 레이어**: Supabase, Prisma 등
6. **유틸리티**: lodash, date-fns 등

**원칙**: 의존성 트리 하위(leaf)부터 상위(root)로. 각 단계마다 `build + test` 검증.

## 롤백 전략

업그레이드 실패 시:
```bash
# git으로 롤백
git checkout -- package.json package-lock.json
rm -rf node_modules
npm install

# 또는 특정 버전으로 되돌리기
npm install <package>@<previous-version>
```
