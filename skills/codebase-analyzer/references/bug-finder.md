# Bug Finder Guide

버그 및 잠재적 이슈 탐지를 위한 상세 지침. 체계적인 디버깅 워크플로우와 버그 패턴 분석을 제공합니다.

---

## 5단계 디버깅 워크플로우

### 1단계: 문제 재현 (Reproduce)
- 버그를 **일관되게** 재현할 수 있는 조건 확립
- 재현 단계 문서화
- 환경 변수, 입력값, 상태 기록

### 2단계: 범위 축소 (Isolate)
- Binary Search: 코드 절반씩 주석 처리하여 범위 좁히기
- 모듈 단위로 기능 비활성화하며 범위 파악
- 최근 변경사항 (git blame, git bisect) 분석

### 3단계: 가설 수립 (Hypothesize)
- 증상을 설명할 수 있는 가능한 원인 나열
- 가장 가능성 높은 것부터 검증
- 로그, 디버거, 테스트로 가설 확인

### 4단계: 수정 (Fix)
- 가장 작은 변경으로 문제 해결
- 새 버그 유발하지 않도록 주의
- 수정 후 원인 완전히 이해했는지 검증

### 5단계: 회귀 방지 (Prevent)
- **재현 테스트** 작성 (버그가 다시 발생하면 실패)
- 유사 패턴 코드베이스에서 검색 및 수정
- Root Cause 문서화

---

## 버그 패턴 카탈로그

### 1. 타입 에러 (Type Errors)
| 패턴 | 증상 | 해결책 |
|------|------|--------|
| 암묵적 any | 런타임 속성 에러 | `strict: true` 활성화, 명시적 타입 |
| Null 참조 | `Cannot read property of null` | Optional chaining (`?.`), null 검사 |
| 타입 단언 남용 | `as` 후 런타임 에러 | 타입 가드 사용, 단언 최소화 |
| 제네릭 불일치 | 컴파일 에러 없이 런타임 실패 | 제네릭 제약 조건 추가 |

### 2. 로직 에러 (Logic Errors)
| 패턴 | 증상 | 해결책 |
|------|------|--------|
| Off-by-one | 배열 마지막 요소 누락, 반복 횟수 오류 | 경계 조건 명시적 테스트 |
| 잘못된 비교 | `==` vs `===`, 부동소수점 비교 | `===` 사용, 오차 범위 허용 |
| 조건 역전 | `if (!condition)` 로직 오류 | 조건문 단순화, 긍정형 표현 |
| 단락 평가 | `&&`, `\|\|` 예상 외 동작 | 명시적 조건문 분리 |

### 3. 비동기 에러 (Async Errors)
| 패턴 | 증상 | 해결책 |
|------|------|--------|
| 누락된 await | Promise 대신 Promise 객체 반환 | 모든 async 함수에 await 검사 |
| Race condition | 비결정적 결과, 간헐적 실패 | 락, 큐, 순차 실행 |
| Unhandled rejection | 프로세스 크래시, 무시된 에러 | `.catch()` 또는 `try-catch` |
| Stale closure | 오래된 값 참조 | deps 배열 검증, 최신 값 참조 |

### 4. 상태 관리 에러 (State Errors)
| 패턴 | 증상 | 해결책 |
|------|------|--------|
| 직접 변이 | React 리렌더 안됨, 상태 불일치 | 불변 업데이트, immer 사용 |
| 전역 상태 오염 | 테스트 간 상태 유출 | 상태 격리, 의존성 주입 |
| 초기화 순서 | undefined 참조 | 초기화 순서 명시, lazy init |

### 5. 리소스 에러 (Resource Errors)
| 패턴 | 증상 | 해결책 |
|------|------|--------|
| 메모리 누수 | 메모리 사용량 증가 | cleanup, WeakRef, 프로파일링 |
| 연결 누수 | 커넥션 풀 고갈 | finally에서 close, using 문 |
| 파일 핸들 누수 | 파일 열기 실패 | try-finally, dispose 패턴 |

---

## Root Cause Analysis (RCA)

### 5 Whys 기법
```
문제: 프로덕션 서버 다운
→ Why? DB 커넥션 풀 고갈
→ Why? 커넥션 반환 안됨
→ Why? 예외 발생 시 finally 없음
→ Why? 코드 리뷰에서 누락
→ Why? 체크리스트에 리소스 관리 항목 없음
⇒ 해결: 코드 리뷰 체크리스트에 리소스 정리 항목 추가
```

### Fishbone 다이어그램 카테고리
- **코드**: 로직, 타입, 알고리즘 오류
- **환경**: 설정, 의존성, 인프라 차이
- **데이터**: 입력 검증, 엣지 케이스, 상태 불일치
- **프로세스**: 배포, 테스트, 코드 리뷰 미흡

---

## 디버깅 도구 및 전략

### 로깅 전략
```typescript
// 구조화된 로그
logger.info('User action', {
  action: 'purchase',
  userId: user.id,
  amount: cart.total,
  timestamp: new Date().toISOString()
});
```

### 디버거 활용
- **Breakpoint**: 의심 지점에서 실행 중지
- **Watch**: 변수 값 실시간 관찰
- **Call Stack**: 호출 경로 추적
- **Conditional Breakpoint**: 특정 조건에서만 중지

### Git Bisect
```bash
git bisect start
git bisect bad HEAD          # 현재가 버그 있음
git bisect good v1.0.0       # 이 버전은 정상
# 자동으로 중간 커밋 체크아웃, 테스트 후 good/bad 표시
git bisect good/bad
```

---

## 출력 형식

```markdown
# Bug Detection Report

## Bugs Found: [X]

## Critical Bugs (즉시 수정 필요)
### Bug #1: [제목]
- **위치**: `file.ts:line`
- **유형**: [Type Error / Logic Error / Async Error / State Error]
- **증상**: [사용자가 경험하는 문제]
- **Root Cause**: [근본 원인]
- **영향**: [발생 가능한 상황]
- **수정**:
  ```typescript
  // 제안된 수정
  ```

## Major Bugs (빠른 시일 내 수정)
[동일 형식]

## Minor Issues (낮은 우선순위)
[동일 형식]

## Potential Edge Cases
- **시나리오**: [설명]
  - **위치**: `file.ts:line`
  - **이슈**: [문제될 수 있는 상황]
  - **권장**: [처리 방법]

## Prevention Recommendations
- [재발 방지를 위한 권장사항]

## Summary
- Critical: X
- Major: X
- Minor: X
- Edge Cases: X

## Immediate Actions Required
1. [가장 긴급한 수정]
2. [두 번째 우선순위]
3. [세 번째 우선순위]
```

---

## 실행 지침

1. 분석할 파일 확인 (미지정 시 질문)
2. 5단계 디버깅 워크플로우 기반 분석
3. 버그 패턴 카탈로그 참조하여 유형 분류
4. Root Cause Analysis 수행
5. 구체적인 라인 번호와 수정 제안 제공
6. 회귀 방지를 위한 테스트 권장사항 포함
