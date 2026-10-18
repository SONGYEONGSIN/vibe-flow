---
name: site-auditor
description: This skill should be used for comprehensive site auditing that combines performance, design, SEO, backend safety, and security checks in one run. Use when the user requests "전체 점검", "사이트 검증", "배포 전 종합 점검", "audit", or wants to run all checks before deployment.
user-invocable: true
---

# Site Auditor

performance-checker, web-design-guidelines, seo-master, deploy-safety-guard, security-audit를 **병렬로** 실행하는 통합 점검 스킬.

---

## Workflow

실행 전 프로젝트 루트를 확인하고, `package.json` 존재 여부로 프로젝트 타입을 파악한다.

### Step 1: 5개 Phase를 Task 도구로 동시 호출

Phase 간 의존성이 없으므로 **반드시 하나의 메시지에서 5개 Task를 병렬로 호출**한다.

```
단일 메시지에서 동시에 5개 Task 호출:

Task(subagent_type="general-purpose", name="performance-checker", run_in_background=true)
Task(subagent_type="general-purpose", name="ui-accessibility-checker", run_in_background=true)
Task(subagent_type="general-purpose", name="seo-checker", run_in_background=true)
Task(subagent_type="general-purpose", name="backend-safety-checker", run_in_background=true)
Task(subagent_type="security-specialist", name="security-auditor", run_in_background=true)
```

각 에이전트에게 전달할 프롬프트는 아래 Phase 설명을 포함한다.

### Phase 1: Performance Check (에이전트 프롬프트)

`~/.claude/skills/performance-checker/SKILL.md`를 읽고, Workflow 섹션에 정의된 단계를 실행한다:
- 빌드 검증 (`next build` 또는 해당 빌드 명령어)
- 번들 크기 분석 (`@next/bundle-analyzer` 또는 빌드 출력 파싱)
- 파일 무결성 점검 (깨진 import, 미사용 파일 검출)
- 코드 품질 확인 (lint, TypeScript 에러)

결과 형식:
```
{ score: number, issues: string[], critical: string[], warnings: string[] }
```

에러 처리: 빌드 실패 시 `{ score: 0, critical: ["Build verification failed"] }`로 기록.

---

### Phase 2: UI/Accessibility Check (에이전트 프롬프트)

`~/.claude/skills/web-design-guidelines/SKILL.md`를 읽고, Rules 섹션의 100+ 규칙을 기반으로 검증한다:
- 접근성: alt 속성, outline, 키보드 네비게이션, ARIA 라벨
- 폼: label 연결, autocomplete, 에러 메시지
- 애니메이션: prefers-reduced-motion, transition 값
- 색상/대비: WCAG AA 4.5:1 기준
- 성능: virtualization, font-display, lazy loading
- React/Next.js 패턴: hydration 불일치, key prop

대상: `app/` 또는 `src/` 디렉토리 내 `.tsx`, `.jsx` 파일. 위반 항목을 `file:line` 형식으로 수집.

결과 형식:
```
{ score: number, violations: Array<{ rule, file, line, severity }>, critical: string[], warnings: string[] }
```

에러 처리: 소스 파일 없을 시 `{ score: 0, issues: ["No source files found"] }`로 기록.

---

### Phase 3: SEO Check (에이전트 프롬프트)

`~/.claude/skills/seo-master/SKILL.md`를 읽고, 체크리스트를 기반으로 검증한다:
- 메타데이터: title, description, viewport 설정
- OG 이미지: og:image, twitter:card 설정
- sitemap/robots: `public/sitemap.xml`, `public/robots.txt` 존재
- 구조화 데이터: JSON-LD 스키마 확인
- favicon: `app/favicon.ico` 또는 `public/favicon.ico`

상세 참조: `references/seo-checklist.md`, `references/technical-seo.md`, `references/io-optimization.md`, `references/advanced-json-ld.md`

결과 형식:
```
{ score: number, issues: string[], critical: string[], warnings: string[] }
```

에러 처리: Next.js가 아닌 경우 기본 HTML SEO 항목만 점검, 해당 없는 항목은 skip.

---

### Phase 4: Backend Safety Check (에이전트 프롬프트)

`~/.claude/skills/deploy-safety-guard/SKILL.md`를 읽고, 5단계 점검을 실행한다:
- Step 1: 가시성 확보 (Sentry 연동 확인)
- Step 2: 환경변수 검증 (t3-env, .env.example)
- Step 3: 가용성 가드레일 (Timeout, 재시도)
- Step 4: 자원/비용 통제 (Rate Limit, Idempotency)
- Step 5: LLM 토큰 관리 (max_tokens, 입력 검증)

상세 참조: `references/observability.md`, `references/env-validation.md`, `references/resilience.md`, `references/rate-limiting.md`, `references/token-management.md`

결과 형식:
```
{ score: number, issues: string[], critical: string[], warnings: string[] }
```

에러 처리: Supabase CLI 미설치 등 해당 없는 항목은 "N/A"로 기록, 점수에서 제외.

---

### Phase 5: Security Audit (에이전트 프롬프트)

다음 4개 파일을 순서대로 읽고 3-Layer 보안 감사를 실행한다:
1. `~/.claude/skills/security-audit/SKILL.md` — 워크플로우 및 등급 기준
2. `~/.claude/skills/security-audit/references/layer1-auto-scan.md` — L1 상세 패턴
3. `~/.claude/skills/security-audit/references/layer2-code-review.md` — L2 Grep 패턴
4. `~/.claude/skills/security-audit/references/layer3-architecture.md` — L3 체크리스트

references 파일 없이는 Grep 패턴이 없어 형식적 감사에 그침 — 반드시 읽을 것.

- Layer 1: 자동 스캔 (의존성 취약점, Secret 노출, 보안헤더, 위험 패턴, .env 추적, HTTPS, 클라이언트 번들 Secret, Supply Chain, 어드민 페이지 열거)
- Layer 2: 코드 리뷰 (XSS, SQLi, CSRF, CORS, SSRF, 파일업로드, Open Redirect, Mass Assignment, 에러 노출, Cookie/세션, Cryptography, Deserialization, IDOR, Prototype Pollution, Server Actions, LLM Prompt Injection)
- Layer 3: 아키텍처 리뷰 (AuthN/AuthZ, RBAC/테넌트격리, 최소권한, Rate Limit, Audit Log, Secret Rotation, Privacy, Software Integrity, Security Monitoring, Insecure Design)

결과 형식:
```
{ grade: "A"~"F", layers: { l1: { passed: N, total: 9 }, l2: { passed: N, total: 16 }, l3: { passed: N, total: 10 } }, critical: string[], high: string[], medium: string[], low: string[] }
# Note: 1-9(어드민 페이지 열거)는 열거 전용이므로 passed 카운트에서 제외 (N/A와 동일 처리)
```

에러 처리: 해당 없는 항목(파일업로드 없음, 멀티테넌트 아님 등)은 N/A로 기록, 총 항목 수에서 제외.

**Note:** Phase 4(Backend Safety)와 Rate Limit, Secret 관련 항목이 관점 다르게 중복될 수 있음. 리포트 통합 시 교차참조 표기.

### Step 2: 결과 수집

5개 에이전트가 모두 완료되면 각 결과를 수집한다. `TaskOutput`으로 백그라운드 에이전트 결과를 확인.

---

## 통합 리포트 생성

모든 Phase 완료 후, 결과를 통합하여 최종 리포트를 작성한다.

### 점수 산출

| Phase | 만점 | 산출 방식 |
|-------|------|----------|
| Performance | 25점 | phase1_result.score / 4 |
| UI/Accessibility | 25점 | 위반 수 기반 감점 |
| SEO | 25점 | 체크리스트 충족률 |
| Backend Safety | 25점 | phase4_result.score / 2 |
| **합계** | **100점** | |

### 등급 기준

| 등급 | 점수 범위 | 판정 |
|------|----------|------|
| A | 90-100 | 배포 권장 |
| B | 70-89 | 배포 가능 (권장 조치 있음) |
| C | 50-69 | 배포 주의 (개선 필요) |
| D | 30-49 | 배포 비권장 |
| F | 0-29 | 배포 차단 |

### 우선순위 분류

1. **긴급 (배포 차단):** 모든 Phase의 `critical` 항목 통합
2. **권장 (1주 내):** 모든 Phase의 `warnings` 중 보안/접근성 관련
3. **개선 (점진적):** 나머지 `warnings`

### 리포트 템플릿

```markdown
# Site Audit Report

**프로젝트:** {project_name (package.json의 name 필드)}
**점검일:** {YYYY-MM-DD}
**종합 등급:** {A/B/C/D/F} ({총점}/100)

---

## 1. Performance ({phase1 점수}/25)
{phase1 결과 요약}

## 2. UI/Accessibility ({phase2 점수}/25)
{phase2 결과 요약 - 상위 10개 위반 항목}

## 3. SEO ({phase3 점수}/25)
{phase3 결과 요약}

## 4. Backend Safety ({phase4 점수}/25)
{phase4 결과 요약}

**종합 점수: {총점}/100**

---

## 5. Security Audit (별도 등급: {A~F})

> 기존 100점 체계와 독립. security-audit 스킬 자체 등급 기준 적용.

### Layer 1: 자동 스캔 ({N}/9 통과)
{phase5 L1 결과}

### Layer 2: 코드 리뷰 ({N}/16 통과)
{phase5 L2 결과 — 상위 항목}

### Layer 3: 아키텍처 리뷰 ({N}/10 통과)
{phase5 L3 결과}

**Phase 4와 겹치는 항목:** Rate Limit(비용 vs 보안), Secret(검증 vs 노출) — 관점 차이 교차참조

---

## 긴급 조치 (배포 전 필수)
{모든 Phase(1~5)의 critical 항목 통합 목록}

## 권장 조치 (1주 내)
{보안/접근성 관련 warnings}

## 개선 사항 (점진적)
{나머지 warnings}
```

---

## Notes

- 각 스킬의 상세 워크플로우는 해당 스킬의 SKILL.md 참조
- 개별 스킬 수정 시 이 통합 점검에도 자동 반영됨
- 특정 Phase만 실행하려면 개별 스킬을 직접 호출 (e.g., `/seo-master`)
- Phase 간 의존성 없음: 어느 Phase가 실패해도 나머지는 계속 진행

---

## Troubleshooting

| 문제 | 원인 | 해결 |
|------|------|------|
| 점수가 비정상적으로 낮음 | 빌드 실패 시 자동 F등급 | Phase 1 빌드부터 수정 |
| Phase 간 점수 불균형 | 특정 영역 집중 개발 | 가장 낮은 Phase 우선 개선 |
| N/A 항목 처리 혼란 | LLM 미사용 등 해당 없는 항목 | 점수 재배분 공식 적용 |
| 개별 스킬과 결과 불일치 | 스킬 버전/설정 차이 | 개별 스킬 직접 실행으로 비교 |
| 에이전트 하나가 실패 | 빌드 에러, 파일 없음 등 | 실패한 Phase만 재실행, 나머지 결과는 유지 |
| Critical 항목인데 등급 높음 | Critical 기반 하향 규칙 미적용 | scoring-methodology 재확인 |
| Security와 Backend Safety 중복 보고 | Rate Limit/Secret이 관점 다르게 두 번 나옴 | 의도된 동작 — 리포트에서 교차참조 표기 |
| Security 등급만 F | 보안 취약점 Critical 3건 이상 | 종합 등급은 별도이나 배포 차단 권고 |

## Anti-patterns

| 패턴 | 문제 | 대안 |
|------|------|------|
| 점수만 보고 문제 무시 | 정성적 이슈 누락 | 항목별 상세 보고서 확인 |
| 한 Phase만 집중 개선 | 전체 균형 무시 | Gap Analysis로 우선순위 |
| 감사 없이 배포 | 치명적 결함 미발견 | 배포 전 필수 감사 |
| 경고를 전부 무시 | 점진적 품질 저하 | Major 이상 주간 리뷰 |
| 자동 수정에만 의존 | 맥락 없는 기계적 수정 | 수정 후 수동 검증 |

## References

| 문서 | 경로 | 내용 |
|------|------|------|
| 감사 체크리스트 | `references/audit-checklist.md` | Phase별 상세 체크리스트 |
| 점수 산출 방법론 | `references/scoring-methodology.md` | 가중치, 감점 기준, 등급 판정 |
| 해결 가이드 | `references/remediation-guide.md` | 문제별 코드 수정 가이드, 우선순위 |
