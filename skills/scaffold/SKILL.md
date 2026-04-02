---
name: scaffold
description: 새 도메인의 보일러플레이트 파일을 프로젝트 패턴에 맞게 자동 생성한다. 사용법: /scaffold [domain-name]
---

`$ARGUMENTS` 도메인의 보일러플레이트를 생성한다.

## 생성 파일

모든 파일은 `src/` 하위에 생성한다.

### 1. 스키마 — `features/$ARGUMENTS/schemas.ts`

```typescript
import { z } from "zod";

export const create${Domain}Schema = z.object({
  // 필드 정의
});

export type Create${Domain}Input = z.infer<typeof create${Domain}Schema>;
```

### 2. 타입 — `features/$ARGUMENTS/types.ts`

```typescript
export interface ${Domain} {
  id: string;
  created_at: string;
  // 필드 정의
}

export interface ${Domain}ActionState {
  error?: string;
  success?: boolean;
}
```

### 3. 액션 — `features/$ARGUMENTS/actions.ts`

```typescript
"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { create${Domain}Schema } from "./schemas";
import type { ${Domain}ActionState } from "./types";

export async function create${Domain}(
  prevState: ${Domain}ActionState,
  formData: FormData,
): Promise<${Domain}ActionState> {
  const parsed = create${Domain}Schema.safeParse(
    Object.fromEntries(formData),
  );
  if (!parsed.success) {
    return { error: parsed.error.issues[0].message };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("$ARGUMENTS").insert(parsed.data);

  if (error) {
    return { error: error.message };
  }

  revalidatePath("/$ARGUMENTS");
  return { success: true };
}
```

### 4. 테스트 — `features/$ARGUMENTS/actions.test.ts`

```typescript
import { describe, it, expect, vi } from "vitest";

vi.mock("@/lib/supabase/server", () => ({
  createClient: vi.fn(),
}));

describe("$ARGUMENTS actions", () => {
  it("should validate input with zod schema", async () => {
    // TODO: 구현
  });
});
```

### 5. barrel export — `features/$ARGUMENTS/index.ts`

```typescript
export * from "./actions";
export * from "./schemas";
export * from "./types";
```

### 6. 페이지 — `app/$ARGUMENTS/page.tsx`

```typescript
export default function ${Domain}Page() {
  return (
    <main className="container mx-auto p-4">
      <h1 className="text-2xl font-bold">${Domain}</h1>
    </main>
  );
}
```

### 7. 컴포넌트 디렉토리 — `components/$ARGUMENTS/`

빈 디렉토리 생성 (컴포넌트는 필요에 따라 추가)

## 절차

1. `$ARGUMENTS`를 도메인명으로 사용
2. 도메인명을 PascalCase로 변환하여 `${Domain}`으로 사용
3. 위 파일들을 순서대로 생성
4. 생성된 파일 목록 출력
