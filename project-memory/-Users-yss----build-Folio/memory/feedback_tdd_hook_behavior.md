---
name: Folio TDD hook 동작과 우회 패턴
description: .claude/hooks/tdd-enforce.sh가 모든 .ts/.tsx 변경에 test 파일 강제. 타입/스타일 전용 변경 대응법
type: feedback
originSessionId: fa4d7468-5d81-4499-b474-305dc529d2ce
---
Folio `.claude/hooks/tdd-enforce.sh`가 Edit/Write 시 같은 폴더 또는 `__tests__/` 안에 대응 test 파일이 없으면 BLOCK. 타입 정의 / 스타일 전용 변경 / 단순 분기 추가도 모두 막힘.

## 대응 패턴

**1순위 — RED test 추가 후 GREEN**: 작은 shape 검증 또는 mock import 검증 test로 hook 만족 + TDD 사이클 살리기. 예:

```ts
// patterns.test.ts
import type { ProjectMockData } from "./patterns";
describe("ProjectMockData type", () => {
  it("필수 필드", () => {
    const sample: ProjectMockData = { /* ... */ };
    expect(sample.meta.manager).toBeTruthy();
  });
});
```

**type-only import는 vitest에서 erase되어 RED 안 보임** — TSC `--noEmit`으로 RED 검증 (컴파일 시점 타입 검사).

**2순위 — `CLAUDE_TDD_ENFORCE=off` 우회**: Tailwind 클래스 추가 같은 명백한 스타일 전용 변경에 한정. 1회 작업.

## test 파일 위치 hook 인식

hook이 두 경로 모두 OK:
- `<file>.test.(ts|tsx|js|jsx)` (같은 폴더)
- `__tests__/<file>.(ts|tsx|js|jsx)` (subdirectory)

**Why:** 단순 타입 추가/스타일 변경에 테스트 강제는 과해 보이지만, hook이 자동 분별 못 함. 매번 수동 판단보다 RED test 추가가 안전한 디폴트.

**How to apply:** Edit/Write 전에 같은 폴더 또는 `__tests__/`에 대응 test 파일 있는지 먼저 확인. 없으면 작은 RED test 작성 → BLOCK 회피.
