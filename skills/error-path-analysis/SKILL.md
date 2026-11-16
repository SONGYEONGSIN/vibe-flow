---
name: error-path-analysis
description: |
  구현된 코드에서 유저가 에러를 만났을 때의 경험을 진단할 때 사용.
  트리거: "에러 경로 분석", "에러 핸들링 점검", "실패 시나리오", "에러 UX", "에러 메시지 품질",
  "빈 상태 점검", "에러 바운더리", "오프라인 대응", empty state, error boundary, offline handling.
---

# Error Path Analysis

구현된 코드를 기반으로 유저가 에러를 만났을 때의 경험을 체계적으로 진단한다.
**핵심 관점**: "인프라 resilience"도 "코드 품질"도 아닌, **유저가 에러를 만났을 때의 경험**.

5-Phase: Dependency Mapping → Failure Enumeration → Handling Audit → UX Gap → Report

---

## Phase 1: Dependency Mapping

유저 액션별 외부 의존성을 역추적한다.

### 1-1. 프로젝트 구조 스캔

```bash
# 라우트/페이지 파악
find . -type f \( -name "*.tsx" -o -name "*.ts" \) | grep -E "(page|route|api)" | head -50

# API 호출 패턴 탐색
grep -r "fetch\|axios\|supabase\|prisma\|trpc" --include="*.ts" --include="*.tsx" -l
```

### 1-2. 유저 액션별 의존성 매핑 테이블

| 유저 액션 | 트리거 컴포넌트 | 외부 의존성 | 의존성 유형 |
|----------|--------------|------------|------------|
| 로그인 | `LoginForm` | Supabase Auth | 인증 |
| 파일 업로드 | `FileUpload` | Storage API | 파일 시스템 |
| 결제 | `CheckoutForm` | Stripe | 결제 |
| 데이터 조회 | `DataTable` | REST API | HTTP |

**의존성 유형 분류**: 인증 / 데이터 API(REST·GraphQL·tRPC) / 파일 / 결제 / 실시간(WebSocket·SSE) / 외부 서비스(이메일·SMS·AI) / 브라우저 API(Clipboard·Camera·Geolocation) / 인프라(CDN·이미지 서버)

---

## Phase 2: Failure Enumeration

Phase 1에서 식별된 각 의존성에 대해 실패 시나리오를 체계적으로 열거한다.

### 내장 실패 시나리오 카탈로그

#### HTTP / REST API

| 시나리오 | 상태코드 | 발생 빈도 |
|---------|---------|----------|
| 네트워크 단절 | `TypeError: Failed to fetch` | 높음 |
| 요청 타임아웃 | timeout / 504 | 중간 |
| 서버 에러 | 500, 502, 503 | 낮음 |
| 클라이언트 에러 | 400 Bad Request | 높음 |
| 인증 만료 | 401 Unauthorized | 높음 |
| 권한 없음 | 403 Forbidden | 중간 |
| 리소스 없음 | 404 Not Found | 중간 |
| Rate Limit 초과 | 429 Too Many Requests | 낮음 |
| CORS 차단 | CORS error | 낮음 |

#### 인증

| 시나리오 | 트리거 |
|---------|-------|
| 토큰 만료 (access token) | 세션 장기간 유지 |
| Refresh token 만료 | 장기 미사용 |
| 소셜 로그인 팝업 차단 | 팝업 블로커 |
| OAuth 콜백 오류 | redirect_uri 불일치 |
| 계정 비활성화 | 관리자 차단 |
| 이메일 미인증 | 가입 후 이메일 확인 전 |

#### 파일 업로드

| 시나리오 | 원인 |
|---------|------|
| 파일 크기 초과 | quota/limit 설정 |
| 허용되지 않은 파일 형식 | MIME type 검증 |
| 업로드 중 네트워크 단절 | 대용량 파일 |
| 스토리지 용량 초과 | 서버 quota |

#### 결제

| 시나리오 | 심각도 |
|---------|-------|
| 카드 거절 | 치명적 |
| 결제 타임아웃 | 치명적 |
| 중복 결제 요청 | 치명적 |
| 웹훅 전달 실패 | 높음 |

#### 브라우저 API

| API | 실패 시나리오 |
|-----|-------------|
| Clipboard | 권한 거부, HTTPS 아님 |
| Camera/Mic | 권한 거부, 하드웨어 없음 |
| Geolocation | 권한 거부, 위치 서비스 꺼짐 |
| IndexedDB | 용량 초과, Private Mode |

---

## Phase 3: Handling Audit

Phase 2에서 열거된 각 시나리오에 대해 실제 핸들링 코드가 존재하는지 확인한다.

### 3-1. 코드 탐색 패턴

```bash
grep -rn "try {" --include="*.ts" --include="*.tsx" .
grep -rn "\.catch(" --include="*.ts" --include="*.tsx" .
grep -rn "ErrorBoundary\|error-boundary" --include="*.tsx" .
grep -rn "isError\|isLoading\|error:" --include="*.tsx" .
grep -rn "401\|unauthorized\|Unauthorized" --include="*.ts" --include="*.tsx" .
grep -rn "\.safeParse\|ZodError" --include="*.ts" --include="*.tsx" .
```

### 3-2. 핸들링 수준 평가

| 수준 | 설명 | 예시 |
|------|------|------|
| **없음** | 에러 미처리 | `await fetch(url)` — catch 없음 |
| **기본** | 에러 캐치만 | `catch (e) { console.error(e) }` |
| **중간** | 상태 반영 | `setError(e.message)` |
| **양호** | 유저에게 표시 | `<ErrorMessage>` 컴포넌트 |
| **우수** | 복구 경로 제공 | 재시도 버튼, 대안 제시 |

### 3-3. 시나리오별 핸들링 매핑 테이블

| 시나리오 | 핸들링 존재 | 수준 | 파일:라인 |
|---------|-----------|------|---------|
| 네트워크 단절 | O/X | — | `api/client.ts:45` |
| 401 토큰 만료 | O/X | — | — |

---

## Phase 4: UX Gap Analysis

Phase 2 시나리오 vs Phase 3 핸들링 대조 → 갭 식별.

### 4-1. 6가지 에러 UX 차원 평가

| 차원 | 평가 질문 |
|------|---------|
| **Empty State** | 데이터 없을 때 표시 내용이 있는가? 첫 사용자와 검색 결과 없음을 구분하는가? |
| **Error State** | 에러 메시지가 기술 용어인가, 사람 언어인가? 원인과 해결 방법을 제시하는가? |
| **Loading/Timeout** | 스피너/스켈레톤이 있는가? 타임아웃 후 알림이 있는가? |
| **Fallback UI** | Error Boundary가 있는가? 전체 크래시 vs 부분 격리가 되는가? |
| **Retry** | 재시도 버튼이 있는가? 자동 재시도 로직이 있는가? |
| **Offline** | 오프라인 감지가 있는가? 오프라인 중 데이터를 보존하는가? |

### 4-2. 에러 메시지 품질 평가

| 기준 | 나쁜 예 | 좋은 예 |
|------|--------|--------|
| **명확성** | "오류가 발생했습니다" | "파일 크기가 10MB를 초과합니다" |
| **행동 유도** | "다시 시도하세요" | "다시 시도" 버튼 제공 |
| **톤** | "ERROR: 401" | "로그인이 만료되었습니다" |
| **복구 가능성** | 에러만 표시 | 대안 경로 제시 |

### 4-3. 갭 심각도 분류

| 심각도 | 기준 | 예시 |
|-------|------|------|
| **P0** | 유저가 완전히 막히거나 데이터 손실 | 결제 실패 시 아무 안내 없음 |
| **P1** | 주요 기능 이용 불가, 핸들링 없음 | 로그인 실패 시 침묵 |
| **P2** | 기능은 되나 UX 나쁨 | 에러 메시지가 기술적 용어 |
| **P3** | 개선하면 좋은 것 | 빈 상태에 일러스트 없음 |

---

## Phase 5: Report

### 우선순위 매트릭스

```
발생빈도
  높음 │ P1       │ P0       │
       │──────────┼──────────│
  낮음 │ P3       │ P1       │
       └──────────┴──────────┘
          낮음           높음
                심각도
```

### 최종 리포트 형식

```markdown
## 에러 경로 분석 결과

### 요약
- 분석 범위: [유저 액션 수]개 액션, [의존성 수]개 외부 의존성
- 식별된 실패 시나리오: [총 수]개 / 핸들링 없는 시나리오: [수]개 ([비율]%)
- P0/P1 이슈: [수]개

### P0 — 즉시 수정

| 시나리오 | 현재 상태 | 영향 | 권장 수정 |
|---------|---------|------|---------|

### P1 — 다음 스프린트

| 시나리오 | 현재 상태 | 권장 수정 |
|---------|---------|---------|

### UX 갭 요약

| 차원 | 현재 수준 | 주요 이슈 |
|------|---------|---------|
| Empty State | 없음/기본/양호 | |

### 핵심 권장 사항

1. **[즉시]** [설명]
2. **[단기]** [설명]
3. **[장기]** [설명]
```

---

## Anti-patterns (P1 이상 자동 분류)

- **빈 catch 블록**: `catch (e) {}` — 에러 삼키기
- **console.error만**: 유저에게 아무것도 표시 안 함
- **무한 로딩**: 에러 시 스피너가 계속 돌아감
- **전체 페이지 크래시**: Error Boundary 없이 렌더링 에러 전파
- **기술적 에러 노출**: HTTP 상태코드, 스택 트레이스 그대로 표시
- **재시도 불가**: 에러 후 새로고침 외 방법 없음

---

## Troubleshooting

**의존성을 찾기 어려울 때**: `package.json` dependencies → `.env.example` 외부 서비스 키 → `lib/`, `services/` 디렉토리 우선 탐색

**핸들링이 암묵적일 때**: React Query `useQuery` → `isError`, `error` 자동 제공 / Next.js `error.tsx`, `not-found.tsx` 파일 존재 확인

---

## 기존 도구와의 관점 차이

| 도구 | 관점 | 이 스킬과의 차이 |
|------|------|----------------|
| `deploy-safety-guard` Step 3 | 인프라 resilience (timeout, backoff) | 유저에게 보이는 결과까지 추적 |
| `architecture-reviewer` Phase 2 | 코드 품질 pass/fail | 구체적 시나리오별 핸들링 대조 |
| `security-audit` 2-9 | 스택 트레이스 노출 (보안) | UX 관점 에러 메시지 품질 |
| `silent-failure-hunter` | PR diff 내 빈 catch | 전체 코드베이스 + 유저 경험 포함 |
