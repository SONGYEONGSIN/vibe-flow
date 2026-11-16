# 설계 원칙 가이드

TRD 작성 및 아키텍처 설계 시 반드시 검토해야 할 원칙과 패턴.

---

## SOLID 원칙

### SRP (Single Responsibility Principle)

**체크**: 클래스/모듈이 변경되어야 하는 이유가 하나인가?

```typescript
// Bad - 여러 책임이 섞여 있음
class UserService {
  saveUser(user: User) { /* DB 저장 */ }
  sendWelcomeEmail(user: User) { /* 이메일 발송 */ }
  generateUserReport(user: User) { /* 리포트 생성 */ }
}

// Good - 책임별로 분리
class UserService {
  saveUser(user: User) { /* DB 저장 */ }
}
class EmailService {
  sendWelcomeEmail(user: User) { /* 이메일 발송 */ }
}
class ReportService {
  generateUserReport(user: User) { /* 리포트 생성 */ }
}
```

---

### OCP (Open-Closed Principle)

**체크**: 기존 코드 수정 없이 기능 확장이 가능한가?

```typescript
// Bad - 새 결제 수단 추가 시 기존 코드 수정 필요
class PaymentService {
  process(type: string, amount: number) {
    if (type === 'card') { /* 카드 결제 */ }
    else if (type === 'bank') { /* 계좌이체 */ }
    // 새 결제 수단 추가 시 여기 수정해야 함
  }
}

// Good - 새 결제 수단은 새 클래스로 추가
interface PaymentProcessor {
  process(amount: number): void
}
class CardPayment implements PaymentProcessor {
  process(amount: number) { /* 카드 결제 */ }
}
class BankPayment implements PaymentProcessor {
  process(amount: number) { /* 계좌이체 */ }
}
// 새 결제 수단: 새 클래스만 추가하면 됨
```

---

### LSP (Liskov Substitution Principle)

**체크**: 자식 클래스가 부모 클래스를 대체해도 문제없는가?

```typescript
// Bad - 자식이 부모의 계약을 위반
class Rectangle {
  setWidth(w: number) { this.width = w }
  setHeight(h: number) { this.height = h }
  getArea() { return this.width * this.height }
}
class Square extends Rectangle {
  setWidth(w: number) { this.width = w; this.height = w } // 계약 위반!
  setHeight(h: number) { this.width = h; this.height = h }
}

// Good - 상속 대신 별도 클래스
interface Shape {
  getArea(): number
}
class Rectangle implements Shape {
  constructor(private width: number, private height: number) {}
  getArea() { return this.width * this.height }
}
class Square implements Shape {
  constructor(private side: number) {}
  getArea() { return this.side * this.side }
}
```

---

### ISP (Interface Segregation Principle)

**체크**: 사용하지 않는 메서드에 의존하고 있지 않은가?

```typescript
// Bad - 모든 기능이 하나의 인터페이스에
interface Worker {
  work(): void
  eat(): void
  sleep(): void
}
class Robot implements Worker {
  work() { /* 작업 */ }
  eat() { throw new Error('로봇은 못 먹음') } // 불필요한 구현
  sleep() { throw new Error('로봇은 안 잠') }
}

// Good - 인터페이스 분리
interface Workable { work(): void }
interface Eatable { eat(): void }
interface Sleepable { sleep(): void }

class Human implements Workable, Eatable, Sleepable {
  work() { /* 작업 */ }
  eat() { /* 식사 */ }
  sleep() { /* 수면 */ }
}
class Robot implements Workable {
  work() { /* 작업 */ }
}
```

---

### DIP (Dependency Inversion Principle)

**체크**: 구체 클래스가 아닌 추상화(인터페이스)에 의존하는가?

```typescript
// Bad - 구체 클래스에 직접 의존
class UserService {
  private db = new MySQLDatabase() // 구체 클래스에 의존

  getUser(id: string) {
    return this.db.query(`SELECT * FROM users WHERE id = ${id}`)
  }
}

// Good - 인터페이스에 의존
interface Database {
  query(sql: string): any
}
class UserService {
  constructor(private db: Database) {} // 추상화에 의존

  getUser(id: string) {
    return this.db.query(`SELECT * FROM users WHERE id = ${id}`)
  }
}
// 사용 시 주입
const service = new UserService(new MySQLDatabase())
// 테스트 시 mock 주입 가능
const testService = new UserService(new MockDatabase())
```

---

## 설계 패턴

### Repository 패턴

**언제**: 데이터 접근 로직을 비즈니스 로직에서 분리할 때

```typescript
// Bad - 비즈니스 로직에 DB 쿼리가 섞여 있음
class UserService {
  async getActiveUsers() {
    const users = await db.query('SELECT * FROM users WHERE status = "active"')
    return users.filter(u => u.lastLogin > thirtyDaysAgo)
  }
}

// Good - Repository로 데이터 접근 분리
class UserRepository {
  async findAll(): Promise<User[]> {
    return await db.query('SELECT * FROM users')
  }
  async findByStatus(status: string): Promise<User[]> {
    return await db.query('SELECT * FROM users WHERE status = ?', [status])
  }
}

class UserService {
  constructor(private userRepo: UserRepository) {}

  async getActiveUsers() {
    const users = await this.userRepo.findByStatus('active')
    return users.filter(u => u.lastLogin > thirtyDaysAgo)
  }
}
```

**장점**:
- 비즈니스 로직이 DB 구현에 독립적
- 테스트 시 Repository만 mock 가능
- DB 변경 시 Repository만 수정

---

### Factory 패턴

**언제**: 객체 생성 로직이 복잡하거나 조건에 따라 다른 객체를 생성할 때

```typescript
// Bad - 생성 로직이 여러 곳에 중복
function handlePayment(type: string, amount: number) {
  let processor
  if (type === 'card') {
    processor = new CardProcessor()
    processor.setMerchantId('xxx')
    processor.setApiKey('yyy')
  } else if (type === 'bank') {
    processor = new BankProcessor()
    processor.setBankCode('zzz')
  }
  return processor.process(amount)
}

// Good - Factory로 생성 로직 캡슐화
class PaymentProcessorFactory {
  static create(type: string): PaymentProcessor {
    switch (type) {
      case 'card':
        const card = new CardProcessor()
        card.setMerchantId('xxx')
        card.setApiKey('yyy')
        return card
      case 'bank':
        const bank = new BankProcessor()
        bank.setBankCode('zzz')
        return bank
      default:
        throw new Error(`Unknown payment type: ${type}`)
    }
  }
}

function handlePayment(type: string, amount: number) {
  const processor = PaymentProcessorFactory.create(type)
  return processor.process(amount)
}
```

**장점**:
- 생성 로직 중앙화
- 새 타입 추가 시 Factory만 수정
- 클라이언트 코드가 단순해짐

---

### Strategy 패턴

**언제**: 알고리즘/정책을 런타임에 교체해야 할 때, if-else 체인을 제거할 때

```typescript
// Bad - 조건문이 계속 늘어남
class PriceCalculator {
  calculate(price: number, userType: string): number {
    if (userType === 'vip') {
      return price * 0.8 // 20% 할인
    } else if (userType === 'member') {
      return price * 0.9 // 10% 할인
    } else if (userType === 'new') {
      return price * 0.95 // 5% 할인
    }
    return price
  }
}

// Good - Strategy로 알고리즘 분리
interface DiscountStrategy {
  apply(price: number): number
}

class VipDiscount implements DiscountStrategy {
  apply(price: number) { return price * 0.8 }
}
class MemberDiscount implements DiscountStrategy {
  apply(price: number) { return price * 0.9 }
}
class NewUserDiscount implements DiscountStrategy {
  apply(price: number) { return price * 0.95 }
}
class NoDiscount implements DiscountStrategy {
  apply(price: number) { return price }
}

class PriceCalculator {
  constructor(private strategy: DiscountStrategy) {}

  calculate(price: number): number {
    return this.strategy.apply(price)
  }
}

// 사용
const calculator = new PriceCalculator(new VipDiscount())
calculator.calculate(10000) // 8000
```

**장점**:
- 알고리즘 추가/수정이 기존 코드에 영향 없음
- 런타임에 전략 교체 가능
- 테스트가 쉬움 (각 전략 독립 테스트)

---

## 체크리스트

### 아키텍처 설계 전 확인

```markdown
## SOLID
- [ ] SRP: 각 클래스/모듈이 하나의 책임만 갖는가?
- [ ] OCP: 기존 코드 수정 없이 확장 가능한가?
- [ ] LSP: 상속 관계가 올바른가? (자식이 부모 대체 가능?)
- [ ] ISP: 인터페이스가 적절히 분리되어 있는가?
- [ ] DIP: 구체 클래스가 아닌 추상화에 의존하는가?

## 패턴 적용 검토
- [ ] Repository: 데이터 접근 로직이 비즈니스 로직과 분리되어야 하는가?
- [ ] Factory: 복잡한 객체 생성 로직이 있는가?
- [ ] Strategy: 조건에 따라 다른 알고리즘을 적용해야 하는가?
```
