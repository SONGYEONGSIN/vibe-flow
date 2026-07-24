---
name: ""
metadata: 
  node_type: memory
  originSessionId: 90fa3225-f069-423b-9fd5-1b1f1fc7bd0a
---

`"use server"` 파일(서버 액션 모듈)은 **export하는 모든 심볼이 async 함수**여야 한다. 동기 헬퍼/타입을 export하면 `next build`가 `Server Actions must be async functions`로 실패한다.

**Why:** 2026-05-23 자료요청 예약(actions.ts)에서 동기 순수함수 `parseScheduledAtKst`를 `"use server"` 파일에서 export → `next build` 빌드 에러. lint·typecheck·vitest는 **이 규칙을 강제하지 않아** 전부 통과했고 build만 잡아냄. (해결: 순수 헬퍼를 `schedule-time.ts` 같은 비-"use server" 모듈로 분리 후 액션에서 import.)

**How to apply:**
- 서버 액션 파일에는 async 액션 + (type/상수는 OK는 아님 — type export는 허용되나 값/함수 export는 async여야) — 순수 함수/상수 헬퍼는 별도 파일에 둔다.
- subagent-driven / 기능 완료 검증에서 **`unset NODE_ENV && npm run build`를 반드시 포함**한다. lint/typecheck/test만으로는 (1) use-server async 규칙, (2) RSC 직렬화 경계, (3) prerender/useContext 류를 못 잡는다. ([[nodeenv-leak-falsepositive]] 와 함께: build는 `unset NODE_ENV`로.)
