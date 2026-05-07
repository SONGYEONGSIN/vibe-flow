# Delegation Patterns

오케스트레이터가 서브에이전트에 작업을 위임할 때의 패턴과 모범 사례.

---

## 위임 프롬프트 7섹션 구조

모든 위임은 반드시 7개 섹션을 포함해야 한다.

### 섹션 설명

| # | 섹션 | 설명 | 예시 |
|---|------|------|------|
| 1 | TASK | 원자적, 구체적 목표 | "로그인 폼에 이메일 검증 추가" |
| 2 | EXPECTED OUTCOME | 구체적 산출물 + 성공 기준 | "isValidEmail() 함수 + 테스트 3개" |
| 3 | REQUIRED SKILLS | 사용할 스킬/도구 | "test-driven-development 스킬" |
| 4 | REQUIRED TOOLS | 도구 허용 목록 | "Read, Edit, Bash(npm test)" |
| 5 | MUST DO | 반드시 해야 할 것 | "기존 validation 패턴 따르기" |
| 6 | MUST NOT DO | 절대 하지 말 것 | "다른 파일 수정 금지" |
| 7 | CONTEXT | 파일 경로, 기존 패턴, 제약 | "src/utils/validation.ts 참조" |

### Before (불충분한 위임)

```
Task(prompt="로그인 폼에 이메일 검증 추가해줘")
```

**문제:** 어디에? 어떤 패턴으로? 테스트는? 다른 파일 건드려도 되나?

### After (완전한 위임)

```
Task(subagent_type="general-purpose", model="sonnet", prompt="
1. TASK: src/components/LoginForm.tsx의 이메일 input에 클라이언트 검증 추가
2. EXPECTED OUTCOME:
   - src/utils/validation.ts에 isValidEmail() 함수
   - LoginForm.tsx에서 submit 시 검증, 에러 메시지 표시
   - 테스트 파일 src/utils/validation.test.ts 생성 (3개 이상 케이스)
3. REQUIRED SKILLS: test-driven-development
4. REQUIRED TOOLS: Read, Edit, Write, Bash(npm test만)
5. MUST DO:
   - src/utils/validation.ts의 기존 검증 함수 패턴 따르기
   - 에러 메시지는 한국어
   - TDD: 테스트 먼저 작성 후 구현
6. MUST NOT DO:
   - LoginForm.tsx 외 컴포넌트 수정 금지
   - 패키지 설치 금지
   - 정규식 라이브러리 사용 금지
7. CONTEXT:
   - 기존 패턴: src/utils/validation.ts의 isValidPhone() 참조
   - 에러 표시: FormError 컴포넌트 사용 (src/components/FormError.tsx)
   - 테스트: vitest 사용, npm test로 실행
")
```

---

## 위임 패턴 유형

### Pattern 1: 탐색 위임 (Explore)

코드베이스 조사, 패턴 파악, 정보 수집.

```
Task(subagent_type="Explore", model="haiku", run_in_background=true,
prompt="
1. TASK: 프로젝트의 인증 관련 구현 파악
2. EXPECTED OUTCOME:
   - 인증 관련 파일 목록 (경로 + 역할)
   - 사용 중인 인증 라이브러리/패턴
   - 세션 관리 방식
   - 미들웨어/가드 구현 위치
3. REQUIRED TOOLS: Read, Grep, Glob
4. MUST DO: 파일 경로와 줄 번호 포함
5. MUST NOT DO: 코드 수정 금지, 제안만
6. CONTEXT: Next.js App Router + Supabase 프로젝트
")
```

**핵심:** 항상 `run_in_background=true`, 탐색 결과를 기다리지 않고 다른 작업 병행.

### Pattern 2: 구현 위임 (Implement)

실제 코드 작성, 수정, 테스트.

```
Task(subagent_type="general-purpose", model="sonnet",
prompt="
1. TASK: /api/users/[id] DELETE 엔드포인트 구현
2. EXPECTED OUTCOME:
   - app/api/users/[id]/route.ts에 DELETE 핸들러
   - Supabase에서 soft delete (deleted_at 설정)
   - 204 응답 (성공), 404 (미존재), 401 (미인증)
3. REQUIRED SKILLS: supabase-edge-functions
4. REQUIRED TOOLS: Read, Edit, Write, Bash
5. MUST DO:
   - 기존 GET 핸들러 패턴 따르기 (같은 파일)
   - RLS 정책 확인 (본인 데이터만 삭제 가능)
   - Zod로 path params 검증
6. MUST NOT DO:
   - 실제 레코드 삭제 (hard delete) 금지
   - migration 파일 생성 금지
7. CONTEXT:
   - DB 스키마: users 테이블에 deleted_at nullable timestamp 있음
   - 인증: middleware.ts의 withAuth() 미들웨어 사용
   - 참고: app/api/posts/[id]/route.ts의 DELETE 구현
")
```

### Pattern 3: 검증 위임 (Verify)

코드 리뷰, 품질 검증, 보안 점검.

```
Task(subagent_type="general-purpose", model="opus",
prompt="
VERIFY COMPLETION:
Original task: 사용자 프로필 수정 기능 구현
What was implemented:
- app/api/users/[id]/route.ts: PATCH 핸들러
- components/ProfileEditForm.tsx: 수정 폼
- actions/updateProfile.ts: Server Action

Files changed:
- app/api/users/[id]/route.ts (수정)
- components/ProfileEditForm.tsx (신규)
- actions/updateProfile.ts (신규)

Verification done:
- npm run build: 성공
- npm test: 47/47 통과
- TypeScript: 에러 없음

Please verify:
1. Does this FULLY address the original request?
2. Any obvious bugs or issues?
3. Any missing edge cases?
4. Code quality acceptable?
5. Security concerns?

Return: APPROVED or REJECTED with specific reasons.
")
```

### Pattern 4: 리서치 위임 (Research)

외부 정보 조사, 최신 문서 확인.

```
Task(subagent_type="general-purpose", model="sonnet", run_in_background=true,
prompt="
1. TASK: Next.js 15의 Server Actions 보안 모범 사례 조사
2. EXPECTED OUTCOME:
   - CSRF 보호 기본 제공 여부
   - 입력 검증 패턴
   - Rate limiting 방법
   - 인증 확인 패턴
   - 에러 핸들링 모범 사례
3. REQUIRED TOOLS: WebSearch, WebFetch
4. MUST DO: 공식 문서 기반 정보만 포함
5. MUST NOT DO: 추측이나 검증되지 않은 정보 포함 금지
")
```

---

## 병렬 실행 전략

### 독립 작업 병렬화

```
// CORRECT: 독립적인 작업은 단일 메시지에서 병렬 호출
Task(subagent_type="Explore", model="haiku", prompt="인증 구현 파악...")
Task(subagent_type="Explore", model="haiku", prompt="에러 핸들링 패턴 파악...")
Task(subagent_type="general-purpose", model="sonnet", prompt="외부 API 보안 조사...")

// WRONG: 순차적으로 하나씩 기다림
result1 = Task(...)
result2 = Task(...)  // result1 완료 후 실행
```

### 의존적 작업 순차화

```
// Phase 1: 탐색 (병렬)
Task(explore1)
Task(explore2)

// Phase 2: 탐색 결과 기반 설계 (순차 - Phase 1 완료 후)
Task(architect, context=explore_results)

// Phase 3: 설계 기반 구현 (병렬)
Task(implement_frontend)
Task(implement_backend)
Task(implement_tests)

// Phase 4: 검증 (순차 - Phase 3 완료 후)
Task(verify)
```

---

## 에러 복구 패턴

### 3회 실패 후 에스컬레이션

```
cycle = 0
while cycle < 3:
  result = Task(implement)
  if result.success:
    break
  cycle++
  Task(diagnose, context=result.error)

if cycle >= 3:
  // Architect에 에스컬레이션
  Task(model="opus", prompt="3회 구현 실패. 근본 원인 분석 필요...")
  // 또는 사용자에게 판단 요청
  AskUserQuestion("3회 시도 실패. 접근 방식을 변경할까요?")
```

### 부분 성공 처리

```
// Promise.allSettled 스타일
results = [Task(a), Task(b), Task(c)]

fulfilled = results.filter(r => r.success)
rejected = results.filter(r => !r.success)

if rejected.length > 0:
  // 실패한 작업만 재시도 또는 다른 접근
  for task in rejected:
    Task(retry, context=task.error)
```

---

## 비용 최적화

### 모델 선택 매트릭스

| 작업 유형 | 모델 | 비용/1K tokens | 사용 사례 |
|----------|------|:-----------:|----------|
| 파일 탐색 | haiku | $0.25 | Grep, Glob, 간단한 Read |
| 패턴 분석 | haiku | $0.25 | 코드 패턴 파악, 목록 생성 |
| 기능 구현 | sonnet | $3.00 | 코드 작성, 테스트, 수정 |
| 코드 리뷰 | sonnet | $3.00 | 품질 검증, 버그 탐지 |
| 아키텍처 | opus | $15.00 | 복잡한 설계, 최종 검증 |
| 디버깅 | opus | $15.00 | 난해한 버그, 레이스 컨디션 |

### 비용 절감 팁

1. **탐색은 항상 haiku** - 파일 찾기에 opus 사용 금지
2. **Background 실행** - 결과를 당장 안 쓰면 background
3. **프롬프트 최소화** - 불필요한 컨텍스트 제거
4. **캐싱** - 같은 탐색 2번 하지 않기
5. **범위 제한** - "전체 분석" 대신 "src/auth/ 분석"

---

## 위임 실패 진단

| 증상 | 원인 | 해결 |
|------|------|------|
| 엉뚱한 결과 | TASK가 모호 | 구체적 산출물 명시 |
| 과도한 수정 | MUST NOT DO 누락 | 수정 범위 명시적 제한 |
| 패턴 불일치 | CONTEXT 부족 | 참조 파일 경로 포함 |
| 테스트 미작성 | REQUIRED SKILLS 누락 | TDD 스킬 명시 |
| 무한 루프 | 종료 조건 없음 | 최대 시도 횟수 설정 |
| 토큰 낭비 | 과도한 탐색 | 범위 제한, haiku 사용 |

---

## 체크리스트

위임 전 확인:
- [ ] 7섹션 모두 작성
- [ ] 모델 명시적으로 선택 (haiku/sonnet/opus)
- [ ] 독립 작업은 병렬 호출
- [ ] 산출물 형식 구체화
- [ ] 수정 범위 제한 (MUST NOT DO)
- [ ] 참조 파일 경로 포함 (CONTEXT)
- [ ] 실패 시 복구 계획 수립
