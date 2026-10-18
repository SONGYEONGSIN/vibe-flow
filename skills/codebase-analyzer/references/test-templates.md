# Test Templates Guide

테스트 생성을 위한 상세 지침. AAA 패턴, 테스트 유형별 템플릿, 모킹 전략을 제공합니다.

---

## AAA 패턴 (Arrange-Act-Assert)

```typescript
it('should calculate total with discount', () => {
  // Arrange: 테스트에 필요한 데이터와 상태 준비
  const cart = new Cart();
  cart.addItem({ name: 'Item', price: 100 });
  const discount = 0.1;

  // Act: 테스트 대상 동작 실행 (단 하나의 동작)
  const total = cart.calculateTotal(discount);

  // Assert: 결과 검증 (명확한 기대값)
  expect(total).toBe(90);
});
```

### AAA 체크리스트
- [ ] Arrange: 테스트 데이터가 명확히 준비되었는가?
- [ ] Act: 단 하나의 동작만 실행하는가?
- [ ] Assert: 기대값이 명확하고 검증 가능한가?

---

## 테스트 유형별 템플릿

### 단위 테스트 (Unit Test)
```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import { Calculator } from './calculator';

describe('Calculator', () => {
  let calculator: Calculator;

  beforeEach(() => {
    calculator = new Calculator();
  });

  describe('add', () => {
    it('should add two positive numbers', () => {
      expect(calculator.add(2, 3)).toBe(5);
    });

    it('should handle negative numbers', () => {
      expect(calculator.add(-1, 1)).toBe(0);
    });

    it('should handle zero', () => {
      expect(calculator.add(0, 5)).toBe(5);
    });
  });

  describe('edge cases', () => {
    it('should handle large numbers', () => {
      expect(calculator.add(Number.MAX_SAFE_INTEGER, 0))
        .toBe(Number.MAX_SAFE_INTEGER);
    });
  });
});
```

### 통합 테스트 (Integration Test)
```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { app } from './app';
import { db } from './db';

describe('User API', () => {
  beforeAll(async () => {
    await db.migrate.latest();
    await db.seed.run();
  });

  afterAll(async () => {
    await db.destroy();
  });

  describe('POST /api/users', () => {
    it('should create user and return 201', async () => {
      const userData = { name: 'Test', email: 'test@example.com' };

      const response = await request(app)
        .post('/api/users')
        .send(userData)
        .expect(201);

      expect(response.body).toMatchObject(userData);
      expect(response.body.id).toBeDefined();
    });

    it('should return 400 for invalid email', async () => {
      await request(app)
        .post('/api/users')
        .send({ name: 'Test', email: 'invalid' })
        .expect(400);
    });
  });
});
```

### E2E 테스트 (Playwright)
```typescript
import { test, expect } from '@playwright/test';

test.describe('Login Flow', () => {
  test('should login successfully with valid credentials', async ({ page }) => {
    // Arrange
    await page.goto('/login');

    // Act
    await page.fill('[data-testid="email"]', 'user@example.com');
    await page.fill('[data-testid="password"]', 'password123');
    await page.click('[data-testid="submit"]');

    // Assert
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid="welcome"]'))
      .toContainText('Welcome');
  });

  test('should show error for invalid credentials', async ({ page }) => {
    await page.goto('/login');
    await page.fill('[data-testid="email"]', 'wrong@example.com');
    await page.fill('[data-testid="password"]', 'wrong');
    await page.click('[data-testid="submit"]');

    await expect(page.locator('[data-testid="error"]'))
      .toBeVisible();
  });
});
```

---

## 모킹 전략 (Test Doubles)

### Stub vs Mock vs Spy
| 종류 | 목적 | 검증 방식 |
|------|------|----------|
| **Stub** | 미리 정의된 응답 반환 | 상태(State) 검증 |
| **Mock** | 호출 여부/방식 검증 | 행위(Behavior) 검증 |
| **Spy** | 실제 구현 유지하며 호출 관찰 | 상태 + 행위 검증 |

### Stub 예시
```typescript
// 외부 API 응답을 고정값으로 대체
const userServiceStub = {
  getUser: async (id: string) => ({ id, name: 'Stub User' })
};
```

### Mock 예시
```typescript
// 메서드 호출 여부 검증
const mockLogger = vi.fn();
service.doSomething();
expect(mockLogger).toHaveBeenCalledWith('expected message');
```

### Spy 예시
```typescript
// 실제 구현 유지하면서 호출 관찰
const spy = vi.spyOn(service, 'save');
service.process(data);
expect(spy).toHaveBeenCalledTimes(1);
```

### 모킹 레이어
```
외부 API    → Mock (네트워크 격리)
Database   → Stub (테스트 데이터)
Time/Random → Stub (결정적 결과)
Logger     → Spy (로그 검증 시)
```

---

## DO / DON'T

### DO (권장)
| 패턴 | 이유 |
|------|------|
| 하나의 테스트 = 하나의 동작 | 실패 원인 명확 |
| 명확한 테스트 이름 | `should_return_error_when_email_invalid` |
| 테스트 데이터 격리 | 테스트 간 간섭 방지 |
| 경계값 테스트 | 엣지 케이스 커버 |
| Given-When-Then 구조 | 가독성 향상 |

### DON'T (지양)
| 패턴 | 문제점 |
|------|--------|
| 테스트 간 상태 공유 | 순서 의존성 발생 |
| 프라이빗 메서드 직접 테스트 | 구현 결합, 리팩토링 어려움 |
| sleep/delay 사용 | 불안정한 테스트 |
| 모든 것 모킹 | 실제 동작 검증 불가 |
| 테스트 내 조건문 | 복잡도 증가 |

---

## 테스트 네이밍 컨벤션

```typescript
// 패턴: should_[예상결과]_when_[조건]
it('should_return_empty_array_when_no_items', () => { ... });
it('should_throw_error_when_invalid_input', () => { ... });
it('should_calculate_discount_when_premium_user', () => { ... });

// 또는 BDD 스타일
describe('given premium user', () => {
  describe('when calculating discount', () => {
    it('then applies 20% off', () => { ... });
  });
});
```

---

## 출력 형식

```markdown
# Test Coverage Report

## Coverage Summary
- **Lines**: X% (X/X)
- **Functions**: X% (X/X)
- **Branches**: X% (X/X)

## Well-Tested Modules
- `module1.ts`: 95% coverage

## Needs Testing
- `module2.ts`: 45% coverage
  - Missing: 에러 핸들링 테스트
  - Missing: 엣지 케이스 커버리지

## Recommended Test Additions

### High Priority
1. **module.ts** - 에러 핸들링
   - 네트워크 실패 시나리오
   - 유효성 검사 에러 시나리오

### Medium Priority
2. **utils.ts** - 엣지 케이스
   - 빈 배열 입력
   - null/undefined 처리

## Generated Tests
[숫자] 개의 새 테스트 파일 생성
[숫자] 개의 테스트 케이스 추가
```

---

## 실행 지침

1. 코드 구조 분석 및 테스트 가능한 단위 식별
2. 사용 중인 테스트 프레임워크 감지 (Jest, Vitest, Mocha 등)
3. AAA 패턴에 따라 테스트 생성
4. Happy path와 엣지 케이스 모두 포함
5. 적절한 모킹 전략 적용
6. 테스트가 결정적이고 격리되어 있는지 확인
7. 설명적인 테스트 이름 사용
8. describe 블록으로 관련 테스트 그룹화
