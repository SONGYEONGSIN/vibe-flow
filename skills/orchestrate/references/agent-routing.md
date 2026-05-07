# Agent Routing Guide

작업 특성에 따른 에이전트/모델 선택 가이드. 비용 효율과 품질의 균형.

---

## 라우팅 의사결정 트리

```
요청 수신
  │
  ├─ 스킬 트리거? ──── YES → 해당 스킬 실행
  │
  ├─ 탐색/검색? ────── YES → Explore (haiku)
  │
  ├─ 외부 리서치? ──── YES → general-purpose (sonnet) + WebSearch
  │
  ├─ UI 구현? ──────── YES → frontend-design-specialist (sonnet)
  │
  ├─ DB/쿼리? ──────── YES → supabase-db-specialist (sonnet)
  │
  ├─ 테스트 작성? ──── YES → test-writer (sonnet)
  │
  ├─ 코드 리뷰? ────── YES → code-reviewer (opus)
  │
  ├─ 아키텍처? ──────── YES → general-purpose (opus)
  │
  ├─ 간단한 수정? ──── YES → 직접 수행 (오케스트레이터)
  │
  └─ 복잡한 구현? ──── YES → general-purpose (sonnet)
```

---

## 스킬 트리거 매핑

요청을 받으면 먼저 스킬 매칭을 확인한다.

| 요청 키워드 | 스킬 | 우선순위 |
|------------|------|:--------:|
| "커밋", "commit" | commit | 1 |
| "배포", "deploy" | vercel-deploy-claimable | 1 |
| "SEO 점검", "메타태그" | seo-master | 1 |
| "TDD", "테스트 주도" | test-driven-development | 1 |
| "코드 리뷰", "품질 검사" | codebase-analyzer | 1 |
| "성능 점검", "빌드 체크" | site-auditor | 1 |
| "전체 점검", "사이트 검증" | site-auditor | 1 |
| "UI 검증", "접근성 검사" | web-design-guidelines | 1 |
| "프로젝트 시작", "기획 문서" | start-docs | 1 |
| "크롤링", "스크래핑" | agent-browser | 1 |
| "끝까지", "완료까지" | ralph | 1 |
| "토론", "debate" | debate | 1 |
| "MCP 서버 만들기" | mcp-builder | 1 |
| "Edge Function" | supabase-edge-functions | 1 |
| "배포 안전 점검" | site-auditor | 1 |
| "스킬 찾기" | find-skills | 1 |
| "새 기능 구현" | feature-dev | 2 |

---

## 에이전트 유형별 특성

### Explore (탐색 전문)

**용도:** 코드베이스 탐색, 패턴 파악, 파일 검색
**모델:** haiku (항상)
**도구:** Read, Grep, Glob
**특성:**
- 빠르고 저렴
- 항상 background 실행
- 결과: 파일 목록, 패턴 요약, 구조 분석

```
Task(subagent_type="Explore", model="haiku", run_in_background=true,
  prompt="src/ 디렉토리에서 Supabase 클라이언트 초기화 패턴을 모두 찾아주세요")
```

### general-purpose (범용)

**용도:** 구현, 리서치, 리뷰, 아키텍처
**모델:** 작업 복잡도에 따라 선택
**도구:** 모든 도구
**특성:**
- 가장 유연한 에이전트
- 모델 선택이 중요

```
// 간단한 구현
Task(subagent_type="general-purpose", model="sonnet", prompt="...")

// 복잡한 아키텍처
Task(subagent_type="general-purpose", model="opus", prompt="...")
```

### 전문 에이전트

| 에이전트 | 전문 분야 | 기본 모델 |
|----------|----------|:---------:|
| frontend-design-specialist | UI/UX 구현 | sonnet |
| supabase-db-specialist | DB 스키마, RLS, 쿼리 | sonnet |
| test-writer | 테스트 코드 작성 | sonnet |
| code-reviewer | 코드 품질 검증 | opus |
| project-planner | 프로젝트 기획 | sonnet |
| performance-optimizer | 성능 최적화 | sonnet |
| api-architect | API 설계 | sonnet |
| security-specialist | 보안 감사 | sonnet |

---

## 워크플로우별 에이전트 구성

### 새 프로젝트 워크플로우

```
Phase 1: 기획
  project-planner (sonnet) → PRD, 요구사항

Phase 2: 설계
  general-purpose (opus) → 아키텍처 설계
  supabase-db-specialist (sonnet) → DB 스키마
  api-architect (sonnet) → API 설계

Phase 3: 구현 (병렬)
  frontend-design-specialist (sonnet) → UI 컴포넌트
  general-purpose (sonnet) → 백엔드 로직
  test-writer (sonnet) → 테스트 코드

Phase 4: 검증
  code-reviewer (opus) → 코드 리뷰
  site-auditor (스킬) → 종합 점검/배포
```

### 기능 추가 워크플로우

```
Phase 1: 탐색 (병렬, background)
  Explore (haiku) × 2-3 → 관련 코드 파악

Phase 2: 설계
  general-purpose (opus) → 구현 방안 2-3개

Phase 3: 구현 (사용자 선택 후)
  적절한 전문 에이전트 (sonnet)

Phase 4: 검증
  code-reviewer (opus) → 최종 검증
```

### 버그 수정 워크플로우

```
Phase 1: 진단
  Explore (haiku) → 관련 코드 파악
  general-purpose (opus) → 근본 원인 분석

Phase 2: 수정
  직접 수행 또는 general-purpose (sonnet)

Phase 3: 검증
  Bash → 테스트 실행
```

---

## 비용 효율 가이드

### 토큰 비용 비교

| 모델 | 입력 $/1M | 출력 $/1M | 상대 비용 |
|------|:---------:|:---------:|:---------:|
| Haiku | $0.80 | $4.00 | 1x |
| Sonnet | $3.00 | $15.00 | ~4x |
| Opus | $15.00 | $75.00 | ~19x |

### 비용 절감 규칙

1. **탐색은 무조건 haiku** - 파일 찾기, 패턴 검색
2. **haiku로 충분한 작업** - SEO 점검, 배포 체크, 간단한 리서치
3. **sonnet이 필요한 작업** - 코드 구현, 테스트 작성, 중간 복잡도 분석
4. **opus가 필요한 작업** - 최종 검증, 복잡한 디버깅, 아키텍처 설계
5. **프롬프트 최적화** - 불필요한 컨텍스트 제거, 범위 제한

### 예산 관리

```
소규모 작업 (버그 수정):
  Explore (haiku) × 1 + Fix (직접) = ~$0.01

중규모 작업 (기능 추가):
  Explore (haiku) × 2 + Implement (sonnet) × 1 + Review (opus) × 1 = ~$0.50

대규모 작업 (새 프로젝트):
  Plan (sonnet) + Design (opus) + Implement (sonnet) × 5 + Review (opus) × 2 = ~$5.00
```

---

## 에이전트 프롬프트 템플릿

### 탐색 에이전트 템플릿

```
[EXPLORE] {specific_area}에서 {target_pattern}을 찾아주세요.
결과 형식: 파일경로:줄번호 - 설명
제외: node_modules, .next, dist
```

### 구현 에이전트 템플릿

```
[IMPLEMENT]
Task: {구체적 작업}
Files: {수정할 파일 목록}
Pattern: {참조할 기존 패턴 파일}
Tests: {테스트 전략}
Constraints: {제약 조건}
```

### 검증 에이전트 템플릿

```
[VERIFY]
Original: {원래 요구사항}
Changes: {변경 목록}
Evidence: {빌드/테스트 결과}
Verdict: APPROVED | REJECTED (with reasons)
```

---

## 트러블슈팅

| 문제 | 원인 | 해결 |
|------|------|------|
| 에이전트가 엉뚱한 작업 | 프롬프트 모호 | 7섹션 구조 준수 |
| 비용 과다 | opus 과용 | 라우팅 매트릭스 준수 |
| 결과 품질 낮음 | haiku로 복잡한 작업 | 모델 업그레이드 |
| 에이전트 간 충돌 | 동일 파일 동시 수정 | 파일별 에이전트 분리 |
| 응답 시간 느림 | 순차 실행 | 병렬 + background |
| 컨텍스트 부족 | CONTEXT 섹션 미흡 | 참조 파일/패턴 추가 |
