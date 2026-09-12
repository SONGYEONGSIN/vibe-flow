# Layer 3: 아키텍처 리뷰 체크리스트

코드 패턴이 아닌 설계 수준 판단. Read로 관련 파일을 읽고 전체 흐름을 분석.

---

## 3-1. AuthN/AuthZ 흐름

### 확인 포인트

1. **인증 미들웨어 일관성**
   - 모든 보호 라우트에 인증 체크가 일관적으로 적용되는가?
   - 미들웨어 vs 개별 라우트 체크 → 미들웨어가 권장

2. **보호되지 않은 라우트 검출**
   ```
   # API 라우트 목록
   글로브: **/api/**/route.{ts,js}, app/**/route.{ts,js}, app/**/page.{tsx,ts}, app/**/layout.{tsx,ts}

   # 각 라우트에서 인증 체크 존재 여부
   패턴: auth|session|getUser|getServerSession|currentUser|requireAuth|withAuth
   ```
   모든 상태 변경 라우트(POST/PUT/PATCH/DELETE)에 인증 체크 존재 확인.

4. **페이지 라우트 보호 (역방향 검출)**

   L1-9에서 열거된 어드민 후보 + 아래 전체 페이지 스캔을 병행:

   ```
   # 모든 페이지 라우트에서 인증 체크 존재 여부
   글로브: app/**/page.{tsx,ts}
   패턴: auth|session|getUser|getServerSession|currentUser|requireAuth|withAuth|redirect.*login|createServerClient
   ```

   인증 체크가 없는 페이지 열거 → 공개 의도 화이트리스트 제외:
   - 공개 페이지 예시: `/`, `/about`, `/pricing`, `/login`, `/signup`, `/blog/**`, `/docs/**`
   - 화이트리스트는 프로젝트별로 다름 — 명시적 공개 의도 확인

   인증 체크 대상은 page.tsx 자체 + 상위 layout.tsx (가장 가까운 layout에서 인증하면 하위 page도 보호됨):
   ```
   # 해당 페이지의 상위 layout 체인에서 인증 체크
   글로브: app/**/layout.{tsx,ts}
   패턴: auth|session|getUser|getServerSession|currentUser|requireAuth|withAuth|redirect.*login|createServerClient
   ```

   Pages Router (Step 0에서 감지 시):
   ```
   글로브: pages/**/*.{tsx,ts}
   패턴: getServerSideProps.*session|getServerSideProps.*auth|getServerSideProps.*redirect
   ```

5. **클라이언트 사이드 전용 보호 안티패턴**
   ```
   패턴: useEffect.*(redirect|push.*login|router|location)
   글로브: app/**/page.{tsx,ts}
   ```
   위 패턴만 존재하고 서버사이드 체크(미들웨어/layout/page 서버 컴포넌트)가 없으면:
   - HTML이 서버에서 렌더링되어 클라이언트에 전달된 후 리다이렉트 → 콘텐츠 노출
   - JS 비활성화 시 보호 우회 가능

6. **동적 라우트 역할 분기 (수동 확인)**
   ```
   패턴: \[role\]|\[type\]|\[userType\]
   글로브: app/**/page.{tsx,ts}
   ```
   동적 세그먼트에서 런타임 역할 분기하는 패턴이 있으면 수동 확인 플래그.
   정적 분석 한계 — WARN으로만 보고.

3. **토큰 관리**
   - JWT 만료 시간 적절한가? (access: 15분~1시간, refresh: 7~30일)
   - 리프레시 토큰 로테이션 구현 여부
   - 로그아웃 시 토큰 무효화

### 판정

| 상황 | 판정 |
|------|------|
| 미들웨어 기반 일괄 보호 + 예외 명시 | PASS |
| 미들웨어/layout/page에서 서버사이드 인증 보호 | PASS |
| layout.tsx 체인에서 인증 체크 (미들웨어 없음) | PASS — layout 보호 충분 |
| 대부분 보호되나 1-2개 라우트 누락 | FAIL (High) |
| 인증 체크가 개별 라우트에 산재 | FAIL (Medium) — 누락 위험 |
| useEffect 기반 클라이언트 리다이렉트만 | FAIL (Critical) — 서버 렌더링 시 콘텐츠 노출 |
| 인증 체크 없는 비공개 페이지 | FAIL (High) |
| 동적 라우트 역할 분기 감지 | WARN — 수동 확인 필요 |
| 공개 API에 인증 없음 (의도적) | N/A — 의도 확인 |

---

## 3-2. RBAC/ABAC + 테넌트 격리

### 확인 포인트

1. **역할 기반 접근 제어**
   ```
   패턴: role|permission|can\(|ability|authorize|isAdmin|hasRole
   글로브: *.{ts,js}
   ```
   - 역할 검증이 서버사이드에서 수행되는가? (클라이언트 검증만은 FAIL)
   - 역할 변경 API가 적절히 보호되는가?

2. **테넌트 격리** (멀티테넌트 앱에만 해당)
   ```
   패턴: tenant|org_id|organization_id|team_id|workspace_id
   글로브: *.{ts,js}
   ```
   - 모든 DB 쿼리에 테넌트 필터가 적용되는가?
   - RLS 정책으로 행 수준 격리가 되는가?
   - 교차 테넌트 데이터 접근 테스트 가능한가?

3. **Supabase RLS 검증** (Supabase 사용 시)
   ```bash
   # RLS 활성화 확인
   grep -rn "enable.*row.*level\|alter.*table.*enable.*rls\|ENABLE ROW LEVEL" supabase/migrations/

   # RLS 정책 확인
   grep -rn "create policy\|CREATE POLICY" supabase/migrations/
   ```
   - 모든 사용자 데이터 테이블에 RLS 활성화
   - SELECT/INSERT/UPDATE/DELETE 각각에 정책 존재
   - `auth.uid()` 기반 사용자 격리

### 판정

| 상황 | 판정 |
|------|------|
| RBAC + 서버사이드 검증 | PASS |
| 클라이언트에서만 역할 확인 (UI 숨김) | FAIL (Critical) |
| 멀티테넌트 + 모든 쿼리에 테넌트 필터 | PASS |
| 멀티테넌트 + 일부 쿼리에 필터 누락 | FAIL (Critical) |
| Supabase RLS 전체 적용 | PASS |
| RLS 미적용 테이블 존재 (사용자 데이터) | FAIL (Critical) |

---

## 3-3. 최소권한 원칙

### 확인 포인트

1. **DB 권한**
   - 앱이 DB superuser로 연결하지 않는가?
   - Supabase: `service_role` 키 사용이 꼭 필요한 곳에만 제한
   ```
   패턴: service_role|SUPABASE_SERVICE_ROLE
   글로브: *.{ts,js}
   ```
   서버사이드 관리 작업에서만 사용, 클라이언트 노출 FAIL (Critical).

2. **API 키 스코프**
   - 외부 API 키가 필요한 최소 권한만 갖는가?
   - 읽기 전용 작업에 쓰기 권한 키 사용 → FAIL (Medium)

3. **파일시스템 접근**
   - 서버 프로세스의 파일시스템 접근 범위
   - 업로드 디렉토리가 코드 디렉토리와 분리

### 판정

| 상황 | 판정 |
|------|------|
| service_role 키가 서버 API에서만 사용 | PASS |
| service_role 키가 클라이언트 번들에 포함 | FAIL (Critical) |
| 외부 API 키에 필요 최소 스코프 | PASS |
| 과도한 권한의 API 키 | FAIL (Medium) |

---

## 3-4. Rate Limit / Bruteforce 방어

### 확인 포인트

1. **인증 엔드포인트 보호**
   ```
   패턴: rateLimit|rate-limit|Ratelimit|throttle|limiter
   글로브: middleware.*, **/api/auth/**/*.{ts,js}
   ```
   - 로그인, 회원가입, 비밀번호 재설정에 Rate Limit 적용
   - IP 기반 + 계정 기반 이중 제한 권장

2. **일반 API 보호**
   - 비용이 큰 API (LLM 호출, 파일 생성 등)에 제한
   - 429 응답에 Retry-After 헤더 포함

3. **Account Lockout**
   - 연속 로그인 실패 시 계정 잠금 또는 지연
   - Supabase Auth 사용 시: Supabase가 자체 Rate Limit 제공 → 커스텀 인증에만 해당

### 판정

| 상황 | 판정 |
|------|------|
| 인증 엔드포인트에 Rate Limit 적용 | PASS |
| 인증 엔드포인트에 Rate Limit 없음 | FAIL (High) |
| 비용 큰 API에 Rate Limit 없음 | FAIL (Medium) |
| Supabase Auth만 사용 (커스텀 인증 없음) | PASS (인증 부분) |

**`deploy-safety-guard` Step 4 교차참조:** 비용 통제 관점의 Rate Limit은 deploy-safety-guard에서 다룸. 여기서는 보안(Bruteforce 방어) 관점만 확인.

---

## 3-5. Audit Log

### 확인 포인트

1. **민감 작업 기록 범위**
   ```
   패턴: audit|log.*action|activity.*log|event.*log
   글로브: *.{ts,js}
   ```
   최소 기록 대상:
   - 로그인/로그아웃
   - 권한 변경 (역할 부여/제거)
   - 데이터 삭제
   - 설정 변경
   - 관리자 작업

2. **로그 무결성**
   - 로그가 변조 불가능한 저장소에 기록되는가? (별도 DB, 외부 서비스)
   - 로그에 민감 정보 (비밀번호, 토큰) 미포함 확인

3. **보존 기간**
   - 법적 요구사항에 따른 보존 기간 설정
   - 자동 정리(retention policy) 구현

### 판정

| 상황 | 판정 |
|------|------|
| 민감 작업 Audit Log + 변조 방지 | PASS |
| 로그 존재하나 변조 방지 없음 | FAIL (Medium) |
| Audit Log 미구현 | FAIL (High) — MVP 단계에서는 Medium |
| 로그에 민감 정보 포함 | FAIL (High) |

---

## 3-6. Secret 관리 + Rotation

### 확인 포인트

1. **저장 방식**
   - 환경변수 또는 Secret Manager (AWS SM, Vault) 사용
   - 코드 내 하드코딩 → L1에서 이미 검출

2. **교체 전략**
   - API 키, DB 비밀번호의 정기 교체 계획
   - JWT signing key 교체 시 기존 토큰 처리 방안
   - Supabase: 프로젝트 키 교체 프로세스

3. **만료 정책**
   - API 키에 만료일 설정
   - 서비스 계정 비밀번호 교체 주기

### 판정

| 상황 | 판정 |
|------|------|
| 환경변수 + Secret Manager + 교체 계획 | PASS |
| 환경변수만 사용, 교체 계획 없음 | FAIL (Medium) |
| 하드코딩 | FAIL (Critical) — L1에서 검출됨 |

**`deploy-safety-guard` Step 2 교차참조:** 환경변수 검증 패턴(Fail-Fast)은 deploy-safety-guard에서 다룸. 여기서는 보안(노출, 교체) 관점만 확인.

---

## 3-7. Privacy / 데이터 최소수집

### 확인 포인트

1. **PII 수집 범위**
   ```
   패턴: email|phone|address|birth|ssn|주민|생년|전화|주소
   글로브: **/api/**/*.{ts,js}, **/route.{ts,js}
   ```
   - 비즈니스에 필요한 최소 PII만 수집하는가?
   - 수집 목적이 명확한가?

2. **데이터 삭제권**
   - 사용자 계정 삭제 시 관련 데이터 완전 삭제
   - 삭제 API 또는 관리 도구 존재
   ```
   패턴: delete.*user|remove.*account|gdpr|탈퇴|삭제
   글로브: *.{ts,js}
   ```

3. **암호화 저장**
   - PII가 DB에 암호화되어 저장되는가?
   - 최소 전송 중 암호화 (HTTPS) 확보

4. **개인정보 처리방침**
   - 서비스에 개인정보 처리방침 페이지 존재
   ```
   글로브: **/privacy/**,**/privacy-policy/**
   패턴: privacy|개인정보
   글로브: *.{tsx,jsx}
   ```

### 판정

| 상황 | 판정 |
|------|------|
| 최소 수집 + 삭제 기능 + 암호화 + 방침 존재 | PASS |
| PII 과다 수집 (불필요한 필드) | FAIL (Medium) |
| 계정 삭제 시 데이터 미삭제 (soft delete만) | FAIL (Medium) |
| 개인정보 처리방침 미존재 | FAIL (High) — 법적 요구사항 |
| PII 평문 저장 + 접근 제한 없음 | FAIL (High) |

---

## 3-8. Software Integrity (OWASP A08)

### 확인 포인트

1. **SRI (Subresource Integrity)**
   ```
   # CDN 스크립트에 integrity 속성 확인
   패턴: <script.*src=.*cdn|<link.*href=.*cdn
   글로브: *.{html,tsx,jsx}
   ```
   - CDN에서 로드하는 스크립트/스타일에 `integrity` 속성 존재 여부

2. **lockfile 커밋 및 무결성**
   - package-lock.json / pnpm-lock.yaml이 git에 커밋되어 있는가?
   - `npm ci` (lockfile 기반 설치) 사용 여부 확인

3. **CI/CD 파이프라인 보안**
   - 빌드 스크립트에 외부 스크립트 직접 다운로드 실행 없음
   - 의존성 설치에 검증된 레지스트리(npmjs.org) 사용

### 판정

| 상황 | 판정 |
|------|------|
| lockfile 커밋 + CI에서 `npm ci` 사용 | PASS |
| lockfile 없음 | FAIL (High) |
| CDN 스크립트에 SRI 없음 | FAIL (Medium) |
| CI/CD에서 외부 스크립트 무검증 실행 | FAIL (Critical) |

---

## 3-9. Security Monitoring & Alerting (OWASP A09 보강)

> 3-5(Audit Log)가 보안 이벤트 **기록**이라면, 3-9는 **탐지 및 알림**에 집중.

### 확인 포인트

1. **보안 이벤트 알림**
   ```
   패턴: alert|notify|sendAlert|webhook.*security|Slack.*alert
   글로브: *.{ts,js}
   ```
   - 반복 로그인 실패, 비정상 트래픽, 권한 에러 급증 시 알림 존재 여부

2. **이상 징후 탐지**
   - Rate Limit 초과 이벤트 기록 및 알림
   - 짧은 시간 내 다수 계정 접근 시도 탐지

3. **모니터링 통합**
   - Sentry, Datadog, CloudWatch 등 보안 이벤트 채널 분리 여부

### 판정

| 상황 | 판정 |
|------|------|
| 보안 이벤트 → 실시간 알림 채널 존재 | PASS |
| 로그만 있고 알림 없음 | FAIL (Medium) |
| 보안 이벤트 모니터링 전무 | FAIL (High) |
| MVP 단계 (Sentry 기본 설정만) | FAIL (Low) — 성장 단계에서 High |

---

## 3-10. Insecure Design Patterns (OWASP A04)

### 확인 포인트

1. **Business Logic Flaw**
   - 가격 조작 가능성: 클라이언트에서 가격/금액 전달 → 서버 검증 없이 결제 처리
   - 수량 음수 입력: 장바구니에 음수 수량 입력 시 처리 방식
   - 쿠폰/할인 중복 적용: 동일 쿠폰 반복 적용 방지 여부
   ```
   패턴: (?:price|amount|quantity|coupon|discount).*(?:req\.body|body|input)
   글로브: **/api/**/*.{ts,js}, **/route.{ts,js}
   ```

2. **Race Condition (TOCTOU)**
   - 트랜잭션 없이 Check → Use 패턴 (잔액 확인 후 차감)
   - Supabase: 트랜잭션 또는 RPC + DB 제약 조건 사용 여부

3. **보안 설계 검토**
   - 비밀번호 재설정 토큰: 단방향 해시 저장, 만료 시간 설정
   - 이메일 인증 없이 계정 활성화 가능 여부

### 판정

| 상황 | 판정 |
|------|------|
| 서버에서 가격/재고 재검증 후 처리 | PASS |
| 클라이언트 전달 가격을 검증 없이 결제 처리 | FAIL (Critical) |
| 음수 수량 허용 | FAIL (High) |
| Race condition 취약 트랜잭션 | FAIL (High) |
| 쿠폰 중복 적용 방지 없음 | FAIL (Medium) |
