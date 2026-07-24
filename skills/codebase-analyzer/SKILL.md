---
name: codebase-analyzer
description: |
  코드베이스 종합 분석 및 개선 도구. 코드 리뷰, 버그 탐지, 리팩토링 제안, 테스트 생성, 문서화를 지원한다.
  "코드 리뷰해줘", "버그 찾아줘", "리팩토링해줘", "테스트 만들어줘", "문서화해줘", "전체 점검해줘",
  "코드 분석해줘", "품질 검사해줘", "dead code 찾아줘", "미사용 코드 정리", "사용 안 하는 코드" 등의 요청 시 자동으로 트리거된다.
---

# Codebase Analyzer

코드베이스 분석 및 개선을 위한 통합 도구.

## 분석 유형

### 1. 전체 분석 (Full Analysis)
트리거: "전체 점검", "전체 분석", "종합 리뷰", "/review-all"

6개 분석 에이전트를 **병렬로** 실행하여 종합 리포트를 생성한다.

**실행 방법:**
1. 사용자에게 분석 범위 확인 (디렉토리, 파일 타입, 제외 항목)
2. Task tool을 사용하여 6개 에이전트를 **단일 메시지에서 병렬 호출**
3. 모든 결과를 통합하여 종합 리포트 생성

### 2. 개별 분석 (Individual Analysis)

| 분석 유형 | 트리거 키워드 | 참조 파일 |
|-----------|---------------|-----------|
| 코드 리뷰 | "코드 리뷰", "리뷰해줘", "품질 검사" | `references/code-review.md` |
| 버그 탐지 | "버그 찾아줘", "버그 탐지", "에러 찾아" | `references/bug-finder.md` |
| 리팩토링 | "리팩토링", "개선해줘", "최적화" | `references/refactor-patterns.md` |
| 테스트 생성 | "테스트 만들어", "테스트 생성", "유닛 테스트" | `references/test-templates.md` |
| 문서화 | "문서화", "문서 만들어", "JSDoc", "README" | `references/doc-templates.md` |
| Dead Code 탐지 | "dead code", "미사용 코드", "정리해줘", "사용 안 하는 코드" | `references/dead-code.md` |

**실행 방법:**
1. 해당 references 파일을 Read tool로 로드
2. 파일의 지침에 따라 분석 수행
3. 결과 리포트 생성

## 전체 분석 실행 프로토콜

### Step 1: 범위 확인
사용자에게 확인할 사항:
- 분석할 디렉토리 또는 파일
- 파일 타입 필터 (예: .ts, .tsx만)
- 제외할 항목 (예: node_modules, dist)

### Step 2: 병렬 에이전트 실행

**IMPORTANT**: 5개 에이전트를 **단일 메시지**에서 Task tool로 병렬 호출한다.

각 에이전트에 전달할 프롬프트:

**Agent 1 - Code Review**:
```
[SCOPE]에 대해 코드 리뷰를 수행한다. references/code-review.md의 지침을 참조한다.
분석 항목: 코드 품질, 베스트 프랙티스, 성능, 보안, 구조
출력: 품질 점수, Critical/Major/Minor 이슈, 보안 우려사항, 우선순위 액션
```

**Agent 2 - Bug Finder**:
```
[SCOPE]에서 버그와 잠재적 이슈를 탐지한다. references/bug-finder.md의 지침을 참조한다.
분석 항목: 타입 에러, 로직 에러, 런타임 에러 가능성, 엣지 케이스
출력: Critical/Major/Minor 버그 목록, 위치, 영향도, 수정 제안
```

**Agent 3 - Documentation**:
```
[SCOPE]에 대한 문서를 생성한다. references/doc-templates.md의 지침을 참조한다.
생성 항목: JSDoc/TSDoc, README 업데이트, 복잡한 로직 주석, 사용 예시
출력: 문서화된 항목 목록, 생성된 문서, 누락된 문서 식별
```

**Agent 4 - Test Generator**:
```
[SCOPE]에 대한 테스트 스위트를 생성한다. references/test-templates.md의 지침을 참조한다.
생성 항목: 유닛 테스트, 통합 테스트, 엣지 케이스, 목 데이터
출력: 생성된 테스트 파일, 커버리지 분석, 우선순위 테스트 권장사항
```

**Agent 5 - Refactor**:
```
[SCOPE]에서 리팩토링 기회를 분석한다. references/refactor-patterns.md의 지침을 참조한다.
분석 항목: 코드 중복, 복잡한 함수, 디자인 패턴 기회, 성능 최적화
출력: 우선순위별 리팩토링 제안, Before/After 예시, 예상 효과
```

**Agent 6 - Dead Code Finder**:
```
[SCOPE]에서 미사용 코드를 탐지한다. references/dead-code.md의 지침을 참조한다.
탐지 항목: 미사용 export, 미사용 컴포넌트, 도달 불가 코드, 미사용 의존성, 미사용 변수/함수, 빈 파일
출력: 파일별 dead code 목록, 제거 시 예상 절감(줄 수), 안전 제거 가능 여부
```

### Step 3: 종합 리포트 생성

```markdown
# Codebase Analysis Report

**분석 대상**: [SCOPE]
**분석 일시**: [DATE]
**에이전트**: 6개 병렬 실행

---

## Executive Summary

### Overall Health Score: [X/10]

**핵심 지표**:
- 코드 품질: [X/10]
- 버그 위험도: [High/Medium/Low]
- 문서화 수준: [X%]
- 테스트 커버리지: [X%]
- 기술 부채: [High/Medium/Low]
- Dead Code: [X건]

**Top 3 우선순위**:
1. [가장 중요한 이슈]
2. [두 번째]
3. [세 번째]

---

## 1. Code Review Findings
[코드 리뷰 결과 요약]

## 2. Bug Detection Results
[버그 탐지 결과 요약]

## 3. Documentation Status
[문서화 상태 요약]

## 4. Test Coverage Analysis
[테스트 커버리지 분석 요약]

## 5. Refactoring Opportunities
[리팩토링 기회 요약]

## 6. Dead Code Analysis
[미사용 코드 탐지 결과 요약]

---

## Recommended Action Plan

### Immediate (오늘 할 일)
1. [Critical 항목]
2. [Critical 항목]

### Short-term (이번 주)
1. [Important 항목]
2. [Important 항목]

### Long-term (이번 달)
1. [개선 항목]
2. [개선 항목]
```

## 사용 예시

```
# 전체 분석
/review-all
"전체 코드 점검해줘"
"src/ 폴더 종합 분석해줘"

# 개별 분석
"코드 리뷰해줘"
"버그 찾아줘"
"리팩토링 제안해줘"
"테스트 만들어줘"
"문서화해줘"
```

## 참고 사항

- 전체 분석은 병렬 실행으로 **~5배 빠름**
- 개별 분석은 필요한 references만 로드하여 **컨텍스트 효율적**
- 대규모 코드베이스는 범위를 좁혀서 분석 권장

---

## Troubleshooting

| 문제 | 원인 | 해결 |
|------|------|------|
| 분석 결과가 너무 많음 | 범위 미제한 | 특정 디렉토리/파일로 범위 제한 |
| 병렬 에이전트 충돌 | 같은 파일 동시 분석 | 에이전트별 분석 영역 분리 |
| 리팩토링 제안이 과도 | 현재 기능과 무관한 개선 | 요청 범위에 맞게 제한 |
| 테스트 생성이 빌드 실패 | import 경로, 환경 차이 | 프로젝트 테스트 패턴 먼저 확인 |
| 버그 탐지 오탐 | 정적 분석 한계 | 런타임 테스트로 검증 |
| 문서화 결과가 부실 | CONTEXT 부족 | doc-templates 참조 로드 |

## Anti-patterns

| 패턴 | 문제 | 대안 |
|------|------|------|
| 전체 분석 반복 실행 | 비용 과다, 중복 결과 | 변경 파일만 증분 분석 |
| 모든 제안 무조건 적용 | 기존 패턴 파괴 가능 | Critical/Major만 우선 |
| 테스트 없이 리팩토링 | 회귀 버그 위험 | 리팩토링 전 테스트 확보 |
| 단일 에이전트로 전체 분석 | 시간 낭비 | 6에이전트 병렬 실행 |
| 분석 결과 미기록 | 반복 분석 시 비교 불가 | 결과 파일로 저장 |

## References

| 문서 | 경로 | 내용 |
|------|------|------|
| 버그 탐지 | `references/bug-finder.md` | 패턴 기반 버그 탐지 규칙 |
| 코드 리뷰 | `references/code-review.md` | 리뷰 기준, 체크리스트 |
| 리팩토링 패턴 | `references/refactor-patterns.md` | 안전한 리팩토링 기법 |
| 테스트 템플릿 | `references/test-templates.md` | Vitest/Playwright 템플릿 |
| 문서화 템플릿 | `references/doc-templates.md` | 함수/API/컴포넌트 문서화 |
| Dead Code 탐지 | `references/dead-code.md` | 미사용 코드 탐지 패턴/워크플로우 |
