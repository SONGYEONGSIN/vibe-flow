---
name: useReducer 무한 re-render 방지 — same reference 반환 패턴
description: useReducer + useEffect deps 조합에서 reducer가 항상 새 객체/배열 반환 시 무한 루프, 변경 없으면 같은 reference 반환 필수
type: feedback
originSessionId: d01671ca-013e-4e2c-9a05-f2c8f79a3a18
---
useReducer를 쓰는 곳에서 reducer가 `states.map(...)` 같이 항상 새 array를 반환하면, useEffect deps의 외부 prop이 매 render마다 새 reference인 경우와 결합하여 **무한 re-render → OOM**으로 폭주한다.

```ts
// ❌ 위험: 매번 새 array 반환 → useReducer가 reference 다름으로 인식 → re-render
case "AUTO_STAGE_UPDATE": {
  return states.map((s) => {
    const next = action.stages[s.id];
    if (typeof next !== "number" || next === s.autoStage) return s;
    return { ...s, autoStage: next };
  });
}

// ✅ 안전: 변경 없으면 same reference
case "AUTO_STAGE_UPDATE": {
  let changed = false;
  const next = states.map((s) => {
    const v = action.stages[s.id];
    if (typeof v !== "number" || v === s.autoStage) return s;
    changed = true;
    return { ...s, autoStage: v };
  });
  return changed ? next : states;
}
```

**Why:** 2026-05-04 dashboard 캐릭터 Stage 자동 진화 작업에서 vitest worker가 OOM으로 죽음. 원인 추적: 테스트가 `autoStages: {}`를 매 render 새 객체로 전달 → useEffect 매번 트리거 → dispatch → reducer가 same-content지만 새 array 반환 → useReducer 재호출 → 새 props (autoStages={} 또 새 객체) → 무한. fake timer 환경에서 빠르게 폭주하여 OOM.

**How to apply:**
- React reducer 작성 시 항상 "변경 없으면 same reference" 가드 추가. 특히 `states.map()` 패턴.
- prop으로 받는 객체가 매 render 새로 만들어지는지(useMemo 안 씀, 또는 inline `{}`) 함께 검토 — production 코드는 `useMemo`로 감싸지만 테스트는 종종 새 객체 전달.
- 무한 루프 의심 시: vitest worker exit / OOM 메시지 → 가장 최근 추가한 dispatch effect와 reducer return 검사.
