# Refactoring Patterns Guide

코드 개선 및 리팩토링을 위한 상세 지침. 체계적인 리팩토링 워크플로우와 패턴 분석을 제공합니다.

---

## Red-Green-Refactor 워크플로우

### 1단계: Red (테스트 실패)
- 리팩토링할 코드의 현재 동작을 검증하는 테스트 작성
- 기존 테스트가 없다면 **먼저 테스트 추가**
- 테스트가 통과하는지 확인 (Green 상태)

### 2단계: Refactor (구조 변경)
- **동작 변경 없이** 코드 구조만 개선
- 작은 단위로 점진적 변경
- 각 변경 후 테스트 실행하여 회귀 확인

### 3단계: Green (테스트 통과)
- 모든 테스트가 여전히 통과하는지 확인
- 리팩토링이 기존 기능을 손상시키지 않았음을 검증

---

## 코드 스멜 체크리스트

### Bloaters (비대한 코드)
| 스멜 | 증상 | 해결 기법 |
|------|------|----------|
| 긴 메서드 | 30줄 이상 | Extract Method |
| 큰 클래스 | 300줄 이상, 책임 과다 | Extract Class |
| 긴 매개변수 목록 | 4개 이상 | Parameter Object |
| 데이터 덩어리 | 여러 곳에서 함께 사용되는 데이터 | Extract Class |

### Couplers (강한 결합)
| 스멜 | 증상 | 해결 기법 |
|------|------|----------|
| Feature Envy | 다른 객체 데이터를 과도하게 사용 | Move Method |
| Inappropriate Intimacy | 클래스 간 과도한 상호 참조 | Move/Extract Method |
| Message Chains | `a.getB().getC().getD()` | Hide Delegate |
| Middle Man | 단순 위임만 하는 클래스 | Remove Middle Man |

### Dispensables (불필요한 코드)
| 스멜 | 증상 | 해결 기법 |
|------|------|----------|
| 중복 코드 | 동일 로직 반복 | Extract Method/Class |
| 죽은 코드 | 사용되지 않는 코드 | 삭제 |
| 추측성 일반화 | "언젠가 필요할" 코드 | 삭제 |
| 주석 | 코드 설명 대신 주석 | Rename, Extract |

### Change Preventers (변경 방해)
| 스멜 | 증상 | 해결 기법 |
|------|------|----------|
| Divergent Change | 한 클래스가 여러 이유로 변경 | Extract Class |
| Shotgun Surgery | 작은 변경이 여러 클래스에 영향 | Move Method |
| Parallel Inheritance | 한 계층 수정 시 다른 계층도 수정 | Collapse Hierarchy |

---

## 핵심 리팩토링 기법

### 1. Extract Method (메서드 추출)
```typescript
// Before
function printOwing(invoice: Invoice) {
  printBanner();

  // 상세 내역 출력
  console.log(`name: ${invoice.customer}`);
  console.log(`amount: ${invoice.amount}`);
  console.log(`due: ${invoice.dueDate}`);
}

// After
function printOwing(invoice: Invoice) {
  printBanner();
  printDetails(invoice);
}

function printDetails(invoice: Invoice) {
  console.log(`name: ${invoice.customer}`);
  console.log(`amount: ${invoice.amount}`);
  console.log(`due: ${invoice.dueDate}`);
}
```

### 2. Replace Conditional with Polymorphism
```typescript
// Before
function getSpeed(vehicle: Vehicle): number {
  switch (vehicle.type) {
    case 'car': return vehicle.baseSpeed;
    case 'bicycle': return vehicle.baseSpeed - 5;
    case 'plane': return vehicle.baseSpeed + 200;
  }
}

// After
interface Vehicle {
  getSpeed(): number;
}

class Car implements Vehicle {
  getSpeed() { return this.baseSpeed; }
}

class Bicycle implements Vehicle {
  getSpeed() { return this.baseSpeed - 5; }
}
```

### 3. Replace Magic Number with Constant
```typescript
// Before
if (age >= 18) { ... }

// After
const ADULT_AGE = 18;
if (age >= ADULT_AGE) { ... }
```

### 4. Introduce Parameter Object
```typescript
// Before
function amountInvoiced(startDate: Date, endDate: Date) { ... }
function amountReceived(startDate: Date, endDate: Date) { ... }

// After
class DateRange {
  constructor(public start: Date, public end: Date) {}
}

function amountInvoiced(range: DateRange) { ... }
function amountReceived(range: DateRange) { ... }
```

---

## SOLID 원칙 적용

### SRP (Single Responsibility)
- 클래스/함수가 **하나의 책임**만 가지는가?
- 변경의 이유가 하나인가?

### OCP (Open-Closed)
- 확장에 **열려있고** 수정에 **닫혀있는가**?
- 새 기능 추가 시 기존 코드 수정 없이 가능한가?

### LSP (Liskov Substitution)
- 하위 타입이 상위 타입을 **완전히 대체**할 수 있는가?

### ISP (Interface Segregation)
- 사용하지 않는 인터페이스에 **의존하지 않는가**?
- 인터페이스가 충분히 작은가?

### DIP (Dependency Inversion)
- 구체 클래스가 아닌 **추상화에 의존**하는가?
- 의존성 주입을 활용하는가?

---

## Repository 패턴 상세

**적용 시점**:
- 데이터 접근 로직이 비즈니스 로직과 혼재된 경우
- 여러 곳에서 동일한 DB 쿼리가 반복되는 경우
- 테스트 시 DB 의존성을 제거하고 싶은 경우

**예시**:
```typescript
// Before: 컴포넌트에서 직접 DB 접근
async function getUserProfile(id: string) {
  const user = await prisma.user.findUnique({ where: { id } });
  return user;
}

// After: Repository 패턴 적용
interface UserRepository {
  findById(id: string): Promise<User | null>;
}

class PrismaUserRepository implements UserRepository {
  async findById(id: string) {
    return prisma.user.findUnique({ where: { id } });
  }
}

// 테스트용 Mock
class MockUserRepository implements UserRepository {
  private users = new Map<string, User>();
  async findById(id: string) {
    return this.users.get(id) ?? null;
  }
}
```

---

## 출력 형식

```markdown
# Refactoring Report

## Summary
- **분석된 파일**: X
- **리팩토링 기회**: X
- **예상 영향**: [High/Medium/Low]

## Recommended Refactorings

### 1. [리팩토링 제목]

**우선순위**: High / Medium / Low
**유형**: [Code Smell / Duplication / Performance / Design Pattern]
**위치**: `file.ts:line`
**기법**: [Extract Method / Replace Conditional / ...]

**현재 코드**:
```typescript
// 현재 구현
```

**문제점**:
- 문제 1
- 문제 2

**리팩토링된 코드**:
```typescript
// 개선된 구현
```

**이점**:
- 이점 1
- 이점 2

**마이그레이션 단계**:
1. 테스트 작성/확인
2. 리팩토링 적용
3. 테스트 통과 확인

---

## Code Smells Detected

### [스멜 이름]
- **위치**: `file.ts:line`
- **카테고리**: [Bloater / Coupler / Dispensable / Change Preventer]
- **제안**: [해결 기법]

## SOLID Violations

### [위반 원칙]
- **위치**: `file.ts`
- **문제**: [설명]
- **해결**: [개선 방향]

## Priority Refactoring Plan

### Phase 1 (Critical - 즉시)
1. [가장 중요한 리팩토링]

### Phase 2 (Important - 이번 주)
1. [중요한 리팩토링]

### Phase 3 (Nice to Have - 이번 달)
1. [개선하면 좋은 리팩토링]
```

---

## 리팩토링 레드 플래그

- 30줄 이상의 함수
- 300줄 이상의 파일
- Cyclomatic complexity > 10
- 중첩 깊이 > 3
- 5줄 이상의 중복 코드 블록
- 매직 넘버와 문자열
- God 클래스/객체
- 강한 결합
- 불량한 네이밍 컨벤션

---

## 실행 지침

1. 코드베이스 철저히 분석
2. Red-Green-Refactor 워크플로우 적용
3. 코드 스멜 체크리스트 기반 분석
4. 구체적인 Before/After 예시 제공
5. SOLID 원칙 위반 여부 검토
6. 하위 호환성 고려
7. 명확한 이점 없이 작동하는 코드를 리팩토링하지 않음
8. 리팩토링 후 테스트 통과 보장
