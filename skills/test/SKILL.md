---
name: test
description: 지정 파일에 대한 Vitest 단위 테스트를 자동 생성한다. 사용법: /test [file-path]
---

`$ARGUMENTS` 파일에 대한 Vitest 단위 테스트를 생성한다.

## 절차

1. 대상 파일(`$ARGUMENTS`) 읽기 및 분석
2. 기존 테스트 패턴 참조:
   - `features/auth/actions.test.ts`
   - `features/todos/actions.test.ts`
   - `features/dashboard/queries.test.ts`
3. 기존 패턴과 일관된 스타일로 테스트 작성:
   - `describe` / `it` 구조
   - Supabase mock 패턴
   - 성공/실패 케이스 모두 포함
4. 테스트 파일 생성 (같은 디렉토리에 `.test.ts` 접미사)
5. `npm test -- --run [test-file]` 로 실행 확인

## 테스트 패턴

```typescript
import { describe, it, expect, vi } from "vitest";

vi.mock("@/lib/supabase/server", () => ({
  createClient: vi.fn(),
}));

describe("functionName", () => {
  it("should handle valid input", async () => {
    // arrange → act → assert
  });

  it("should reject invalid input", async () => {
    // zod 검증 실패 케이스
  });

  it("should handle Supabase error", async () => {
    // Supabase 에러 케이스
  });
});
```

## 규칙

- 기존 테스트 스타일을 반드시 분석 후 작성
- 최소 3개 이상의 테스트 케이스 (성공, 검증실패, 에러)
- Supabase 호출은 vi.mock으로 모킹
- 테스트 실행 후 통과 확인 필수
