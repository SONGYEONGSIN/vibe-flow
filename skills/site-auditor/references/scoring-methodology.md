# Scoring Methodology

Site Auditor의 점수 산출 방법론. 4개 Phase의 가중치, 감점 기준, 등급 판정.

---

## 전체 점수 구조

```
총점 (100점) = Performance(25) + UI/Accessibility(25) + SEO(25) + Backend Safety(25)
```

### Phase별 만점 배분

| Phase | 만점 | 비중 | 근거 |
|-------|:----:|:----:|------|
| Performance | 25 | 25% | Core Web Vitals, 빌드 안정성 |
| UI/Accessibility | 25 | 25% | WCAG 2.1 AA 준수, UX 품질 |
| SEO | 25 | 25% | 검색 노출, 메타데이터 완전성 |
| Backend Safety | 25 | 25% | 보안, 가용성, 모니터링 |

---

## Phase 1: Performance (25점)

### 세부 항목

| 항목 | 배점 | 측정 방법 |
|------|:----:|----------|
| 빌드 성공 | 8 | `npm run build` exit code |
| TypeScript 에러 | 4 | 빌드 출력 error 카운트 |
| 번들 크기 | 5 | .next/static/chunks/ 총 크기 |
| 이미지 최적화 | 4 | unoptimized 플래그, next/image 사용률 |
| 미사용 의존성 | 4 | package.json vs import 비교 |

### 감점 기준

```
빌드 성공:
  - 빌드 성공: 8/8
  - 빌드 실패: 0/8

TypeScript 에러:
  - 0개: 4/4
  - 1-5개: 2/4
  - 6+개: 0/4

번들 크기 (.next/static/):
  - < 500KB: 5/5
  - 500KB-1MB: 4/5
  - 1MB-2MB: 3/5
  - 2MB-5MB: 2/5
  - > 5MB: 1/5

이미지 최적화:
  - next/image 100% 사용: 4/4
  - 80%+ 사용: 3/4
  - 50%+ 사용: 2/4
  - < 50%: 1/4

미사용 의존성:
  - 0개: 4/4
  - 1-3개: 3/4
  - 4-6개: 2/4
  - 7+개: 1/4
```

---

## Phase 2: UI/Accessibility (25점)

### 세부 항목

| 항목 | 배점 | 측정 방법 |
|------|:----:|----------|
| img alt 속성 | 5 | alt 있는 비율 |
| 키보드 접근성 | 5 | outline:none, tabindex 검사 |
| 폼 접근성 | 5 | label 연결, autocomplete |
| ARIA 사용 | 5 | aria-label, role 적절성 |
| 안티패턴 없음 | 5 | user-scalable=no 등 |

### 감점 공식

```
위반 기반 감점:
  FAIL (error): 위반당 -1점 (최대 해당 항목 배점까지)
  WARN (warning): 위반당 -0.5점
  INFO: 감점 없음

예시:
  img alt 항목 (5점 만점):
  - FAIL 2개: 5 - 2 = 3점
  - FAIL 6개 이상: 0점 (최소 0점)
```

### 심각도 분류

| 심각도 | 규칙 예시 | 감점 |
|--------|----------|:----:|
| Critical | A30(alt 누락), A20(outline:none) | -1.0 |
| Major | F01(label 미연결), M01(reduced-motion) | -0.5 |
| Minor | P01(virtualization), T01(버튼 텍스트) | -0.25 |

---

## Phase 3: SEO (25점)

### 세부 항목

| 항목 | 배점 | 측정 방법 |
|------|:----:|----------|
| 메타데이터 | 5 | title, description, metadataBase |
| OG 이미지 | 4 | openGraph 설정, 이미지 존재 |
| sitemap/robots | 4 | 파일 존재 + 접근 가능 |
| 구조화 데이터 | 4 | JSON-LD 존재 + 유효성 |
| 시멘틱 HTML | 4 | h1, nav, main, section |
| Canonical/기술 SEO | 4 | canonical URL, 에러 페이지 |

### 체크리스트 기반 산출

```
각 항목별 체크포인트:

메타데이터 (5점):
  □ metadataBase 설정 (+1)
  □ title 템플릿 (+1)
  □ 페이지별 고유 description (+1)
  □ viewport 설정 (+1)
  □ favicon 존재 (+1)

OG 이미지 (4점):
  □ OG 이미지 존재 (+1)
  □ 1200x630 크기 (+1)
  □ openGraph 설정 (+1)
  □ twitter:card 설정 (+1)

sitemap/robots (4점):
  □ sitemap.ts 존재 (+1)
  □ robots.ts 존재 (+1)
  □ sitemap 동적 생성 (+1)
  □ sitemap에 모든 페이지 포함 (+1)

구조화 데이터 (4점):
  □ JSON-LD 1개 이상 (+1)
  □ 페이지별 고유 스키마 (+1)
  □ 필수 속성 완전 (+1)
  □ @graph 연결 (+1)

시멘틱 HTML (4점):
  □ h1 페이지당 1개 (+1)
  □ heading 계층 순차적 (+1)
  □ nav/main/section 사용 (+1)
  □ aria-label 적절 사용 (+1)

Canonical/기술 SEO (4점):
  □ canonical URL 설정 (+1)
  □ not-found.tsx 존재 (+1)
  □ error.tsx 존재 (+1)
  □ 리다이렉트 설정 (해당 시) (+1)
```

---

## Phase 4: Backend Safety (25점)

### 세부 항목

| 항목 | 배점 | 측정 방법 |
|------|:----:|----------|
| 가시성 (Observability) | 5 | Sentry/에러 추적 설정 |
| 환경변수 검증 | 5 | t3-env 또는 검증 로직 |
| 가용성 가드레일 | 5 | 타임아웃, 재시도, 서킷브레이커 |
| 자원/비용 통제 | 5 | Rate limiting, Idempotency |
| LLM 토큰 관리 | 5 | max_tokens, 입력 검증 |

### N/A 항목 처리

해당 없는 항목은 점수 재배분:

```
예: LLM 미사용 프로젝트
  - LLM 토큰 관리 (5점): N/A
  - 나머지 4항목에 균등 배분: 각 6.25점
  - 또는 100점 만점에서 해당 비중 제외

공식:
  adjusted_score = (raw_score / applicable_max) × 25
```

---

## 종합 등급 판정

### 등급 기준

| 등급 | 점수 | 판정 | 의미 |
|------|:----:|------|------|
| A | 90-100 | 배포 권장 | 모든 영역 우수 |
| B | 70-89 | 배포 가능 | 경미한 개선 필요 |
| C | 50-69 | 배포 주의 | 상당한 개선 필요 |
| D | 30-49 | 배포 비권장 | 심각한 문제 존재 |
| F | 0-29 | 배포 차단 | 치명적 결함 |

### Critical 항목 기반 차단

점수와 별개로, critical 항목이 있으면 등급 하향:

```
규칙:
  - Critical 1개: 최대 B등급
  - Critical 3개 이상: 최대 C등급
  - 빌드 실패: 자동 F등급

Critical 항목 정의:
  - Phase 1: 빌드 실패
  - Phase 2: 키보드 접근 불가, alt 누락 50%+
  - Phase 3: sitemap 미존재, 메타데이터 전무
  - Phase 4: 환경변수 검증 없음, Sentry 미설정 (프로덕션)
```

### 보안 등급 기반 차단

Phase 5(Security Audit)의 등급이 종합 등급에 상한선을 부여:

```
보안 등급 기반 차단 (점수와 무관하게 적용):
  - Security F: 종합 최대 D등급
  - Security D: 종합 최대 C등급
  - Security C: 종합 최대 B등급

적용 예시:
  종합 점수 91점(A)이어도 Security 등급 F → 종합 D등급 확정
  종합 점수 75점(B)이고 Security 등급 C → 종합 B등급 (그대로)
  종합 점수 55점(C)이고 Security 등급 D → 종합 C등급 (그대로, 더 낮은 쪽 적용)
```

**우선순위:** 보안 등급 차단 → Critical 항목 차단 → 점수 기반 등급 순으로 적용.

---

## 가중치 커스터마이징

프로젝트 유형별 가중치 조정 가능:

| 프로젝트 유형 | Perf | UI/A11y | SEO | Backend |
|-------------|:----:|:-------:|:---:|:-------:|
| 랜딩 페이지 | 20 | 25 | 30 | 25 |
| 대시보드/SaaS | 25 | 30 | 15 | 30 |
| 이커머스 | 25 | 25 | 30 | 20 |
| 블로그/미디어 | 20 | 20 | 35 | 25 |
| 내부 도구 | 30 | 25 | 10 | 35 |

---

## 추세 분석

### 점수 이력 추적

```markdown
# Score History

| 날짜 | 총점 | Perf | UI | SEO | Backend | 등급 |
|------|:----:|:----:|:--:|:---:|:-------:|:----:|
| 2026-01-15 | 62 | 18 | 12 | 20 | 12 | C |
| 2026-01-22 | 71 | 20 | 16 | 22 | 13 | B |
| 2026-01-29 | 78 | 22 | 18 | 22 | 16 | B |
| 2026-02-05 | 85 | 23 | 21 | 23 | 18 | B |
| 2026-02-12 | 92 | 24 | 23 | 24 | 21 | A |
```

### 개선 우선순위 결정

```
Gap Analysis:
  가장 낮은 Phase를 우선 개선

예: Perf(24), UI(15), SEO(22), Backend(20) = 81점 B등급
  → UI/Accessibility가 가장 낮음 → 여기 집중
  → UI를 20으로 올리면 86점
  → UI를 23으로 올리면 89점 → A등급 진입
```

---

## 보고서 생성 시 주의사항

1. **정량적 증거 포함** - "이미지 최적화 부족" 대신 "unoptimized 5개, next/image 미사용 3개"
2. **액션 가능한 권장사항** - "개선 필요" 대신 "src/components/Hero.tsx:15에서 img → Image 변경"
3. **우선순위 명시** - Critical → Major → Minor 순서
4. **N/A 투명하게** - 해당 없는 항목 명시, 점수 조정 설명
5. **이전 점수 비교** - 개선/악화 추세 표시
