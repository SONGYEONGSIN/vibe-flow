---
name: security-audit
description: |
  웹 애플리케이션 보안 감사 스킬. 3-Layer 구조(자동 스캔, 코드 리뷰, 아키텍처 리뷰)로 체계적 보안 점검 수행.
  "보안 감사", "보안 점검", "security audit", "취약점 스캔", "OWASP 점검", "보안 리뷰",
  "XSS 점검", "SQLi 점검", "CSRF 점검", "인증 보안 검토", "권한 검토" 요청 시 사용.
  deploy-safety-guard(운영 안정성)와 구분: 이 스킬은 공격 벡터 관점의 보안 전문 감사.
---

# Security Audit

3-Layer 구조의 웹 애플리케이션 보안 감사. 자동화 가능한 스캔부터 아키텍처 수준 리뷰까지 체계적으로 수행.

## 기존 보안 도구와의 관계

| 도구 | 역할 | 이 스킬과의 관계 |
|------|------|-----------------|
| `security-guidance` 플러그인 | 코드 작성 시 위험 패턴 차단 (PreToolUse 훅) | 보완: 작성 시점 vs 감사 시점 |
| `security-specialist` 에이전트 | 비정형 보안 질문/분석 | 보완: 전문가 vs 체크리스트 |
| `deploy-safety-guard` 스킬 | 운영 안정성/비용 통제 | 분리: 운영 관점 vs 공격 관점 |

---

## Workflow

### Step 0: 프로젝트 컨텍스트 파악

감사 전 프로젝트 기본 정보 수집:

```
1. package.json 읽기 → 프레임워크, 의존성 파악
2. 디렉토리 구조 확인 → src/, app/, api/, supabase/ 등
3. .env.example 또는 .env.local 존재 여부
4. 인증 방식 파악 → Supabase Auth, NextAuth, 커스텀 등
```

### N/A 처리 규칙

- 해당 기능이 프로젝트에 없는 항목은 N/A로 처리
- N/A 항목은 총 항목 수에서 제외 (통과율 분모에서 빠짐)
- 리포트에 N/A 사유를 항목별로 명기
- N/A를 PASS로 처리하는 것은 금지 (별도 열로 구분)

### 프레임워크별 API 패턴

L2, L3 스캔 시 감지된 프레임워크에 맞는 패턴을 적용한다.

| 프레임워크 | 상태 변경 API 패턴 | 글로브 |
|-----------|------------------|--------|
| Next.js App Router | `export.*(POST\|PUT\|PATCH\|DELETE)` | `**/route.{ts,js}` |
| Next.js Pages Router | `handler.*req.*res` | `**/api/**/*.{ts,js}` |
| Express/Hono | `app\.(post\|put\|patch\|delete)\|router\.(post\|put\|patch\|delete)` | `*.{ts,js}` |
| tRPC | `\.mutation\(` | `*.{ts,js}` |

### Step 1: Layer 1 — 자동 스캔

도구(Bash, Grep)로 자동 실행 가능한 항목. 상세 패턴: [references/layer1-auto-scan.md](references/layer1-auto-scan.md)

| # | 항목 | 도구 | 판정 기준 |
|---|------|------|----------|
| 1-1 | 의존성 취약점 | `npm audit` / `pnpm audit` | Critical/High 0건 |
| 1-2 | Secret 노출 | Grep (API key, password, token 패턴) | 소스코드 내 0건 |
| 1-3 | 보안헤더 설정 | Grep (next.config, middleware 내 헤더) | CSP, HSTS, X-Frame-Options 존재 |
| 1-4 | 위험 패턴 | Grep (eval, innerHTML, SQL 문자열 연결) | 0건 또는 안전한 사용 확인 |
| 1-5 | .env 파일 git 추적 | Bash (git ls-files) | .env가 tracked 아님 |
| 1-6 | HTTPS 강제 | Grep (HSTS 설정, redirect 로직) | 설정 존재 |
| 1-7 | 클라이언트 번들 Secret | Grep (NEXT_PUBLIC_ + SECRET/PASSWORD) | 0건 |
| 1-8 | Supply Chain 무결성 | Bash (lockfile 커밋 여부) | lockfile tracked |
| 1-9 | 어드민 페이지 열거 | Glob (어드민 후보 경로) | 열거 전용 — 판정은 L3-1 |

### Step 2: Layer 2 — 코드 리뷰

Grep/Read로 패턴을 찾고 맥락을 분석. 상세 패턴: [references/layer2-code-review.md](references/layer2-code-review.md)

| # | 항목 | 핵심 확인 사항 |
|---|------|---------------|
| 2-1 | XSS + CSP | 사용자 입력 → 출력 경로 추적, CSP 헤더 강도 |
| 2-2 | SQLi / Injection | Parameterized query 사용 여부, ORM raw query 안전성 |
| 2-3 | CSRF | 상태 변경 API에 토큰/SameSite 보호 |
| 2-4 | CORS | 와일드카드(*) 사용, credentials 포함 시 origin 제한 |
| 2-5 | SSRF | URL 파라미터 기반 fetch, 내부 IP 차단 여부 |
| 2-6 | 파일 업로드 | MIME 검증, 확장자 허용목록, 저장 경로 탈출 방지 |
| 2-7 | Open Redirect | redirect 파라미터 검증, 허용 도메인 목록 |
| 2-8 | Mass Assignment | req.body 직접 DB 전달, 허용 필드 명시적 선언 |
| 2-9 | 에러 노출 차단 | stack trace 클라이언트 노출, 상세 에러 메시지 |
| 2-10 | Cookie/세션 | HttpOnly, Secure, SameSite 플래그, 세션 만료 |
| 2-11 | Cryptography | 비밀번호 해싱 알고리즘(bcrypt/argon2), 약한 해시 사용 |
| 2-12 | Deserialization | JSON.parse 외 역직렬화, pickle/yaml.load 사용 |

| 2-13 | IDOR / 수평적 권한 상승 | ID 파라미터 기반 리소스 소유권 검증(auth.uid()) |
| 2-14 | Prototype Pollution | lodash.merge, Object.assign + 사용자 입력 패턴 |
| 2-15 | Server Actions 보안 | "use server" 인자 Zod 검증, server-only 사용, closure 민감정보 |
| 2-16 | LLM Prompt Injection | 사용자 입력 → LLM prompt 삽입, 출력 무검증 사용 |

### Step 3: Layer 3 — 아키텍처 리뷰

설계 수준 분석. 코드 + 구조를 종합 판단. 상세: [references/layer3-architecture.md](references/layer3-architecture.md)

| # | 항목 | 핵심 확인 사항 |
|---|------|---------------|
| 3-1 | AuthN/AuthZ 흐름 | 인증 미들웨어 일관성, 보호되지 않은 라우트 |
| 3-2 | RBAC/ABAC + 테넌트 격리 | 역할 검증 로직, 교차 테넌트 데이터 접근 차단 |
| 3-3 | 최소권한 원칙 | DB 권한, API 키 스코프, 서비스 계정 범위 |
| 3-4 | Rate Limit / Bruteforce | 인증 엔드포인트 제한, IP/유저별 차등 |
| 3-5 | Audit Log | 민감 작업 기록, 변조 방지, 보존 기간 |
| 3-6 | Secret 관리 + Rotation | 키 저장 방식, 교체 전략, 만료 정책 |
| 3-7 | Privacy / 데이터 최소수집 | PII 수집 범위, 삭제권, 암호화 저장 |
| 3-8 | Software Integrity | SRI 태그, lockfile commit, CI/CD 파이프라인 보안 |
| 3-9 | Security Monitoring & Alerting | 보안 이벤트 탐지/알림 (Audit Log 기록과 별도) |
| 3-10 | Insecure Design Patterns | Business logic flaw (가격조작, 음수수량, 쿠폰중복, 레이스컨디션) |

### Step 4: 리포트 생성

```markdown
# Security Audit Report

**프로젝트:** {name}
**점검일:** {YYYY-MM-DD}
**종합 등급:** {A/B/C/D/F}

---

## Layer 1: 자동 스캔 ({N}/9 통과)

| # | 항목 | 상태 | 심각도 | 비고 |
|---|------|------|--------|------|
| 1-1 | 의존성 취약점 | PASS/FAIL | — | npm audit 결과 |
| ... | ... | ... | ... | ... |

## Layer 2: 코드 리뷰 ({N}/16 통과)

| # | 항목 | 상태 | 심각도 | 위치 |
|---|------|------|--------|------|
| 2-1 | XSS + CSP | PASS/FAIL | Critical/High/Medium/Low | file:line |
| ... | ... | ... | ... | ... |

## Layer 3: 아키텍처 리뷰 ({N}/10 통과)

| # | 항목 | 상태 | 심각도 | 소견 |
|---|------|------|--------|------|
| 3-1 | AuthN/AuthZ 흐름 | PASS/FAIL | — | 설명 |
| ... | ... | ... | ... | ... |

---

## 긴급 조치 (Critical/High)
1. ...

## 권장 조치 (Medium)
1. ...

## 개선 사항 (Low)
1. ...
```

### 등급 기준

위에서 아래로 첫 매칭 방식으로 적용.

| 순서 | 등급 | 조건 |
|------|------|------|
| 1 | F | Critical >= 3 또는 "인증 우회 가능" |
| 2 | D | Critical >= 1 또는 High >= 5 |
| 3 | C | High >= 2 또는 Medium >= 10 |
| 4 | B | High == 1 또는 Medium >= 4 |
| 5 | A | 나머지 (Critical 0, High 0, Medium 3 이하) |

**"인증 우회 가능" 정의** (하나라도 해당 시 F 판정):
- 3-1: 상태 변경 API에 인증 체크 완전 부재, 또는 비공개 페이지에 서버사이드 보호 완전 부재
- 3-2: 서버사이드 역할 검증 없이 클라이언트만으로 접근 제어
- 2-4 + 2-3: CORS origin 반사(Critical) + credentials 허용 동시 발생

---

## Troubleshooting

| 문제 | 원인 | 해결 |
|------|------|------|
| Grep에 node_modules 결과 포함 | 글로브 제외 미적용 | path에서 node_modules 제외 확인 |
| npm audit 실패 (EAUDITNOPJSON) | lockfile 없음 | `npm install` 먼저 실행 |
| RLS 검증 시 마이그레이션 파일 없음 | Dashboard로만 관리 | Supabase MCP로 직접 RLS 확인 |
| minified 코드 대량 false positive | 빌드 출력물 검색 대상 포함 | .next, dist, build 디렉토리 제외 |
| monorepo에서 복수 package.json | 루트만 점검 | 각 패키지별 개별 점검 명시 |
| 프레임워크 미식별 | Step 0 생략 | Step 0 필수 후 패턴 분기 적용 |
| L1-9에서 dashboard가 잡힘 | dashboard는 어드민 후보에서 제외됨 | 사용자 대시보드는 L3-1의 역방향 검출에서 인증 여부만 확인 |
| Route Group (admin) URL 불일치 | 괄호 안 이름은 URL에 미포함 | L1-9에서 파일경로/URL경로 구분 표기 |
| 미들웨어 matcher가 정규식 | L1-9 자동 파싱 한계 | L3-1에서 수동 확인. WARN 처리 |

## Anti-patterns

| 패턴 | 문제 | 대안 |
|------|------|------|
| 전 항목 PASS 처리 | False sense of security | 의심 시 FAIL(Medium)로 보수적 판정 |
| L1만 실행하고 등급 판정 | 설계 결함 미발견 | L1→L2→L3 순서 필수 |
| N/A를 PASS로 처리 | 통과율 부풀리기 | N/A는 별도 열, 총 항목에서 제외 |
| 한 번 감사로 "안전" 결론 | 코드 변경 시 새 취약점 | 배포마다 반복 감사 |
| 심각도 낮춰서 등급 올리기 | 위험 과소평가 | 판단 기준표 엄격 준수 |

---

## 교차참조

- Rate Limit 비용 통제 관점 → `deploy-safety-guard` Step 4
- Secret 환경변수 검증 관점 → `deploy-safety-guard` Step 2
- 종합 배포 전 감사 → `site-auditor`

## References

| 파일 | 내용 |
|------|------|
| [references/layer1-auto-scan.md](references/layer1-auto-scan.md) | L1 자동 스캔 상세 패턴 및 명령어 |
| [references/layer2-code-review.md](references/layer2-code-review.md) | L2 코드 리뷰 상세 패턴 및 판단 기준 |
| [references/layer3-architecture.md](references/layer3-architecture.md) | L3 아키텍처 리뷰 체크리스트 및 판단 기준 |
