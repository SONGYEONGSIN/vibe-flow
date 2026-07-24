---
name: hydration-mismatch-fix-react-compiler-lint
description: "useState(loadInitial) localStorage 패턴 + Date.now() SSR/CSR mismatch를 useState([]) + useEffect(setX) 패턴으로 fix 시도 시 새 lint 룰 \"Calling setState synchronously within an effect\"에 차단. 다음 시도는 useSyncExternalStore 또는 dynamic({ssr:false})"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8a18890a-c371-4590-bb5c-6cf1f23166ac
---

## 발견 시점

2026-05-14, services PR-1 검증 트랙. services 페이지 hard reload 시 두 군데 mismatch:

1. **PageTabs OpenTabsProvider** — `useState<OpenTab[]>(loadInitial)` 안 `loadInitial()`이 `localStorage.getItem` 호출. SSR=`[]` / CSR=저장된 탭. 콘솔 표시: `+ <nav role="tablist" aria-label="열린 메뉴">`가 client에만 노출.

2. **ServicesTable** — `deadlineBadge`의 `const now = Date.now()`로 D-N 계산. SSR/CSR 시점 차이 1일 갈림 (잠재적).

## 시도한 fix (폐기됨)

전형적 SSR-safe 패턴:

```tsx
const [tabs, setTabs] = useState<OpenTab[]>([]);
const [hydrated, setHydrated] = useState(false);
useEffect(() => {
  setTabs(loadInitial());
  setHydrated(true);
}, []);
```

22 page-header test + 5 services Table test PASS, typecheck 0 에러. **그러나 ESLint react-compiler 계열 룰이 차단**:

```
Error: Calling setState synchronously within an effect can trigger cascading renders
(https://react.dev/learn/you-might-not-need-an-effect)
```

`rules/donts.md` "ESLint 경고가 있는 상태로 커밋 금지" + "eslint-disable 금지"와 정면 충돌.

## Why

React 19 + Next.js 16 + 새 eslint-config-next 16.2.4가 도입한 react-compiler 룰. mount useEffect 안에서 즉시 setState는 cascading render를 유발하여 권장하지 않음. 일반적인 hydration-safe 패턴은 룰 관점에서 anti-pattern.

## How to apply (다음 시도)

### A. dynamic({ ssr: false }) — 서지컬 권장

```tsx
import dynamic from "next/dynamic";
const PageTabs = dynamic(
  () => import("./PageTabs").then((m) => ({ default: m.PageTabs })),
  { ssr: false },
);
```

- PageTabs는 CSR에서만 렌더 → mismatch 0
- OpenTabsProvider는 원본 `useState(loadInitial)` 유지 (CSR만 실행되므로 안전)
- ServicesTable D-N도 동일: D-N 셀만 별도 client component로 분리하여 dynamic ssr:false

### B. useSyncExternalStore — 정공법

```tsx
const tabs = useSyncExternalStore(
  subscribeToStorage,
  getSnapshot,
  getServerSnapshot,  // 항상 [] 반환 → SSR/CSR 첫 render 동일
);
```

- React 19 권장 hydration-safe external store
- OpenTabsState 인터페이스 변경 큼 (add/close도 store 모듈 함수로)

권장: **A (dynamic ssr:false)** — 변경량 적고 lint 통과.

## 관련

- [[project_next_session_seed]] — 다음 세션 시드에 fix path 명시
- [[feedback_signup_password_pattern]] — 기존 "SSR-safe 시계" 패턴은 setInterval 콜백 안에서 setState (immediate 아님)이라 룰 위반 X — 새 mount-immediate setState 패턴이 룰 위반
