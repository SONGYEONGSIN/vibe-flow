# 런타임 성능 분석 가이드

React Profiler, 메모리 누수 탐지, Long Task 분석 등 런타임 성능 문제를 진단하는 방법

---

## 1. React Profiler로 리렌더링 분석

### React DevTools Profiler (브라우저)

1. React DevTools 설치 (Chrome/Firefox 확장)
2. DevTools → Profiler 탭
3. Record → 문제 있는 인터랙션 수행 → Stop
4. Flamegraph에서 불필요한 리렌더링 확인:
   - 회색: 렌더링 안 됨 (memo 효과)
   - 노란색/빨간색: 렌더링 됨 (시간 기준)

### 코드 내 Profiler 컴포넌트

```tsx
import { Profiler } from 'react';

function onRenderCallback(
  id: string,           // Profiler의 id prop
  phase: 'mount' | 'update' | 'nested-update',
  actualDuration: number,   // 렌더링에 걸린 시간 (ms)
  baseDuration: number,     // memo 없이 걸릴 예상 시간
  startTime: number,
  commitTime: number,
) {
  if (actualDuration > 16) {  // 60fps 기준 1 프레임
    console.warn(`[Perf] ${id} 렌더링 ${actualDuration.toFixed(1)}ms`);
  }
}

export default function Page() {
  return (
    <Profiler id="ProductList" onRender={onRenderCallback}>
      <ProductList />
    </Profiler>
  );
}
```

### 코드 패턴으로 리렌더링 원인 탐지

```bash
# 인라인 함수 (리렌더링 시 새 참조 생성 → 자식 리렌더)
grep -rn "onClick={() =>" --include="*.tsx" app/ components/ 2>/dev/null | \
  grep -v node_modules | head -10

# 인라인 객체 (마찬가지로 새 참조)
grep -rn "style={{ " --include="*.tsx" app/ components/ 2>/dev/null | \
  grep -v node_modules | head -10

# useEffect 의존성 배열 없음 (무한 루프 가능성)
grep -rn "useEffect(" --include="*.tsx" -A2 2>/dev/null | \
  grep -B2 "\[\]" | grep -v node_modules | head -10
```

---

## 2. 메모리 누수 패턴

### 주요 메모리 누수 패턴

```tsx
// 패턴 1: useEffect cleanup 누락
// 나쁜 예
useEffect(() => {
  const handler = (e) => setMousePos({ x: e.clientX });
  window.addEventListener('mousemove', handler);
  // cleanup 없음 → 컴포넌트 언마운트 후에도 handler가 window에 남음
}, []);

// 좋은 예
useEffect(() => {
  const handler = (e) => setMousePos({ x: e.clientX });
  window.addEventListener('mousemove', handler);
  return () => window.removeEventListener('mousemove', handler);  // cleanup
}, []);

// 패턴 2: setInterval/setTimeout cleanup 누락
useEffect(() => {
  const id = setInterval(() => fetchData(), 1000);
  return () => clearInterval(id);  // 필수
}, []);

// 패턴 3: 언마운트 후 setState
useEffect(() => {
  let mounted = true;
  fetchData().then((data) => {
    if (mounted) setData(data);  // 언마운트 후 setState 방지
  });
  return () => { mounted = false; };
}, []);

// 패턴 4: AbortController로 fetch 취소
useEffect(() => {
  const controller = new AbortController();
  fetch('/api/data', { signal: controller.signal })
    .then(res => res.json())
    .then(setData)
    .catch(err => {
      if (err.name !== 'AbortError') console.error(err);
    });
  return () => controller.abort();
}, []);
```

### 코드 패턴으로 누수 가능성 탐지

```bash
# cleanup 없는 addEventListener 탐지
grep -rn "addEventListener" --include="*.tsx" --include="*.ts" \
  app/ components/ 2>/dev/null | grep -v node_modules | head -20
# 해당 파일에서 removeEventListener도 있는지 확인

# cleanup 없는 setInterval 탐지
grep -rn "setInterval" --include="*.tsx" --include="*.ts" \
  app/ components/ 2>/dev/null | grep -v node_modules | head -10

# fetch without AbortController
grep -rn "fetch(" --include="*.tsx" --include="*.ts" \
  app/ components/ 2>/dev/null | grep "useEffect\|async" | \
  grep -v "AbortController\|signal" | grep -v node_modules | head -10
```

---

## 3. Long Task 탐지

### PerformanceObserver로 Long Task 모니터링

```typescript
// 개발 환경에서만 Long Task 모니터링
if (process.env.NODE_ENV === 'development') {
  const observer = new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      console.warn(
        `[Long Task] ${entry.duration.toFixed(0)}ms at ${entry.startTime.toFixed(0)}ms`,
        entry
      );
    }
  });
  observer.observe({ type: 'longtask', buffered: true });
}
```

### Chrome DevTools Performance 탭에서 Long Task 확인

1. Performance 탭 → Record
2. 문제 인터랙션 수행
3. Stop → Main 트랙 확인
4. 빨간색 삼각형 = Long Task (50ms+)
5. 클릭 → Call Tree에서 원인 함수 확인

---

## 4. 불필요한 리렌더링 최적화

> 최적화 전 반드시 Profiler로 실제 문제를 확인한다. 무분별한 memo/useCallback은 오히려 성능을 낮춘다.

### React.memo — 컴포넌트 메모이제이션

```tsx
// 사용 적합: props가 자주 변경되지 않는 복잡한 컴포넌트
const ProductCard = React.memo(({ product, onAddToCart }) => {
  return (
    <div>
      <h3>{product.name}</h3>
      <button onClick={() => onAddToCart(product.id)}>Add to Cart</button>
    </div>
  );
});

// 커스텀 비교 함수 (필요한 경우만)
const ProductCard = React.memo(({ product }) => {
  return <div>{product.name}</div>;
}, (prevProps, nextProps) => {
  // true를 반환하면 리렌더링 건너뜀
  return prevProps.product.id === nextProps.product.id &&
         prevProps.product.price === nextProps.product.price;
});
```

### useCallback — 이벤트 핸들러 안정화

```tsx
// 적합: 자식 컴포넌트에 함수를 prop으로 전달할 때
function Parent() {
  const [count, setCount] = useState(0);

  // useCallback 없으면 매 렌더링마다 새 함수 참조 → ChildMemo 리렌더
  const handleAdd = useCallback(() => {
    setCount(c => c + 1);  // 함수형 업데이트로 deps 최소화
  }, []);  // 빈 배열 가능 — count 직접 참조 안 함

  return <ChildMemo onAdd={handleAdd} />;
}
```

### useMemo — 값 메모이제이션

```tsx
// 적합: 계산 비용이 높은 값
const filteredProducts = useMemo(() => {
  return products.filter(p => p.category === selectedCategory && p.price < maxPrice);
}, [products, selectedCategory, maxPrice]);

// 부적합: 단순 계산 (오버헤드가 더 클 수 있음)
const doubled = useMemo(() => count * 2, [count]);  // ❌ 불필요
const doubled = count * 2;  // 이게 더 나음
```

---

## 5. 렌더링 성능 측정

### 개발 환경에서 렌더링 추적

```typescript
// 커스텀 훅으로 리렌더 추적
function useRenderCount(label: string) {
  const renderCount = useRef(0);
  renderCount.current += 1;

  if (process.env.NODE_ENV === 'development') {
    console.log(`[${label}] 렌더 #${renderCount.current}`);
  }
}

// 사용
function ExpensiveComponent({ data }) {
  useRenderCount('ExpensiveComponent');
  // ...
}
```

### web-vitals로 INP 추적 (프로덕션)

```typescript
import { onINP } from 'web-vitals';

onINP(({ value, rating, attribution }) => {
  if (rating === 'poor') {
    // 느린 인터랙션 원인 분석
    const { eventType, eventTarget, eventTime, inputDelay, processingDuration, presentationDelay } = attribution;
    console.error('[INP Poor]', {
      value,
      eventType,    // 'click', 'keydown' 등
      eventTarget,  // 어떤 요소
      inputDelay,         // 입력 감지 지연
      processingDuration, // 이벤트 핸들러 실행 시간
      presentationDelay,  // 다음 프레임까지 대기
    });
  }
});
```

---

## 6. 코드 패턴 종합 점검

```bash
# 잠재적 메모리 누수 종합 체크
echo "=== addEventListener (cleanup 확인 필요) ==="
grep -rln "addEventListener" --include="*.tsx" --include="*.ts" \
  app/ components/ 2>/dev/null | grep -v node_modules

echo "=== setInterval/setTimeout (cleanup 확인 필요) ==="
grep -rn "setInterval\|setTimeout" --include="*.tsx" \
  app/ components/ 2>/dev/null | grep -v node_modules | grep -v "// "

echo "=== 무분별한 React.memo 사용 (실제 측정 후 적용 권장) ==="
grep -rn "React\.memo\|memo(" --include="*.tsx" \
  app/ components/ 2>/dev/null | grep -v node_modules | wc -l

echo "=== useEffect 의존성 배열 (잠재적 누락) ==="
# useEffect 후 2줄 내에 ], [] 없는 경우 탐지 (단순 휴리스틱)
grep -rn "useEffect(" --include="*.tsx" \
  app/ components/ 2>/dev/null | grep -v node_modules | wc -l
```
