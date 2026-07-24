# Playwright 테스트 에이전트 가이드

Playwright v1.56에서 도입된 AI 기반 테스트 에이전트.

---

## 요구사항

| 항목 | 버전 |
|-----|-----|
| Playwright | **v1.56 이상** |
| VS Code (VS Code 사용 시) | **v1.105 이상** |

---

## 설치

```bash
# Claude Code용
npx playwright init-agents --loop=claude

# VS Code용
npx playwright init-agents --loop=vscode

# OpenCode용
npx playwright init-agents --loop=opencode
```

### 생성되는 구조

```
project/
├── .claude/agents/           # Claude Code 에이전트 정의
│   ├── playwright-test-planner.md
│   ├── playwright-test-generator.md
│   └── playwright-test-healer.md
├── specs/                    # 테스트 계획 (마크다운)
├── tests/                    # 생성된 테스트 코드
│   └── seed.spec.ts          # 시드 테스트
└── playwright.config.ts
```

---

## 3단계 워크플로우

```
Planner → Generator → Healer
(계획)     (생성)      (수정)
```

### 1단계: Planner (플래너)

**역할**: 웹 애플리케이션 탐색 및 테스트 계획 수립

**주요 기능**:
- 브라우저 자동 탐색 및 인터페이스 분석
- 사용자 플로우 맵핑
- 테스트 시나리오 설계
- 마크다운 형식 계획 문서 작성

**프롬프트 예시**:

```
@playwright-test-planner

퍼슨 페이지(localhost:3000/person/{id})에 대한 테스트 시나리오를 작성해줘.

포함할 내용:
- 프로필 정보 표시 검증
- 필모그래피 목록 검증
- 소셜 링크 동작 검증
- 반응형 레이아웃 검증
- 에러 상태 처리 검증

specs/ 폴더에 마크다운으로 저장해줘.
```

**출력**: `specs/person-page-test-plan.md`

### 2단계: Generator (제너레이터)

**역할**: 테스트 계획을 실제 Playwright 테스트 코드로 변환

**주요 기능**:
- 테스트 계획 분석
- 브라우저에서 실제 동작 실행하며 검증
- 실행 로그 기반 테스트 코드 생성
- Playwright 베스트 프랙티스 적용 (시맨틱 로케이터 등)

**병렬 처리 전 필수 - 의존성 그룹화**:

```
specs/person-page-test-plan.md의 시나리오를 분석해서
의존성이 겹치지 않는 그룹으로 나눠줘.

규칙:
- 같은 페이지라도 완전히 다른 기능 테스트는 병렬 처리 가능
- 상태를 공유하거나 순차 실행 필요한 테스트는 같은 그룹
- 로그인 → 프로필 수정 같은 의존 관계는 순차 처리
```

**병렬 실행 프롬프트**:

```
플레이라이트 테스트 제너레이터 에이전트를 활용해서
그룹별로 병렬로 에이전트를 띄워서 테스트 코드를 작성해줘.
최대 10개까지 병렬 실행해줘.

각 테스트는 seed.spec.ts의 fixture를 활용해야 해.
```

**출력**: `tests/` 폴더에 `.spec.ts` 파일들

### 3단계: Healer (힐러)

**역할**: 실패한 테스트 자동 디버깅 및 수정

**주요 기능**:
- 실패한 테스트 식별
- 테스트 재실행하며 UI 변경사항 감지
- 에러 원인 분석 (로케이터 변경, 타이밍 이슈 등)
- 테스트 코드 자동 수정
- 수정 후 재검증

**프롬프트 예시**:

```
npx playwright test 실행 결과 실패한 테스트들을 확인해줘.

실패한 테스트 파일별로 힐러 에이전트를 병렬로 띄워서 수정해줘.
수정 후 각 테스트가 통과하는지 검증까지 해줘.
```

**출력**:
- 수정되어 통과하는 테스트
- 또는 기능 자체가 broken이면 skip 처리 + 설명

---

## 실전 팁

### YOLO 모드 권장

```bash
claude --dangerously-skip-permissions
```

**권장 이유**:
- 병렬 처리 시 매번 허락 받으면 생산성 급감
- 테스트 코드 작성은 기존 프로덕션 로직에 영향 없음
- 새로운 파일 생성이므로 기존 서비스 안전

### seed.spec.ts 활용

시드 테스트는 fixture와 초기화 로직을 포함:

```typescript
// tests/seed.spec.ts
import { test, expect } from './fixtures';

test('seed', async ({ page }) => {
  // 이 테스트는 custom fixtures 사용
  // Planner가 예시로 참조
});
```

### 호출 방법

```bash
# @멘션으로 직접 호출
@playwright-test-planner 테스트 시나리오 작성해줘

# 프롬프트에서 명시적 요청
플레이라이트 플래너 에이전트를 호출해서 작업해줘
```

---

## 전체 워크플로우 프롬프트

```
# 1. 계획 수립
@playwright-test-planner
[페이지 URL]에 대한 테스트 시나리오를 작성해줘.
specs/ 폴더에 마크다운으로 저장해줘.

# 2. 의존성 그룹화
specs/[파일명].md의 시나리오를 분석해서
의존성이 겹치지 않는 그룹으로 나눠줘.

# 3. 테스트 코드 생성 (병렬)
그룹별로 병렬로 에이전트를 띄워서 테스트 코드를 작성해줘.
최대 10개까지 병렬 실행해줘.

# 4. 실패 테스트 수정 (병렬)
실패한 테스트 파일별로 힐러 에이전트를 병렬로 띄워서 수정해줘.
```

---

## 제한사항

- AI가 항상 완벽한 로케이터를 찾지는 않음 → 수동 검토 필요
- 복잡한 UI 변경 시 Healer가 자동 수정 못할 수 있음
- 과도한 의존은 금물 → 테스트 신뢰성 수동 검증 필요
