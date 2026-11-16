# Layer 2: 코드 리뷰 상세 패턴

각 항목에 대해 Grep으로 후보를 찾고, Read로 맥락을 확인하여 판단.

---

## 2-1. XSS + CSP

### 검색 패턴

```
# React에서 XSS 위험 경로
패턴: dangerouslySetInnerHTML
글로브: *.{tsx,jsx}

# 사용자 입력이 href에 직접 삽입
패턴: href=\{.*(?:query|param|input|user|search|url)
글로브: *.{tsx,jsx}

# CSP 헤더 강도 확인
패턴: Content-Security-Policy
대상: next.config.*, middleware.*
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| dangerouslySetInnerHTML + DOMPurify sanitize | PASS (조건부) |
| dangerouslySetInnerHTML + 사용자 입력 직접 전달 | FAIL (Critical) |
| CSP에 `unsafe-inline` `unsafe-eval` 포함 | FAIL (High) |
| CSP nonce 또는 hash 기반 | PASS |
| href에 `javascript:` 프로토콜 가능 | FAIL (High) |

---

## 2-2. SQLi / Injection

### 검색 패턴

```
# SQL 문자열 연결 (템플릿 리터럴)
패턴: `.*(?:SELECT|INSERT|UPDATE|DELETE|FROM|WHERE).*\$\{
글로브: *.{ts,js}

# SQL 문자열 연결 (+ 연산자)
패턴: ['"].*(?:SELECT|INSERT|UPDATE|DELETE).*['"].*\+
글로브: *.{ts,js}

# Supabase RPC 또는 raw SQL
패턴: \.rpc\(|\.sql\(|raw\(|rawQuery
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| ORM (Prisma, Drizzle) parameterized query | PASS |
| Supabase SDK 체이닝 (.from().select().eq()) | PASS |
| `supabase.rpc()` + 파라미터 바인딩 | PASS |
| SQL 문자열에 변수 직접 삽입 | FAIL (Critical) |
| Prisma `$executeRawUnsafe` + 사용자 입력 | FAIL (Critical) |

---

## 2-3. CSRF

### 검색 패턴

```
# 상태 변경 API 라우트
패턴: export.*(?:POST|PUT|PATCH|DELETE)
글로브: **/route.{ts,js}, **/api/**/*.{ts,js}

# CSRF 토큰 확인
패턴: csrf|xsrf|_token|csrfToken
글로브: *.{ts,js,tsx}

# SameSite 쿠키 설정
패턴: SameSite
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| SameSite=Strict/Lax + 같은 origin만 허용 | PASS |
| CSRF 토큰 검증 미들웨어 존재 | PASS |
| 상태 변경 API에 인증만 있고 CSRF 보호 없음 | FAIL (Medium) — SPA에서 SameSite=Lax면 대부분 충분 |
| Cookie credentials + CORS origin 와일드카드 | FAIL (Critical) |

---

## 2-4. CORS

### 검색 패턴

```
# CORS 설정
패턴: Access-Control-Allow-Origin|cors|allowedOrigins
글로브: next.config.*, middleware.*, *.{ts,js}

# 와일드카드 origin
패턴: Allow-Origin.*\*|origin:\s*['"]?\*
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| 특정 origin 명시 | PASS |
| 와일드카드(*) + credentials: false | PASS (주의) |
| 와일드카드(*) + credentials: true | FAIL (Critical) — 브라우저 차단하지만 설계 오류 |
| 요청 origin을 그대로 반사 | FAIL (High) |
| Preflight 캐시 (Access-Control-Max-Age) 설정 | 권장 |

---

## 2-5. SSRF

### 검색 패턴

```
# URL을 파라미터로 받아 fetch하는 패턴
패턴: fetch\(.*(?:req|request|query|param|body).*(?:url|uri|link|href|endpoint)
글로브: **/api/**/*.{ts,js}, **/route.{ts,js}

# URL 파라미터 기반 리다이렉트/프록시
패턴: (?:proxy|redirect|forward|fetch|axios|got)\(.*(?:url|uri)
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| URL 허용목록(allowlist) 검증 후 fetch | PASS |
| URL 파라미터를 검증 없이 서버에서 fetch | FAIL (High) |
| 내부 IP (10.x, 172.16.x, 192.168.x, 127.x, localhost) 차단 | PASS (부분) |
| DNS rebinding 방어 (IP 사전 검증) | PASS (완전) |

---

## 2-6. 파일 업로드

### 검색 패턴

```
# 파일 업로드 처리
패턴: formData|multipart|multer|busboy|formidable|upload
글로브: **/api/**/*.{ts,js}, **/route.{ts,js}

# 파일 저장
패턴: writeFile|createWriteStream|putObject|upload\(
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| 파일 업로드 기능 없음 | N/A |
| MIME 타입 + 확장자 허용목록 검증 | PASS |
| 확장자만 검증 (MIME 미검증) | FAIL (Medium) |
| 파일명에 경로 탈출 (../) 방지 | 필수 확인 |
| 업로드 크기 제한 설정 | 필수 확인 |
| 실행 가능 확장자 (.js, .php, .sh) 차단 | 필수 확인 |
| S3/Supabase Storage 사용 (서버 파일시스템 미사용) | PASS (저장 경로 탈출 N/A) |

---

## 2-7. Open Redirect

### 검색 패턴

```
# redirect 파라미터 사용
패턴: returnUrl|returnTo|callbackUrl|goto|redirect_uri
글로브: **/api/**/*.{ts,js}, **/route.{ts,js}, *.{tsx,jsx}

# 서버사이드 리다이렉트
패턴: redirect\(.*(?:query|param|searchParams)
글로브: *.{ts,js,tsx}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| redirect URL이 상대경로만 허용 | PASS |
| 허용 도메인 목록으로 검증 | PASS |
| URL 파라미터를 검증 없이 redirect | FAIL (Medium) |
| `//evil.com` 형태 (프로토콜 상대 URL) 차단 | 필수 확인 |

---

## 2-8. Mass Assignment

### 검색 패턴

```
# req.body를 직접 DB에 전달
패턴: \.(?:create|update|insert|upsert)\(.*(?:req\.body|body|data)
글로브: **/api/**/*.{ts,js}, **/route.{ts,js}

# Prisma/Drizzle에 spread 연산자
패턴: \.(?:create|update)\(\{.*\.\.\.(?:body|data|input)
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| Zod/Yup으로 허용 필드만 파싱 후 전달 | PASS |
| 명시적 필드 선택 (pick/destructuring) | PASS |
| req.body를 spread로 직접 전달 | FAIL (High) |
| `role`, `isAdmin` 등 권한 필드가 업데이트 가능 | FAIL (Critical) |

---

## 2-9. 에러 노출 차단

### 검색 패턴

```
# stack trace 노출
패턴: (?:error|err)\.(?:stack|message).*(?:json|send|response|res\.)
글로브: **/api/**/*.{ts,js}, **/route.{ts,js}

# 상세 에러 응답
패턴: catch.*\{.*(?:res\.json|Response\.json|NextResponse\.json).*(?:error|err|message)
글로브: *.{ts,js}
멀티라인: true
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| 프로덕션에서 일반 에러 메시지만 반환 | PASS |
| NODE_ENV 기반 분기 (dev에서만 상세) | PASS |
| stack trace를 클라이언트에 그대로 반환 | FAIL (Medium) |
| DB 에러 메시지 (테이블명, 칼럼명) 노출 | FAIL (High) |

---

## 2-10. Cookie / 세션 보안

### 검색 패턴

```
# 쿠키 설정
패턴: Set-Cookie|cookie|setCookie|cookies\(\)\.set
글로브: *.{ts,js}

# 세션 관련 설정
패턴: cookie.*session|setCookie|maxAge
글로브: *.{ts,js}
```

### 판단 기준

| 플래그 | 요구 | FAIL 조건 |
|--------|------|----------|
| HttpOnly | 인증 쿠키 필수 | HttpOnly 미설정 |
| Secure | 프로덕션 필수 | Secure 미설정 |
| SameSite | Lax 이상 | None + Secure 없이 |
| 만료 | 적절한 maxAge | 무기한 세션 |
| 세션 ID | 충분한 엔트로피 | 예측 가능한 ID |

Supabase Auth 사용 시: SDK가 기본적으로 안전한 쿠키 설정 → 커스텀 쿠키만 확인.

---

## 2-11. Cryptography

### 검색 패턴

```
# 비밀번호 해싱
패턴: bcrypt|argon2|scrypt|pbkdf2|md5|sha1|sha256|crypto\.createHash
글로브: *.{ts,js}

# JWT 설정
패턴: sign\(|verify\(|jsonwebtoken|jose
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| bcrypt/argon2 사용 | PASS |
| MD5/SHA1 단독 해싱 (비밀번호) | FAIL (Critical) |
| SHA256 + salt (비밀번호) | FAIL (High) — bcrypt/argon2 권장 |
| JWT HS256 + 약한 secret (< 32자) | FAIL (High) |
| JWT RS256/ES256 + 적절한 키 관리 | PASS |
| Supabase Auth 사용 (직접 해싱 안 함) | PASS |

---

## 2-12. Deserialization

### 검색 패턴

```
# 위험한 역직렬화
패턴: pickle|yaml\.load(?!_safe)|unserialize|ObjectInputStream
글로브: *.{py,ts,js,java}

# JSON.parse는 일반적으로 안전하나 prototype pollution 확인
패턴: JSON\.parse\(.*(?:req|request|body|query|param)
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| JSON.parse만 사용 | PASS (prototype pollution은 별도) |
| yaml.safe_load 사용 | PASS |
| yaml.load (Python) 사용자 입력 | FAIL (Critical) |
| pickle + 외부 입력 | FAIL (Critical) |
| 프로젝트에 역직렬화 없음 | N/A |

---

## 2-13. IDOR / 수평적 권한 상승

### 검색 패턴

```
# ID 파라미터로 리소스 직접 접근
패턴: (?:params|query|searchParams)\.(?:id|userId|resourceId|postId)
글로브: **/api/**/*.{ts,js}, **/route.{ts,js}

# Supabase에서 소유권 검증 없이 조회
패턴: \.eq\(['"]id['"],.*(?:params|query|body)
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| `auth.uid()` 또는 세션 userId로 소유권 검증 후 조회 | PASS |
| Supabase RLS로 행 수준 격리 (auth.uid()) | PASS |
| ID 파라미터로 리소스 조회 시 소유권 검증 없음 | FAIL (High) — OWASP A01 핵심 |
| 관리자 API에 역할 검증 없이 타 사용자 리소스 접근 | FAIL (Critical) |

---

## 2-14. Prototype Pollution

### 검색 패턴

```
# 위험한 병합 패턴
패턴: Object\.assign\(.*(?:req|request|body|query|param)
글로브: *.{ts,js}

# lodash merge + 사용자 입력
패턴: (?:merge|extend|defaults)\(.*(?:body|query|params)
글로브: *.{ts,js}

# __proto__ / constructor 키 패턴
패턴: __proto__|constructor\[|prototype\[
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| 사용자 입력을 Object.assign/merge로 기존 객체에 병합 | FAIL (High) |
| JSON.parse 후 키 검증 없이 객체 확장 | FAIL (Medium) |
| Zod/Yup으로 스키마 검증 후 안전한 필드만 사용 | PASS |
| lodash 4.17.21+ 사용 (패치 버전) | PASS (부분) |

---

## 2-15. Server Actions 보안

### 검색 패턴

```
# "use server" 함수 식별
패턴: "use server"
글로브: *.{ts,js,tsx}

# server-only 패키지 사용 확인
패턴: from ['"]server-only['"]
글로브: *.{ts,js}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| Server Action 인자에 Zod 검증 적용 | PASS |
| `server-only` 패키지로 서버 전용 모듈 격리 | PASS |
| Server Action 인자 무검증 DB 전달 | FAIL (High) |
| closure로 민감 변수(API key) 캡처 — 클라이언트 접근 가능성 | FAIL (Critical) |
| Server Action에 인증/권한 체크 없음 | FAIL (High) |

---

## 2-16. LLM Prompt Injection

### 검색 패턴

```
# 사용자 입력이 프롬프트에 삽입되는 패턴
패턴: (?:messages|prompt|content).*(?:req|body|query|userInput|input)
글로브: *.{ts,js}

# LLM 출력을 무검증으로 DOM/SQL에 삽입
패턴: innerHTML.*(?:completion|response|result|output)
글로브: *.{ts,js,tsx}
```

### 판단 기준

| 상황 | 판정 |
|------|------|
| 사용자 입력을 시스템 프롬프트와 명확히 분리 | PASS |
| 사용자 입력을 프롬프트 내부에 직접 삽입 (검증 없음) | FAIL (High) |
| LLM 출력을 HTML에 직접 삽입 (XSS 위험) | FAIL (Critical) |
| LLM 출력을 SQL 쿼리에 삽입 | FAIL (Critical) |
| LLM 출력으로 명령 실행 시 샌드박스 미적용 | FAIL (Critical) |
