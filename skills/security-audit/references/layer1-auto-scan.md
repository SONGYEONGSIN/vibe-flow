# Layer 1: 자동 스캔 상세 패턴

## 1-1. 의존성 취약점

```bash
# npm
npm audit --json 2>/dev/null | head -100

# pnpm
pnpm audit --json 2>/dev/null | head -100

# yarn
yarn audit --json 2>/dev/null | head -100
```

**판정:**
- PASS: Critical/High 0건
- FAIL: Critical 또는 High 1건 이상
- `npm audit fix`로 자동 수정 가능 여부 함께 보고

---

## 1-2. Secret 노출

### 소스코드 내 하드코딩 검출

```
# Grep 패턴 (소스코드 대상, node_modules/dist/.next 제외)
패턴: (api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|secret[_-]?key|private[_-]?key|password)\s*[:=]\s*['"][^'"]{8,}
글로브: *.{ts,tsx,js,jsx,py,env}
제외 경로: node_modules, .next, dist, build

# Supabase 키 하드코딩
패턴: (eyJhbGci[A-Za-z0-9_-]+|sb-[a-z0-9]+-[a-z]+\.supabase\.co)
```

### .env 파일 git 추적 확인

```bash
git ls-files | grep -E '\.env$|\.env\.local$|\.env\.production$'
```

**판정:**
- PASS: 소스코드 내 secret 0건 + .env 미추적
- FAIL: 1건 이상 검출

### .gitignore 확인

```
# .gitignore에 아래 항목 존재 확인
패턴: ^\.env
파일: .gitignore
```

---

## 1-3. 보안헤더 설정

### 검사 대상 파일

```
글로브: next.config.{js,mjs,ts}, middleware.{ts,js}, src/middleware.{ts,js}
```

### 필수 헤더

| 헤더 | 검색 패턴 | 최소 요구 |
|------|----------|----------|
| Content-Security-Policy | `Content-Security-Policy\|CSP` | 존재 |
| Strict-Transport-Security | `Strict-Transport-Security\|HSTS` | `max-age=31536000` 이상 |
| X-Frame-Options | `X-Frame-Options` | DENY 또는 SAMEORIGIN |
| X-Content-Type-Options | `X-Content-Type-Options` | nosniff |
| Referrer-Policy | `Referrer-Policy` | strict-origin-when-cross-origin 이상 |
| Permissions-Policy | `Permissions-Policy` | 존재 |

**판정:**
- PASS: 필수 6개 중 5개 이상 설정
- FAIL: CSP 또는 HSTS 미설정 시 무조건 FAIL

---

## 1-4. 위험 패턴 스캔

### 검색 패턴

| 패턴 | Grep 정규식 | 심각도 |
|------|------------|--------|
| eval 사용 | `\beval\(` | Critical |
| innerHTML 직접 할당 | `\.innerHTML\s*=` | High |
| dangerouslySetInnerHTML | `dangerouslySetInnerHTML` | High |
| document.write | `document\.write\(` | High |
| SQL 문자열 연결 | `` `.*SELECT.*\$\{`` 또는 `'.*SELECT.*' \+` | Critical |
| new Function | `new Function\(` | High |
| child_process exec | `exec\(.*\$\{` 또는 `exec\(.*\+` | Critical |
| window.location 조작 | `window\.location\s*=\s*` (변수 대입) | Medium |

**각 검출 건에 대해:**
1. 파일 경로와 라인 번호 기록
2. 주변 컨텍스트(5줄) 읽어서 안전한 사용인지 판단
3. 안전한 경우 (예: 상수만 사용) → 제외 처리

---

## 1-5. .env 파일 git 추적

```bash
# tracked .env 파일 검출
git ls-files | grep -i '\.env'

# .gitignore에 .env 패턴 존재 확인
grep -n '\.env' .gitignore 2>/dev/null
```

**판정:**
- PASS: .env 파일이 git에 추적되지 않음 + .gitignore에 패턴 존재
- FAIL: .env 파일이 tracked 상태

---

## 1-6. HTTPS 강제

```
# HSTS 설정 (1-3과 중복되나 별도 확인)
패턴: Strict-Transport-Security
대상: next.config.*, middleware.*, vercel.json

# HTTP → HTTPS 리다이렉트
패턴: redirect.*https\|forceSSL\|requireHTTPS
```

**Vercel/Netlify 배포 시:** 플랫폼이 자동 HTTPS 제공하므로 HSTS 헤더만 확인.

**판정:**
- PASS: HSTS 설정 존재 또는 PaaS 자동 HTTPS
- FAIL: self-hosted인데 HTTPS 강제 로직 없음

---

## 1-7. 클라이언트 번들 Secret 노출

### 검색 패턴

```
# NEXT_PUBLIC_ 환경변수에 민감 키 노출
패턴: NEXT_PUBLIC_.*(SECRET|PRIVATE|SERVICE_ROLE|PASSWORD)
글로브: *.{ts,tsx,js,jsx}, .env*

# publicRuntimeConfig에 민감 정보
패턴: publicRuntimeConfig.*(?:secret|key|token)
대상: next.config.{js,mjs,ts}
```

**판정:**
- PASS: NEXT_PUBLIC_ 변수에 민감 키 없음
- FAIL (High): NEXT_PUBLIC_로 시작하는 Secret/Key/Password 환경변수 존재
- 주의: NEXT_PUBLIC_ 변수는 클라이언트 번들에 포함되어 모든 사용자에게 노출됨. 하드코딩 없이 환경변수로 설정해도 클라이언트에 노출되므로 FAIL.

---

## 1-8. Supply Chain 무결성

### 검색 패턴

```bash
# lockfile 커밋 여부
git ls-files | grep -E 'package-lock\.json|pnpm-lock\.yaml|yarn\.lock'

# postinstall 스크립트 검출
grep -n '"postinstall"' package.json
```

**판정:**
- PASS: lockfile이 git에 커밋됨
- FAIL (High): lockfile 없음 — 의존성 버전 고정 불가, 재현 불가능한 빌드
- 주의: postinstall 스크립트 존재 시 내용 검토 필수 (임의 코드 실행 가능성)

---

## 1-9. 어드민 페이지 노출 (열거 전용)

L3-1의 입력 보조 항목. 보호 여부 판정은 수행하지 않고, 후보 열거와 정보성 경고만 제공.

### 1단계: 어드민 후보 경로 열거

글로브 (App Router):
- app/**/admin/**/page.{tsx,ts,jsx,js}
- app/**/backoffice/**/page.{tsx,ts,jsx,js}
- app/**/cms/**/page.{tsx,ts,jsx,js}
- app/**/internal/**/page.{tsx,ts,jsx,js}

글로브 (Pages Router — Step 0에서 감지 시):
- pages/**/admin/**/*.{tsx,ts,jsx,js}

결과: 후보 경로 리스트 출력 (0건이면 N/A)

주의:
- Route Group `(admin)`은 실제 URL에 admin이 포함되지 않음 — 파일 경로와 URL 경로 구분 표기
- `/admin/login`, `/admin/signin` 등 인증 진입점은 별도 표기 (보호 대상이 아님)
- `dashboard`는 어드민 후보에서 제외 (대부분 일반 사용자 대시보드)
- 동적 라우트 기반 역할 분기(`[role]/page.tsx`)는 정적 분석 한계 — L3-1 수동 확인 위임

### 2단계: robots.txt/sitemap 정보성 경고

파일: app/robots.ts, public/robots.txt, app/sitemap.ts, public/sitemap.xml

확인 사항:
- robots.txt에 어드민 후보 경로가 Disallow로 명시 → INFO: "Disallow는 크롤러 가이드일 뿐 접근 차단이 아님. 오히려 공격자에게 경로 힌트를 제공할 수 있음"
- sitemap에 어드민 후보 경로 포함 → WARN (High): "sitemap이 어드민 경로를 검색엔진에 노출"

### 출력

| 출력 | 설명 |
|------|------|
| 후보 리스트 | L3-1에 전달할 어드민 후보 페이지 경로 목록 |
| robots.txt INFO | Disallow 존재 시 정보성 메시지 |
| sitemap WARN | 어드민 경로 포함 시 High 경고 |

PASS/FAIL 판정 없음. sitemap 노출만 WARN(High)으로 별도 기록.
