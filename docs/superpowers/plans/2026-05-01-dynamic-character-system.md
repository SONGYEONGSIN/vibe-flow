# 동적 캐릭터 시스템 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** vibe-flow-dashboard의 `/characters` 페이지에 12 chibi 캐릭터가 events.jsonl 트리거에 반응하는 픽셀 룸 무대를 만든다.

**Architecture:** Next.js App Router 페이지. 기존 `EventsWatcher` (`src/lib/events-watcher.ts`)와 `/api/events` SSE 인프라 재사용. 캐릭터 상태는 React `useReducer`, 애니메이션은 CSS `transform` + `transition`만 (게임 엔진 X). 모든 비-UI 로직(매핑, wander, dialogue 선택, reducer)은 순수 함수로 추출하여 Vitest 단위 테스트.

**Tech Stack:** Next.js 16, React 19, TypeScript 5, Tailwind 4, Vitest + React Testing Library + jsdom

**Spec:** `docs/superpowers/specs/2026-04-30-dynamic-character-system-design.md`

**Repo:** 모든 구현은 `/Users/yss/개발/build/vibe-flow-dashboard/` 안. plan 자체는 `vibe-flow` repo의 `docs/superpowers/plans/`에 위치.

---

## File Structure

**새로 만들 파일** (vibe-flow-dashboard repo 기준):

```
vitest.config.ts                                      # Vitest 설정
vitest.setup.ts                                       # RTL 매처 setup

src/app/characters/
├── page.tsx                                          # /characters 라우트 (서버 컴포넌트)
├── CharacterStage.client.tsx                         # 클라이언트 진입점 (use client)
├── Stage.tsx                                         # 룸 배경 + 12 캐릭터 컨테이너
├── Character.tsx                                     # 단일 캐릭터 표시
├── SpeechBubble.tsx                                  # 말풍선
├── useEventsStream.ts                                # SSE 구독 hook
├── useCharacterEngine.ts                             # 캐릭터 상태/애니/타이머 hook
├── data/
│   ├── agents.ts                                     # Character Bible (12 캐릭터 명세)
│   ├── stage-unlock.ts                               # Stage → unlocked 캐릭터 매핑
│   ├── event-map.ts                                  # event → action/target 매핑
│   └── dialogue-pool.json                            # 대사 풀
└── lib/
    ├── dialogue.ts                                   # pickLine 로직 (last-used 회피)
    ├── wander.ts                                     # wander 좌표 산출 (순수)
    ├── reducer.ts                                    # 캐릭터 state reducer (순수)
    └── __tests__/                                    # Vitest 테스트
        ├── dialogue.test.ts
        ├── wander.test.ts
        ├── reducer.test.ts
        ├── event-map.test.ts
        └── stage-unlock.test.ts

src/app/characters/__tests__/
└── useCharacterEngine.test.tsx                       # hook 통합 테스트

src/app/api/vibe-flow/stage/route.ts                  # .vibe-flow.json stage 읽는 API

public/sprites/
└── <agent>.png × 12                                  # placeholder PNG (48×48 단색)
```

**수정할 파일:**
- `package.json` — Vitest + RTL devDependencies 추가
- `tsconfig.json` — vitest types 추가 (선택)
- `src/app/page.tsx` — /characters 링크 추가 (헤더 nav)
- `vibe-flow/ROADMAP.md` — 진행중 표시 → 완료 표시

---

## Task 1: Vitest + React Testing Library 설치

**Files:**
- Modify: `/Users/yss/개발/build/vibe-flow-dashboard/package.json`
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/vitest.config.ts`
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/vitest.setup.ts`

- [ ] **Step 1: devDependencies 추가**

`vibe-flow-dashboard/package.json`의 `devDependencies`에 다음 5개 + `scripts`에 test 추가. 전체 구조:

```json
{
  "name": "vibe-flow-dashboard",
  "version": "1.0.0",
  "private": true,
  "description": "vibe-flow의 라이브 메트릭 + inbox + 활성 plan + .claude 구조 대시보드. Next.js + chokidar + SSE.",
  "scripts": {
    "dev": "next dev --port 9999",
    "build": "next build",
    "start": "next start --port 9999",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "chokidar": "^5.0.0",
    "next": "16.2.4",
    "react": "19.2.4",
    "react-dom": "19.2.4"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4",
    "@testing-library/jest-dom": "^6.5.0",
    "@testing-library/react": "^16.1.0",
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "@vitejs/plugin-react": "^4.3.4",
    "jsdom": "^25.0.1",
    "tailwindcss": "^4",
    "typescript": "^5",
    "vitest": "^2.1.8"
  }
}
```

- [ ] **Step 2: vitest.config.ts 작성**

```ts
// vibe-flow-dashboard/vitest.config.ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "node:path";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    setupFiles: ["./vitest.setup.ts"],
    globals: true,
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

- [ ] **Step 3: vitest.setup.ts 작성**

```ts
// vibe-flow-dashboard/vitest.setup.ts
import "@testing-library/jest-dom/vitest";
```

- [ ] **Step 4: 의존성 설치**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm install
```

Expected: 추가 패키지 5개(jsdom, vitest, @vitejs/plugin-react, @testing-library/react, @testing-library/jest-dom) 설치 완료.

- [ ] **Step 5: smoke 테스트로 동작 확인**

`vibe-flow-dashboard/src/__tests__/smoke.test.ts` 임시 파일:

```ts
import { describe, it, expect } from "vitest";

describe("vitest smoke", () => {
  it("works", () => {
    expect(1 + 1).toBe(2);
  });
});
```

실행:
```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test
```

Expected: `smoke.test.ts` 1 passed.

- [ ] **Step 6: smoke 테스트 삭제**

```bash
rm /Users/yss/개발/build/vibe-flow-dashboard/src/__tests__/smoke.test.ts
rmdir /Users/yss/개발/build/vibe-flow-dashboard/src/__tests__ 2>/dev/null || true
```

- [ ] **Step 7: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add package.json package-lock.json vitest.config.ts vitest.setup.ts && git commit -m "chore: add Vitest + React Testing Library"
```

---

## Task 2: Agent Types + Character Bible

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/data/agents.ts`

- [ ] **Step 1: agents.ts 작성**

12 캐릭터 명세를 type-safe하게 정의. spec 5.1 표 그대로.

```ts
// src/app/characters/data/agents.ts
export type AgentId =
  | "planner"
  | "designer"
  | "developer"
  | "qa"
  | "security"
  | "validator"
  | "feedback"
  | "moderator"
  | "comparator"
  | "retrospective"
  | "grader"
  | "skill-reviewer";

export type AgentMeta = {
  id: AgentId;
  name: string;          // 표시용 짧은 이름
  concept: string;       // 한 줄 컨셉
  motif: string;         // 핵심 모티프
  mainColor: string;     // CSS 색상
  accentColor?: string;  // 보조 컬러
  spritePath: string;    // public/sprites/ 기준 base path (확장자 제외)
  unlockStage: number;   // 이 stage 이상이어야 unlock
};

export const AGENTS: AgentMeta[] = [
  { id: "planner",       name: "Plan",  concept: "길쭉한 안테나 책상님",   motif: "클립보드, 안테나",    mainColor: "#5e9bd6", accentColor: "#ffffff", spritePath: "/sprites/planner",       unlockStage: 0 },
  { id: "designer",      name: "Des",   concept: "베레모 쓴 마젠타",       motif: "베레모, 팔레트",      mainColor: "#e36ba7", accentColor: "#f4d65b", spritePath: "/sprites/designer",      unlockStage: 0 },
  { id: "developer",     name: "Dev",   concept: "정사각 헤드폰러",        motif: "헤드폰",             mainColor: "#5fb380", accentColor: "#1a1a1a", spritePath: "/sprites/developer",     unlockStage: 1 },
  { id: "qa",            name: "QA",    concept: "큰 눈 탐정",            motif: "큰 눈, 돋보기",       mainColor: "#7dd6c2", accentColor: "#1a1a1a", spritePath: "/sprites/qa",            unlockStage: 1 },
  { id: "security",      name: "Sec",   concept: "헬멧+바이저 경비",       motif: "헬멧, 배지",         mainColor: "#3a3a4a", accentColor: "#dba83b", spritePath: "/sprites/security",      unlockStage: 3 },
  { id: "validator",     name: "Val",   concept: "기둥형 + 가슴 별",       motif: "기둥, 별",           mainColor: "#3da068", accentColor: "#f4d65b", spritePath: "/sprites/validator",     unlockStage: 2 },
  { id: "feedback",      name: "Fb",    concept: "털 한 가닥 + 큰 입",     motif: "털, 큰 입",          mainColor: "#f5b8d2", accentColor: "#1a1a1a", spritePath: "/sprites/feedback",      unlockStage: 2 },
  { id: "moderator",     name: "Mod",   concept: "통통 콧수염 망치",       motif: "콧수염, 망치",        mainColor: "#a89366", accentColor: "#5a3f1a", spritePath: "/sprites/moderator",     unlockStage: 2 },
  { id: "comparator",    name: "Cmp",   concept: "듀얼톤 좌우반반",        motif: "VS 표식",            mainColor: "#5e9bd6", accentColor: "#d97757", spritePath: "/sprites/comparator",    unlockStage: 3 },
  { id: "retrospective", name: "Ret",   concept: "안경 + 책 더미",         motif: "안경, 책",            mainColor: "#8b6cb0", accentColor: "#d97757", spritePath: "/sprites/retrospective", unlockStage: 3 },
  { id: "grader",        name: "Grd",   concept: "차트 든 회색",           motif: "차트",              mainColor: "#6c8db5", accentColor: "#1a1a1a", spritePath: "/sprites/grader",        unlockStage: 4 },
  { id: "skill-reviewer",name: "SkR",   concept: "캡 + 렌치 작업복",       motif: "캡, 렌치",           mainColor: "#7a8290", accentColor: "#d97757", spritePath: "/sprites/skill-reviewer",unlockStage: 4 },
];

export const AGENT_MAP: Record<AgentId, AgentMeta> = Object.fromEntries(
  AGENTS.map((a) => [a.id, a])
) as Record<AgentId, AgentMeta>;
```

- [ ] **Step 2: 타입 체크**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npx tsc --noEmit
```

Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/data/agents.ts && git commit -m "feat(characters): add Character Bible (12 agents)"
```

---

## Task 3: Stage Unlock 매핑

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/data/stage-unlock.ts`
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/lib/__tests__/stage-unlock.test.ts`

- [ ] **Step 1: 실패 테스트 작성**

```ts
// src/app/characters/lib/__tests__/stage-unlock.test.ts
import { describe, it, expect } from "vitest";
import { isUnlocked, unlockedAgents } from "@/app/characters/data/stage-unlock";

describe("stage-unlock", () => {
  it("Stage 0에서 planner/designer만 unlock", () => {
    expect(isUnlocked("planner", 0)).toBe(true);
    expect(isUnlocked("designer", 0)).toBe(true);
    expect(isUnlocked("developer", 0)).toBe(false);
    expect(isUnlocked("validator", 0)).toBe(false);
  });

  it("Stage 2에서 validator unlock", () => {
    expect(isUnlocked("validator", 2)).toBe(true);
    expect(isUnlocked("security", 2)).toBe(false);
  });

  it("Stage 4에서 모든 캐릭터 unlock", () => {
    const all = unlockedAgents(4);
    expect(all).toHaveLength(12);
  });

  it("Stage 1 default 적용 (음수/null 처리)", () => {
    expect(isUnlocked("developer", -1)).toBe(true); // -1 → 1로 보정
    expect(isUnlocked("developer", null as unknown as number)).toBe(true);
  });
});
```

- [ ] **Step 2: 실패 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- stage-unlock
```

Expected: FAIL — `Cannot find module '@/app/characters/data/stage-unlock'`.

- [ ] **Step 3: 구현**

```ts
// src/app/characters/data/stage-unlock.ts
import { AGENTS, type AgentId } from "./agents";

const DEFAULT_STAGE = 1;

function normalizeStage(stage: number | null | undefined): number {
  if (stage === null || stage === undefined || Number.isNaN(stage)) return DEFAULT_STAGE;
  if (stage < 0) return DEFAULT_STAGE;
  return Math.min(4, Math.floor(stage));
}

export function isUnlocked(agent: AgentId, stage: number | null | undefined): boolean {
  const normStage = normalizeStage(stage);
  const meta = AGENTS.find((a) => a.id === agent);
  if (!meta) return false;
  return meta.unlockStage <= normStage;
}

export function unlockedAgents(stage: number | null | undefined): AgentId[] {
  const normStage = normalizeStage(stage);
  return AGENTS.filter((a) => a.unlockStage <= normStage).map((a) => a.id);
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- stage-unlock
```

Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/data/stage-unlock.ts src/app/characters/lib/__tests__/stage-unlock.test.ts && git commit -m "feat(characters): add Stage unlock mapping"
```

---

## Task 4: Event Map (events → action)

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/data/event-map.ts`
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/lib/__tests__/event-map.test.ts`

- [ ] **Step 1: 실패 테스트 작성**

```ts
// src/app/characters/lib/__tests__/event-map.test.ts
import { describe, it, expect } from "vitest";
import { mapEvent } from "@/app/characters/data/event-map";

describe("event-map", () => {
  it("tool_result pass → 매칭 캐릭터 jump", () => {
    const r = mapEvent({
      type: "tool_result",
      tool: "prettier",
      status: "pass",
    });
    expect(r).toEqual([
      { agent: "designer", action: "jump", dialogueKey: "tool_pass" },
    ]);
  });

  it("tool_result fail → 매칭 + qa walk-to", () => {
    const r = mapEvent({
      type: "tool_result",
      tool: "tsc",
      status: "fail",
    });
    expect(r).toContainEqual({ agent: "developer", action: "idle", dialogueKey: "tool_fail" });
    expect(r).toContainEqual({ agent: "qa", action: "walk-to", target: "developer", dialogueKey: "investigation" });
  });

  it("verify_complete pass → validator jump", () => {
    const r = mapEvent({ type: "verify_complete", overall: "pass", results: [] });
    expect(r).toEqual([
      { agent: "validator", action: "jump", dialogueKey: "approved" },
    ]);
  });

  it("verify_complete fail → validator walk-to 첫 실패 hook", () => {
    const r = mapEvent({
      type: "verify_complete",
      overall: "fail",
      results: [
        { hook: "tsc", status: "fail" },
        { hook: "test", status: "pass" },
      ],
    });
    expect(r).toContainEqual({ agent: "validator", action: "walk-to", target: "developer", dialogueKey: "rejected" });
    expect(r).toContainEqual({ agent: "developer", action: "idle", dialogueKey: "tool_fail" });
  });

  it("unknown tool → moderator fallback", () => {
    const r = mapEvent({ type: "tool_result", tool: "mystery_tool", status: "pass" });
    expect(r[0].agent).toBe("moderator");
  });

  it("알 수 없는 type → 빈 배열", () => {
    const r = mapEvent({ type: "garbage" });
    expect(r).toEqual([]);
  });
});
```

- [ ] **Step 2: 실패 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- event-map
```

Expected: FAIL — module not found.

- [ ] **Step 3: 구현**

```ts
// src/app/characters/data/event-map.ts
import type { AgentId } from "./agents";

export type CharacterAction = "idle" | "walk-to" | "jump" | "clap";

export type ActionInstruction = {
  agent: AgentId;
  action: CharacterAction;
  target?: AgentId;       // walk-to 시 대상
  dialogueKey: string;    // dialogue-pool.json의 contextKey
};

const TOOL_TO_AGENT: Record<string, AgentId> = {
  prettier: "designer",
  eslint: "designer",
  tsc: "developer",
  test: "qa",
  vitest: "qa",
  playwright: "qa",
};
const FALLBACK_AGENT: AgentId = "moderator";

function agentForTool(tool: string | undefined): AgentId {
  if (!tool) return FALLBACK_AGENT;
  return TOOL_TO_AGENT[tool] ?? FALLBACK_AGENT;
}

type RawEvent = Record<string, unknown>;

export function mapEvent(event: RawEvent): ActionInstruction[] {
  const type = event.type;

  if (type === "tool_result") {
    const tool = String(event.tool ?? "");
    const status = event.status;
    const agent = agentForTool(tool);
    if (status === "pass") {
      return [{ agent, action: "jump", dialogueKey: "tool_pass" }];
    }
    if (status === "fail") {
      return [
        { agent, action: "idle", dialogueKey: "tool_fail" },
        { agent: "qa", action: "walk-to", target: agent, dialogueKey: "investigation" },
      ];
    }
  }

  if (type === "verify_complete") {
    const overall = event.overall;
    if (overall === "pass") {
      return [{ agent: "validator", action: "jump", dialogueKey: "approved" }];
    }
    if (overall === "fail") {
      const results = Array.isArray(event.results) ? (event.results as Array<Record<string, unknown>>) : [];
      const firstFail = results.find((r) => r.status === "fail");
      const failedHook = firstFail ? String(firstFail.hook ?? "") : "";
      const target = agentForTool(failedHook);
      return [
        { agent: "validator", action: "walk-to", target, dialogueKey: "rejected" },
        { agent: target, action: "idle", dialogueKey: "tool_fail" },
      ];
    }
  }

  if (type === "error") {
    const tool = String(event.tool ?? "");
    const target = agentForTool(tool);
    return [
      { agent: "qa", action: "walk-to", target, dialogueKey: "bug_found" },
      { agent: target, action: "idle", dialogueKey: "tool_fail" },
    ];
  }

  return [];
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- event-map
```

Expected: 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/data/event-map.ts src/app/characters/lib/__tests__/event-map.test.ts && git commit -m "feat(characters): add event → action mapping"
```

---

## Task 5: Dialogue Pool + pickLine

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/data/dialogue-pool.json`
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/lib/dialogue.ts`
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/lib/__tests__/dialogue.test.ts`

- [ ] **Step 1: dialogue-pool.json 작성**

12 캐릭터 × 5 컨텍스트 키 × 3~5 대사. spec 6.5 형식.

```json
{
  "planner": {
    "tool_pass":   ["계획대로다", "다음 단계 OK", "흠... 좋아"],
    "tool_fail":   ["다시 짜자", "계획 수정"],
    "investigation": ["루트 캐스 찾자"],
    "wander":      ["다음은…", "📋"]
  },
  "designer": {
    "tool_pass":   ["디자인 살아남! 🎨", "또 한 픽셀 추가!", "예쁘다…", "린트 깨끗", "포맷 ✨"],
    "tool_fail":   ["어… 다시 볼게", "스타일 어긋남", "줄 맞춰야지"],
    "wander":      ["흠…", "스케치 중", "🎨"]
  },
  "developer": {
    "tool_pass":   ["타입 통과", "컴파일 OK", "⚡ 빨라!"],
    "tool_fail":   ["타입 안 맞음", "컴파일 실패…", "수정 중"],
    "wander":      ["코드 짠다", "⚡"]
  },
  "qa": {
    "tool_pass":   ["좋아", "테스트 OK"],
    "tool_fail":   ["버그다!", "재현 시도", "🔍"],
    "bug_found":   ["여기다!", "이거 봐!"],
    "investigation": ["확인 중…", "🔍"],
    "wander":      ["흠…"]
  },
  "security": {
    "tool_pass":   ["안전", "🛡️"],
    "tool_fail":   ["취약점", "다시 점검"],
    "wander":      ["순찰 중", "🛡️"]
  },
  "validator": {
    "approved":    ["통과!", "GOOD ✨", "넘겨라", "✅"],
    "rejected":    ["다시", "안 됨", "수정 필요"],
    "wander":      ["검토 중", "확인…"]
  },
  "feedback": {
    "tool_pass":   ["깔끔해!", "💬"],
    "tool_fail":   ["피드백 있음", "이거 보자"],
    "wander":      ["💬", "흠…"]
  },
  "moderator": {
    "tool_pass":   ["진행 OK", "⚖️"],
    "tool_fail":   ["조정 필요", "잠시…"],
    "wander":      ["⚖️", "조용…"]
  },
  "comparator": {
    "tool_pass":   ["A가 낫다", "B가 낫다"],
    "tool_fail":   ["둘 다 미흡"],
    "wander":      ["🆚", "비교 중"]
  },
  "retrospective": {
    "tool_pass":   ["기록함", "📚"],
    "tool_fail":   ["학습 거리"],
    "wander":      ["📚", "회고…"]
  },
  "grader": {
    "tool_pass":   ["A+", "📊"],
    "tool_fail":   ["F"],
    "wander":      ["📊"]
  },
  "skill-reviewer": {
    "tool_pass":   ["스킬 OK", "🔧"],
    "tool_fail":   ["수리 필요"],
    "wander":      ["🔧"]
  }
}
```

- [ ] **Step 2: pickLine 실패 테스트 작성**

```ts
// src/app/characters/lib/__tests__/dialogue.test.ts
import { describe, it, expect } from "vitest";
import { pickLine } from "@/app/characters/lib/dialogue";

const pool = {
  designer: {
    tool_pass: ["a", "b", "c"],
    wander: ["x"],
  },
  qa: {},
};

describe("pickLine", () => {
  it("풀에서 한 개 반환", () => {
    const used = new Map<string, string[]>();
    const line = pickLine(pool, "designer", "tool_pass", used, () => 0);
    expect(["a", "b", "c"]).toContain(line);
  });

  it("최근 사용 대사 회피", () => {
    const used = new Map<string, string[]>([["designer:tool_pass", ["a", "b"]]]);
    const line = pickLine(pool, "designer", "tool_pass", used, () => 0);
    expect(line).toBe("c");
  });

  it("모든 대사가 최근 사용이면 풀 전체에서 선택", () => {
    const used = new Map<string, string[]>([["designer:tool_pass", ["a", "b", "c"]]]);
    const line = pickLine(pool, "designer", "tool_pass", used, () => 0);
    expect(["a", "b", "c"]).toContain(line);
  });

  it("빈 풀이면 null", () => {
    const used = new Map<string, string[]>();
    const line = pickLine(pool, "qa", "tool_pass", used, () => 0);
    expect(line).toBeNull();
  });

  it("없는 캐릭터/키이면 null", () => {
    const used = new Map<string, string[]>();
    expect(pickLine(pool, "feedback" as never, "x", used, () => 0)).toBeNull();
  });
});
```

- [ ] **Step 3: 실패 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- dialogue
```

Expected: FAIL — module not found.

- [ ] **Step 4: dialogue.ts 구현**

```ts
// src/app/characters/lib/dialogue.ts
import type { AgentId } from "@/app/characters/data/agents";

export type DialoguePool = Partial<Record<AgentId, Record<string, string[]>>>;

const RECENT_LIMIT = 3;

/**
 * 대사 풀에서 한 개 선택. 최근 RECENT_LIMIT개 사용한 대사를 회피.
 * @param random 0..1 사이 값을 반환하는 함수 (테스트 시 deterministic하게 주입)
 */
export function pickLine(
  pool: DialoguePool,
  agent: AgentId,
  contextKey: string,
  lastUsed: Map<string, string[]>,
  random: () => number = Math.random,
): string | null {
  const lines = pool[agent]?.[contextKey];
  if (!lines || lines.length === 0) return null;

  const usedKey = `${agent}:${contextKey}`;
  const recent = lastUsed.get(usedKey) ?? [];

  let candidates = lines.filter((l) => !recent.includes(l));
  if (candidates.length === 0) candidates = lines;

  const picked = candidates[Math.floor(random() * candidates.length)];
  if (!picked) return null;

  // last-used 갱신 (mutate map ok — 호출 측이 단일 instance 기대)
  const next = [...recent, picked].slice(-RECENT_LIMIT);
  lastUsed.set(usedKey, next);
  return picked;
}

export function shouldShowWanderBubble(random: () => number = Math.random): boolean {
  return random() < 0.3;
}
```

- [ ] **Step 5: 통과 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- dialogue
```

Expected: 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/data/dialogue-pool.json src/app/characters/lib/dialogue.ts src/app/characters/lib/__tests__/dialogue.test.ts && git commit -m "feat(characters): add dialogue pool + pickLine"
```

---

## Task 6: Wander 좌표 산출 (순수)

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/lib/wander.ts`
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/lib/__tests__/wander.test.ts`

- [ ] **Step 1: 실패 테스트 작성**

```ts
// src/app/characters/lib/__tests__/wander.test.ts
import { describe, it, expect } from "vitest";
import { nextWanderPosition, ROOM, characterHome } from "@/app/characters/lib/wander";

describe("wander", () => {
  it("home 좌표 ± wander_radius 안으로 산출", () => {
    const home = { x: 200, y: 300 };
    const next = nextWanderPosition(home, () => 0.5);
    expect(next.x).toBeGreaterThanOrEqual(home.x - 60);
    expect(next.x).toBeLessThanOrEqual(home.x + 60);
    expect(next.y).toBeGreaterThanOrEqual(home.y - 60);
    expect(next.y).toBeLessThanOrEqual(home.y + 60);
  });

  it("random 0 → home - radius", () => {
    const home = { x: 200, y: 300 };
    const next = nextWanderPosition(home, () => 0);
    expect(next.x).toBe(140);
    expect(next.y).toBe(240);
  });

  it("room 경계 clamp", () => {
    const home = { x: 30, y: 30 };
    const next = nextWanderPosition(home, () => 0); // home - 60 → -30, clamp to padding
    expect(next.x).toBeGreaterThanOrEqual(ROOM.padding);
    expect(next.y).toBeGreaterThanOrEqual(ROOM.padding);
  });

  it("characterHome — 6×2 격자, index 0~11", () => {
    const h0 = characterHome(0);
    const h11 = characterHome(11);
    expect(h0.x).toBeGreaterThan(0);
    expect(h0.x).toBeLessThan(ROOM.width / 2);
    expect(h11.x).toBeGreaterThan(ROOM.width / 2);
    expect(h0.y).not.toBe(h11.y); // 다른 row
  });
});
```

- [ ] **Step 2: 실패 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- wander
```

Expected: FAIL — module not found.

- [ ] **Step 3: 구현**

```ts
// src/app/characters/lib/wander.ts
export const ROOM = {
  width: 1024,
  height: 576,
  padding: 50,
  wanderRadius: 60,
};

const COLS = 6;
const ROWS = 2;

export function characterHome(index: number): { x: number; y: number } {
  const col = index % COLS;
  const row = Math.floor(index / COLS);
  const cellW = ROOM.width / COLS;
  const cellH = ROOM.height / ROWS;
  return {
    x: cellW * col + cellW / 2,
    y: cellH * row + cellH / 2 + 30, // 약간 아래쪽 (위쪽은 룸 천장 여유)
  };
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

export function nextWanderPosition(
  home: { x: number; y: number },
  random: () => number = Math.random,
): { x: number; y: number } {
  const r = ROOM.wanderRadius;
  const dx = (random() - 0.5) * 2 * r;
  const dy = (random() - 0.5) * 2 * r;
  return {
    x: clamp(home.x + dx, ROOM.padding, ROOM.width - ROOM.padding),
    y: clamp(home.y + dy, ROOM.padding, ROOM.height - ROOM.padding),
  };
}

export function meetingPosition(
  source: { x: number; y: number },
  target: { x: number; y: number },
): { x: number; y: number } {
  // target home 기준 옆 +40px (source가 target과 겹치지 않게)
  const dx = source.x < target.x ? -40 : 40;
  return {
    x: clamp(target.x + dx, ROOM.padding, ROOM.width - ROOM.padding),
    y: target.y,
  };
}

export function distance(a: { x: number; y: number }, b: { x: number; y: number }): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- wander
```

Expected: 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/lib/wander.ts src/app/characters/lib/__tests__/wander.test.ts && git commit -m "feat(characters): add wander coordinate computation"
```

---

## Task 7: Character State Reducer

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/lib/reducer.ts`
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/lib/__tests__/reducer.test.ts`

- [ ] **Step 1: 실패 테스트 작성**

```ts
// src/app/characters/lib/__tests__/reducer.test.ts
import { describe, it, expect } from "vitest";
import { initialStates, characterReducer, type CharacterState } from "@/app/characters/lib/reducer";

describe("characterReducer", () => {
  it("initialStates — 12 캐릭터, home에서 idle", () => {
    const s = initialStates(2); // stage 2
    expect(s).toHaveLength(12);
    const planner = s.find((c) => c.id === "planner")!;
    expect(planner.action).toBe("idle");
    expect(planner.position).toEqual(planner.home);
    expect(planner.unlocked).toBe(true);
    const grader = s.find((c) => c.id === "grader")!;
    expect(grader.unlocked).toBe(false);
  });

  it("ACTION_INSTRUCTION — jump 적용", () => {
    const s = initialStates(2);
    const next = characterReducer(s, {
      type: "INSTRUCTION",
      instruction: { agent: "designer", action: "jump", dialogueKey: "tool_pass" },
      bubbleText: "디자인 살아남!",
      now: 1000,
    });
    const designer = next.find((c) => c.id === "designer")!;
    expect(designer.action).toBe("jump");
    expect(designer.bubble).toEqual({ text: "디자인 살아남!", expiresAt: 1000 + 4000 });
    expect(designer.usageCount).toBe(1);
  });

  it("ACTION_INSTRUCTION — walk-to (target 옆으로 이동)", () => {
    const s = initialStates(2);
    const next = characterReducer(s, {
      type: "INSTRUCTION",
      instruction: { agent: "qa", action: "walk-to", target: "developer", dialogueKey: "investigation" },
      bubbleText: "🔍",
      now: 2000,
    });
    const qa = next.find((c) => c.id === "qa")!;
    const developer = s.find((c) => c.id === "developer")!;
    expect(qa.action).toBe("walk");
    // qa는 developer home 옆에 있어야 함
    expect(Math.abs(qa.position.x - developer.home.x)).toBeLessThanOrEqual(60);
  });

  it("WANDER_TICK — 캐릭터를 wander 좌표로 이동", () => {
    const s = initialStates(2);
    const next = characterReducer(s, {
      type: "WANDER_TICK",
      agent: "planner",
      newPosition: { x: 100, y: 100 },
    });
    const planner = next.find((c) => c.id === "planner")!;
    expect(planner.action).toBe("walk");
    expect(planner.position).toEqual({ x: 100, y: 100 });
  });

  it("ARRIVE — walk → idle", () => {
    let s = initialStates(2);
    s = characterReducer(s, { type: "WANDER_TICK", agent: "planner", newPosition: { x: 100, y: 100 } });
    s = characterReducer(s, { type: "ARRIVE", agent: "planner" });
    const planner = s.find((c) => c.id === "planner")!;
    expect(planner.action).toBe("idle");
  });

  it("BUBBLE_EXPIRE — 만료된 bubble만 제거", () => {
    let s = initialStates(2);
    s = characterReducer(s, {
      type: "INSTRUCTION",
      instruction: { agent: "designer", action: "jump", dialogueKey: "tool_pass" },
      bubbleText: "hi",
      now: 1000,
    });
    s = characterReducer(s, { type: "BUBBLE_EXPIRE", now: 1000 + 5000 });
    const designer = s.find((c) => c.id === "designer")!;
    expect(designer.bubble).toBeNull();
  });

  it("locked 캐릭터는 이벤트 무시", () => {
    const s = initialStates(0); // grader/skill-reviewer 잠김 (& developer/qa도 0이면 잠김)
    const next = characterReducer(s, {
      type: "INSTRUCTION",
      instruction: { agent: "grader", action: "jump", dialogueKey: "tool_pass" },
      bubbleText: "hi",
      now: 1000,
    });
    const grader = next.find((c) => c.id === "grader")!;
    expect(grader.action).toBe("idle"); // 변화 없음
    expect(grader.bubble).toBeNull();
  });
});
```

- [ ] **Step 2: 실패 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- reducer
```

Expected: FAIL — module not found.

- [ ] **Step 3: 구현**

```ts
// src/app/characters/lib/reducer.ts
import { AGENTS, type AgentId } from "@/app/characters/data/agents";
import { isUnlocked } from "@/app/characters/data/stage-unlock";
import type { ActionInstruction, CharacterAction } from "@/app/characters/data/event-map";
import { characterHome, meetingPosition } from "./wander";

export type CharacterState = {
  id: AgentId;
  home: { x: number; y: number };
  position: { x: number; y: number };
  facing: "left" | "right";
  action: "idle" | "walk" | "jump" | "clap";
  bubble: { text: string; expiresAt: number } | null;
  usageCount: number;
  unlocked: boolean;
};

export const BUBBLE_TTL_MS = 4000;

export function initialStates(stage: number | null | undefined): CharacterState[] {
  return AGENTS.map((meta, idx) => {
    const home = characterHome(idx);
    return {
      id: meta.id,
      home,
      position: home,
      facing: "right",
      action: "idle",
      bubble: null,
      usageCount: 0,
      unlocked: isUnlocked(meta.id, stage),
    };
  });
}

export type ReducerAction =
  | { type: "INSTRUCTION"; instruction: ActionInstruction; bubbleText: string | null; now: number }
  | { type: "WANDER_TICK"; agent: AgentId; newPosition: { x: number; y: number } }
  | { type: "ARRIVE"; agent: AgentId }
  | { type: "JUMP_END"; agent: AgentId }
  | { type: "RETURN_HOME"; agent: AgentId }
  | { type: "BUBBLE_EXPIRE"; now: number };

function update(states: CharacterState[], id: AgentId, patch: Partial<CharacterState>): CharacterState[] {
  return states.map((s) => (s.id === id ? { ...s, ...patch } : s));
}

function findState(states: CharacterState[], id: AgentId): CharacterState | undefined {
  return states.find((s) => s.id === id);
}

export function characterReducer(states: CharacterState[], action: ReducerAction): CharacterState[] {
  switch (action.type) {
    case "INSTRUCTION": {
      const inst = action.instruction;
      const me = findState(states, inst.agent);
      if (!me || !me.unlocked) return states;

      const bubble = action.bubbleText
        ? { text: action.bubbleText, expiresAt: action.now + BUBBLE_TTL_MS }
        : me.bubble;
      const usage = me.usageCount + 1;

      if (inst.action === "jump") {
        return update(states, inst.agent, { action: "jump", bubble, usageCount: usage });
      }
      if (inst.action === "clap") {
        return update(states, inst.agent, { action: "clap", bubble, usageCount: usage });
      }
      if (inst.action === "idle") {
        return update(states, inst.agent, { action: "idle", bubble, usageCount: usage });
      }
      if (inst.action === "walk-to" && inst.target) {
        const target = findState(states, inst.target);
        if (!target) return states;
        const dest = meetingPosition(me.position, target.home);
        const facing: "left" | "right" = dest.x >= me.position.x ? "right" : "left";
        return update(states, inst.agent, {
          action: "walk",
          position: dest,
          facing,
          bubble,
          usageCount: usage,
        });
      }
      return states;
    }

    case "WANDER_TICK": {
      const me = findState(states, action.agent);
      if (!me || !me.unlocked || me.action === "walk") return states;
      const facing: "left" | "right" = action.newPosition.x >= me.position.x ? "right" : "left";
      return update(states, action.agent, { action: "walk", position: action.newPosition, facing });
    }

    case "ARRIVE": {
      const me = findState(states, action.agent);
      if (!me) return states;
      return update(states, action.agent, { action: "idle" });
    }

    case "JUMP_END": {
      return update(states, action.agent, { action: "idle" });
    }

    case "RETURN_HOME": {
      const me = findState(states, action.agent);
      if (!me) return states;
      const facing: "left" | "right" = me.home.x >= me.position.x ? "right" : "left";
      return update(states, action.agent, { action: "walk", position: me.home, facing });
    }

    case "BUBBLE_EXPIRE": {
      return states.map((s) => {
        if (!s.bubble) return s;
        if (s.bubble.expiresAt <= action.now) return { ...s, bubble: null };
        return s;
      });
    }
  }
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- reducer
```

Expected: 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/lib/reducer.ts src/app/characters/lib/__tests__/reducer.test.ts && git commit -m "feat(characters): add character state reducer"
```

---

## Task 8: useEventsStream hook

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/useEventsStream.ts`

- [ ] **Step 1: 구현**

이미 `/api/events`가 SSE로 제공된다 (기존 `src/app/api/events/route.ts` 사용 중). 이 hook은 EventSource로 그 endpoint 구독.

```ts
// src/app/characters/useEventsStream.ts
"use client";

import { useEffect, useRef } from "react";

export type RawEvent = Record<string, unknown>;

type Options = {
  onEvent: (event: RawEvent) => void;
  onConnectionChange?: (connected: boolean) => void;
};

export function useEventsStream({ onEvent, onConnectionChange }: Options) {
  const onEventRef = useRef(onEvent);
  const onConnRef = useRef(onConnectionChange);
  onEventRef.current = onEvent;
  onConnRef.current = onConnectionChange;

  useEffect(() => {
    let es: EventSource | null = null;
    let retryDelay = 3_000;
    let timer: ReturnType<typeof setTimeout> | null = null;
    let cancelled = false;

    const connect = () => {
      if (cancelled) return;
      es = new EventSource("/api/events");

      es.onopen = () => {
        retryDelay = 3_000;
        onConnRef.current?.(true);
      };

      es.onmessage = (msg) => {
        try {
          const data = JSON.parse(msg.data) as { raw: string; parsed?: RawEvent };
          if (data.parsed) {
            onEventRef.current(data.parsed);
          }
        } catch {
          // skip malformed
        }
      };

      es.onerror = () => {
        onConnRef.current?.(false);
        es?.close();
        es = null;
        timer = setTimeout(connect, retryDelay);
        retryDelay = Math.min(30_000, retryDelay * 3); // 3 → 9 → 27 → 30 cap
      };
    };

    connect();

    return () => {
      cancelled = true;
      if (timer) clearTimeout(timer);
      es?.close();
    };
  }, []);
}
```

- [ ] **Step 2: 타입 체크**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npx tsc --noEmit
```

Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/useEventsStream.ts && git commit -m "feat(characters): add useEventsStream SSE hook"
```

---

## Task 9: useCharacterEngine hook

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/useCharacterEngine.ts`
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/__tests__/useCharacterEngine.test.tsx`

- [ ] **Step 1: 실패 테스트 작성**

```tsx
// src/app/characters/__tests__/useCharacterEngine.test.tsx
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { useCharacterEngine } from "@/app/characters/useCharacterEngine";
import dialoguePool from "@/app/characters/data/dialogue-pool.json";

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

describe("useCharacterEngine", () => {
  it("initial states 12명", () => {
    const { result } = renderHook(() => useCharacterEngine({ stage: 2, dialoguePool }));
    expect(result.current.states).toHaveLength(12);
  });

  it("handleEvent — tool_result pass → designer jump + bubble", () => {
    const { result } = renderHook(() => useCharacterEngine({ stage: 2, dialoguePool }));
    act(() => {
      result.current.handleEvent({
        type: "tool_result",
        tool: "prettier",
        status: "pass",
      });
    });
    const designer = result.current.states.find((c) => c.id === "designer")!;
    expect(designer.action).toBe("jump");
    expect(designer.bubble).not.toBeNull();
    expect(dialoguePool.designer.tool_pass).toContain(designer.bubble!.text);
  });

  it("4초 후 bubble 만료", () => {
    const { result } = renderHook(() => useCharacterEngine({ stage: 2, dialoguePool }));
    act(() => {
      result.current.handleEvent({ type: "tool_result", tool: "prettier", status: "pass" });
    });
    expect(result.current.states.find((c) => c.id === "designer")!.bubble).not.toBeNull();
    act(() => {
      vi.advanceTimersByTime(5000);
    });
    expect(result.current.states.find((c) => c.id === "designer")!.bubble).toBeNull();
  });
});
```

- [ ] **Step 2: 실패 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- useCharacterEngine
```

Expected: FAIL — module not found.

- [ ] **Step 3: useCharacterEngine 구현**

```ts
// src/app/characters/useCharacterEngine.ts
"use client";

import { useCallback, useEffect, useReducer, useRef } from "react";
import { mapEvent } from "./data/event-map";
import { pickLine, shouldShowWanderBubble, type DialoguePool } from "./lib/dialogue";
import { nextWanderPosition } from "./lib/wander";
import { characterReducer, initialStates, type CharacterState, BUBBLE_TTL_MS } from "./lib/reducer";
import type { RawEvent } from "./useEventsStream";

type Options = {
  stage: number | null | undefined;
  dialoguePool: DialoguePool;
};

const WANDER_MIN_MS = 5_000;
const WANDER_MAX_MS = 15_000;
const ARRIVE_MS = 600; // walk transition 시간 + 약간 여유
const JUMP_MS = 500;
const BUBBLE_SWEEP_MS = 1_000;

export function useCharacterEngine({ stage, dialoguePool }: Options) {
  const [states, dispatch] = useReducer(characterReducer, stage, initialStates);
  const lastUsedRef = useRef<Map<string, string[]>>(new Map());

  const handleEvent = useCallback((event: RawEvent) => {
    const instructions = mapEvent(event);
    const now = Date.now();
    for (const inst of instructions) {
      const text = pickLine(dialoguePool, inst.agent, inst.dialogueKey, lastUsedRef.current);
      dispatch({ type: "INSTRUCTION", instruction: inst, bubbleText: text, now });

      if (inst.action === "jump" || inst.action === "clap") {
        setTimeout(() => dispatch({ type: "JUMP_END", agent: inst.agent }), JUMP_MS);
      }
      if (inst.action === "walk-to") {
        setTimeout(() => dispatch({ type: "ARRIVE", agent: inst.agent }), ARRIVE_MS);
      }
    }
  }, [dialoguePool]);

  // bubble sweep
  useEffect(() => {
    const id = setInterval(() => {
      dispatch({ type: "BUBBLE_EXPIRE", now: Date.now() });
    }, BUBBLE_SWEEP_MS);
    return () => clearInterval(id);
  }, []);

  // wander schedule per agent
  useEffect(() => {
    const timers: ReturnType<typeof setTimeout>[] = [];

    function scheduleWander(agent: CharacterState) {
      if (!agent.unlocked) return;
      const delay = WANDER_MIN_MS + Math.random() * (WANDER_MAX_MS - WANDER_MIN_MS);
      const t = setTimeout(() => {
        const pos = nextWanderPosition(agent.home);
        dispatch({ type: "WANDER_TICK", agent: agent.id, newPosition: pos });

        if (shouldShowWanderBubble()) {
          const text = pickLine(dialoguePool, agent.id, "wander", lastUsedRef.current);
          if (text) {
            dispatch({
              type: "INSTRUCTION",
              instruction: { agent: agent.id, action: "idle", dialogueKey: "wander" },
              bubbleText: text,
              now: Date.now(),
            });
          }
        }

        // arrive 후 다시 스케줄
        const arriveTimer = setTimeout(() => {
          dispatch({ type: "ARRIVE", agent: agent.id });
          scheduleWander(agent);
        }, ARRIVE_MS);
        timers.push(arriveTimer);
      }, delay);
      timers.push(t);
    }

    states.forEach((s) => {
      if (s.unlocked) scheduleWander(s);
    });

    return () => {
      timers.forEach(clearTimeout);
    };
    // 첫 마운트 시 1회만 시작 (이후 self-perpetuating)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // visibility 일시정지 (간단: 페이지 hidden 시 wander 멈춤은 self-perpetuating에서 자연스럽게 처리되지 않음)
  // — 후속에서 개선. 현재는 수용.

  return { states, handleEvent };
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test -- useCharacterEngine
```

Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/useCharacterEngine.ts src/app/characters/__tests__/useCharacterEngine.test.tsx && git commit -m "feat(characters): add useCharacterEngine hook"
```

---

## Task 10: SpeechBubble 컴포넌트

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/SpeechBubble.tsx`

- [ ] **Step 1: 구현**

```tsx
// src/app/characters/SpeechBubble.tsx
"use client";

import { useEffect, useState } from "react";

type Props = {
  text: string;
  expiresAt: number;
};

export function SpeechBubble({ text, expiresAt }: Props) {
  const [visible, setVisible] = useState(false);
  const [fading, setFading] = useState(false);

  useEffect(() => {
    setVisible(true);
    setFading(false);
    const remain = expiresAt - Date.now();
    const fadeStart = Math.max(0, remain - 400);
    const t1 = setTimeout(() => setFading(true), fadeStart);
    return () => clearTimeout(t1);
  }, [text, expiresAt]);

  return (
    <div
      className="absolute bottom-full left-1/2 -translate-x-1/2 -translate-y-1.5 whitespace-nowrap rounded-md bg-white px-2 py-1 text-[11px] font-semibold text-zinc-900 shadow-md transition-opacity duration-200"
      style={{ opacity: visible && !fading ? 1 : 0 }}
    >
      {text}
      <span
        aria-hidden
        className="absolute left-1/2 top-full -translate-x-1/2 border-[5px] border-transparent border-t-white"
      />
    </div>
  );
}
```

- [ ] **Step 2: 타입 체크**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npx tsc --noEmit
```

Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/SpeechBubble.tsx && git commit -m "feat(characters): add SpeechBubble component"
```

---

## Task 11: Character 컴포넌트 (anchor-relative)

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/Character.tsx`

이 컴포넌트는 부모(Stage)가 좌표 anchor를 잡아주는 안에서 sprite + bubble만 렌더한다. 자체 절대 좌표 X — Stage가 percentage로 위치 잡음.

- [ ] **Step 1: 구현**

```tsx
// src/app/characters/Character.tsx
"use client";

import { AGENT_MAP } from "./data/agents";
import { SpeechBubble } from "./SpeechBubble";
import type { CharacterState } from "./lib/reducer";

const SPRITE_SIZE = 48;

type Props = {
  state: CharacterState;
};

export function Character({ state }: Props) {
  const meta = AGENT_MAP[state.id];
  const spriteSuffix =
    state.action === "walk" ? `walk-${state.facing}` : `idle-${state.facing}`;
  const spriteUrl = `${meta.spritePath}-${spriteSuffix}.png`;

  const jumpY = state.action === "jump" ? -12 : 0;

  return (
    <div
      className="absolute"
      style={{
        width: SPRITE_SIZE,
        height: SPRITE_SIZE,
        left: -SPRITE_SIZE / 2,
        top: -SPRITE_SIZE,
        transform: `translateY(${jumpY}px)`,
        transition:
          state.action === "jump"
            ? "transform 250ms cubic-bezier(.5,1.5,.5,1)"
            : "none",
        opacity: state.unlocked ? 1 : 0.35,
        filter: state.unlocked ? "none" : "grayscale(0.6)",
      }}
      aria-label={`${meta.name} (${state.action})`}
    >
      <div
        className="h-full w-full"
        style={{
          backgroundImage: `url(${spriteUrl})`,
          backgroundSize: "contain",
          backgroundRepeat: "no-repeat",
          backgroundPosition: "center",
          backgroundColor: meta.mainColor,
          imageRendering: "pixelated",
          borderRadius: 4,
        }}
      />
      {state.bubble && (
        <SpeechBubble text={state.bubble.text} expiresAt={state.bubble.expiresAt} />
      )}
      {!state.unlocked && (
        <span className="absolute -bottom-4 left-1/2 -translate-x-1/2 whitespace-nowrap text-[8px] text-zinc-300">
          Stage {meta.unlockStage}
        </span>
      )}
    </div>
  );
}
```

- [ ] **Step 2: 타입 체크**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npx tsc --noEmit
```

Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/Character.tsx && git commit -m "feat(characters): add Character component"
```

---

## Task 12: Stage 컴포넌트

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/Stage.tsx`

- [ ] **Step 1: 구현**

```tsx
// src/app/characters/Stage.tsx
"use client";

import { Character } from "./Character";
import { ROOM } from "./lib/wander";
import type { CharacterState } from "./lib/reducer";

const WALK_TRANSITION_MS = 600;

type Props = {
  states: CharacterState[];
};

export function Stage({ states }: Props) {
  return (
    <div className="mx-auto w-full max-w-5xl rounded-lg border-2 border-zinc-800 bg-zinc-900 p-2">
      <div
        className="relative w-full overflow-hidden rounded-md"
        style={{
          aspectRatio: `${ROOM.width} / ${ROOM.height}`,
          background: "linear-gradient(#1a2238 0 60%, #4a3520 60% 100%)",
        }}
      >
        {/* 픽셀 디테일 (창문/그림) — 후속에 픽셀 배경 PNG로 교체 예정 */}
        <div
          aria-hidden
          className="absolute"
          style={{
            left: "5%", top: "8%", width: "12%", height: "20%",
            background: "linear-gradient(#5a8fd8,#2a5db0)",
            border: "2px solid #14161f",
          }}
        />
        <div
          aria-hidden
          className="absolute"
          style={{
            left: "20%", top: "8%", width: "12%", height: "20%",
            background: "linear-gradient(#5a8fd8,#2a5db0)",
            border: "2px solid #14161f",
          }}
        />
        <div
          aria-hidden
          className="absolute"
          style={{
            left: "70%", top: "10%", width: "10%", height: "16%",
            background: "#d97757",
            border: "2px solid #14161f",
          }}
        />

        {/* 캐릭터 anchor — 좌표는 ROOM 기준 percentage */}
        {states.map((s) => (
          <div
            key={s.id}
            className="absolute"
            style={{
              left: `${(s.position.x / ROOM.width) * 100}%`,
              top: `${(s.position.y / ROOM.height) * 100}%`,
              transition:
                s.action === "walk"
                  ? `left ${WALK_TRANSITION_MS}ms linear, top ${WALK_TRANSITION_MS}ms linear`
                  : "none",
            }}
          >
            <Character state={s} />
          </div>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: 타입 체크**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npx tsc --noEmit
```

Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/Stage.tsx && git commit -m "feat(characters): add Stage component"
```

---

## Task 13: Stage API endpoint (.vibe-flow.json 읽기)

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/api/vibe-flow/stage/route.ts`

- [ ] **Step 1: 구현**

```ts
// src/app/api/vibe-flow/stage/route.ts
import { existsSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { NextResponse } from "next/server";
import { getVibeFlowProject } from "@/lib/vibe-flow-config";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const root = getVibeFlowProject();
  const cfgPath = path.join(root, ".vibe-flow.json");
  if (!existsSync(cfgPath)) {
    return NextResponse.json({ stage: 1, source: "default" });
  }
  try {
    const text = await fs.readFile(cfgPath, "utf-8");
    const data = JSON.parse(text) as { stage?: unknown };
    const stage = typeof data.stage === "number" ? data.stage : 1;
    return NextResponse.json({ stage, source: "file" });
  } catch {
    return NextResponse.json({ stage: 1, source: "fallback" });
  }
}
```

- [ ] **Step 2: 타입 체크 + 빌드 가능성 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npx tsc --noEmit
```

Expected: 에러 없음.

- [ ] **Step 3: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/api/vibe-flow/stage/route.ts && git commit -m "feat(api): add /api/vibe-flow/stage endpoint"
```

---

## Task 14: /characters page

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/page.tsx`
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/characters/CharacterPage.client.tsx`

- [ ] **Step 1: 서버 컴포넌트 page.tsx**

```tsx
// src/app/characters/page.tsx
import { existsSync } from "node:fs";
import fs from "node:fs/promises";
import path from "node:path";
import { getVibeFlowProject } from "@/lib/vibe-flow-config";
import { CharacterPage } from "./CharacterPage.client";

export const dynamic = "force-dynamic";

async function loadStage(): Promise<number> {
  const cfg = path.join(getVibeFlowProject(), ".vibe-flow.json");
  if (!existsSync(cfg)) return 1;
  try {
    const text = await fs.readFile(cfg, "utf-8");
    const data = JSON.parse(text) as { stage?: unknown };
    return typeof data.stage === "number" ? data.stage : 1;
  } catch {
    return 1;
  }
}

export default async function Page() {
  const stage = await loadStage();
  return <CharacterPage initialStage={stage} />;
}
```

- [ ] **Step 2: 클라이언트 컴포넌트 CharacterPage.client.tsx**

```tsx
// src/app/characters/CharacterPage.client.tsx
"use client";

import { useState } from "react";
import Link from "next/link";
import { Stage } from "./Stage";
import { useCharacterEngine } from "./useCharacterEngine";
import { useEventsStream } from "./useEventsStream";
import dialoguePool from "./data/dialogue-pool.json";

type Props = {
  initialStage: number;
};

export function CharacterPage({ initialStage }: Props) {
  const [connected, setConnected] = useState(false);
  const { states, handleEvent } = useCharacterEngine({
    stage: initialStage,
    dialoguePool,
  });

  useEventsStream({
    onEvent: handleEvent,
    onConnectionChange: setConnected,
  });

  return (
    <div className="flex min-h-screen flex-col bg-zinc-50 font-sans dark:bg-black">
      <header className="border-b border-zinc-200 bg-white px-8 py-4 dark:border-zinc-800 dark:bg-zinc-950">
        <div className="mx-auto flex max-w-5xl items-center justify-between">
          <div>
            <Link href="/" className="text-sm text-zinc-500 hover:text-zinc-900 dark:hover:text-zinc-200">
              ← Dashboard
            </Link>
            <h1 className="mt-1 text-xl font-bold text-zinc-900 dark:text-zinc-50">
              🎮 Characters
            </h1>
            <p className="text-sm text-zinc-600 dark:text-zinc-400">
              12 에이전트가 events.jsonl에 반응합니다 · Stage {initialStage}
            </p>
          </div>
          <div className="flex items-center gap-2">
            <span
              className={`inline-block h-2 w-2 rounded-full ${
                connected ? "bg-green-500" : "bg-red-500"
              }`}
            />
            <span className="text-sm text-zinc-700 dark:text-zinc-300">
              {connected ? "live" : "연결 시도 중"}
            </span>
          </div>
        </div>
      </header>

      <main className="mx-auto w-full max-w-5xl flex-1 space-y-6 px-8 py-6">
        <Stage states={states} />
        <div className="text-xs text-zinc-500">
          캐릭터를 보고 싶은데 비어있다면: 사용자 프로젝트에서 코드 변경/테스트 실행 시 events.jsonl이 생성되며 캐릭터들이 반응합니다.
        </div>
      </main>
    </div>
  );
}
```

- [ ] **Step 3: 타입 체크**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npx tsc --noEmit
```

Expected: 에러 없음.

- [ ] **Step 4: dev server 동작 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && timeout 30 npm run dev &
sleep 8
curl -sf http://localhost:9999/characters > /dev/null && echo "OK" || echo "FAIL"
```

Expected: `OK` (HTTP 200). 그 후 dev server는 background에서 계속 — 다음 task에서 종료.

- [ ] **Step 5: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/characters/page.tsx src/app/characters/CharacterPage.client.tsx && git commit -m "feat(characters): add /characters page"
```

---

## Task 15: 메인 dashboard에 navigation link 추가

**Files:**
- Modify: `/Users/yss/개발/build/vibe-flow-dashboard/src/app/page.tsx` (헤더 부근)

- [ ] **Step 1: 현재 헤더 확인**

```bash
sed -n '215,240p' /Users/yss/개발/build/vibe-flow-dashboard/src/app/page.tsx
```

(헤더 구조를 보고 다음 step에서 정확한 위치 식별)

- [ ] **Step 2: Link import + nav 추가**

`src/app/page.tsx` 상단 import 영역에 `import Link from "next/link";` 가 없으면 추가. 그 후 헤더의 `<div className="flex items-center gap-2">` (connected indicator 부분) 바로 앞에 다음 추가:

```tsx
<Link
  href="/characters"
  className="mr-3 text-sm text-zinc-600 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
>
  🎮 Characters
</Link>
```

정확한 위치 (page.tsx 224번째 줄 부근, `<div className="flex items-center gap-2">` 바로 안 첫 자식으로):

기존:
```tsx
<div className="flex items-center gap-2">
  <span
    className={`inline-block h-2 w-2 rounded-full ${
```

변경 후:
```tsx
<div className="flex items-center gap-2">
  <Link
    href="/characters"
    className="mr-3 text-sm text-zinc-600 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
  >
    🎮 Characters
  </Link>
  <span
    className={`inline-block h-2 w-2 rounded-full ${
```

- [ ] **Step 3: 타입 체크 + 동작 확인**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npx tsc --noEmit
```

Expected: 에러 없음.

- [ ] **Step 4: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add src/app/page.tsx && git commit -m "feat(dashboard): add /characters nav link"
```

---

## Task 16: Placeholder sprite PNG 12종 생성

**Files:**
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/public/sprites/<agent>-{idle,walk}-{l,r}.png` (12 캐릭터 × 4 = 48 파일)
- Create: `/Users/yss/개발/build/vibe-flow-dashboard/scripts/generate-placeholder-sprites.mjs`

실제 픽셀 에셋은 별도 작업(AI 생성 + Aseprite 후처리). 이 task는 dev에서 동작 확인용 placeholder PNG.

- [ ] **Step 1: placeholder 생성 스크립트**

```js
// vibe-flow-dashboard/scripts/generate-placeholder-sprites.mjs
// 48×48 단색 PNG를 캐릭터 메인 컬러로 12종 × 4 프레임 생성.
// PNG 만들 외부 라이브러리 없이, sharp/jimp 대신 base64 1×1 PNG에 의존.
// 실패하면 색만 채운 SVG 대체.

import { writeFileSync, mkdirSync, existsSync } from "node:fs";
import path from "node:path";

const AGENTS = [
  ["planner", "#5e9bd6"],
  ["designer", "#e36ba7"],
  ["developer", "#5fb380"],
  ["qa", "#7dd6c2"],
  ["security", "#3a3a4a"],
  ["validator", "#3da068"],
  ["feedback", "#f5b8d2"],
  ["moderator", "#a89366"],
  ["comparator", "#5e9bd6"],
  ["retrospective", "#8b6cb0"],
  ["grader", "#6c8db5"],
  ["skill-reviewer", "#7a8290"],
];

const FRAMES = ["idle-l", "idle-r", "walk-l", "walk-r"];
const outDir = path.join(process.cwd(), "public", "sprites");
mkdirSync(outDir, { recursive: true });

// SVG로 폴백 — 진짜 PNG 대신 SVG를 .png 확장자로 못 쓰니까 .svg 또는 단순 비워두기
// 깔끔하게: SVG 파일을 만들고, Character 컴포넌트가 png 못 찾으면 background-color fallback
// → 그래서 여기서는 빈 1×1 PNG (투명) 만들어 두는 것으로 충분.

// 1×1 transparent PNG (base64)
const TRANSPARENT_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
  "base64"
);

let n = 0;
for (const [agent] of AGENTS) {
  for (const frame of FRAMES) {
    const f = path.join(outDir, `${agent}-${frame}.png`);
    if (!existsSync(f)) {
      writeFileSync(f, TRANSPARENT_PNG);
      n += 1;
    }
  }
}
console.log(`Created ${n} placeholder PNG sprites in ${outDir}`);
```

- [ ] **Step 2: 스크립트 실행**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && node scripts/generate-placeholder-sprites.mjs
```

Expected: `Created 48 placeholder PNG sprites in .../public/sprites`.

- [ ] **Step 3: 확인**

```bash
ls /Users/yss/개발/build/vibe-flow-dashboard/public/sprites | wc -l
```

Expected: 48.

- [ ] **Step 4: Commit**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add scripts/generate-placeholder-sprites.mjs public/sprites && git commit -m "chore(characters): add placeholder sprites (48 transparent PNG)"
```

---

## Task 17: 시각 smoke test (dev server + 수동 검증)

**Files:** 없음 (검증 step만)

- [ ] **Step 1: dev server 실행 (이미 떠있으면 skip)**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm run dev
```

(다른 터미널 / 백그라운드)

- [ ] **Step 2: 브라우저 접속**

브라우저 → `http://localhost:9999/characters`

확인 항목:
- [ ] 12 캐릭터가 6×2 격자로 룸 안에 보임 (PNG가 transparent라 사각형 mainColor만 보임)
- [ ] 메인 dashboard `http://localhost:9999/` 헤더에 "🎮 Characters" 링크 보임
- [ ] Stage 1 default일 때 grader/skill-reviewer 흐릿 (opacity 0.35)
- [ ] connected 상태 indicator (live or 연결 시도 중)
- [ ] 5~15초 간격으로 캐릭터들이 home 주변으로 wander (살짝 위치 변경)
- [ ] 30% 확률로 wander 시 말풍선 (예: 디자이너의 "🎨")

- [ ] **Step 3: events 트리거 (옵션 — 사용자 프로젝트에서 수동)**

vibe-flow 본체가 활성인 사용자 프로젝트에서 실제 코드 변경 → hook이 events.jsonl에 push → dashboard에서 캐릭터 반응 보임.

빠른 테스트는 events.jsonl에 직접 한 줄 append:

```bash
PROJECT_DIR="${VIBE_FLOW_PROJECT:-$(pwd)}"
echo '{"type":"tool_result","tool":"prettier","status":"pass","ts":"2026-05-01T12:00:00Z"}' >> "$PROJECT_DIR/.claude/events.jsonl"
```

브라우저에서 designer 캐릭터가 점프하고 말풍선("디자인 살아남! 🎨" 등) 표시되어야 함.

- [ ] **Step 4: 검증 결과 메모**

위 항목 중 실패가 있으면 root cause 디버깅 (events.jsonl 경로, 환경변수 `VIBE_FLOW_PROJECT`, sprite path 등).

- [ ] **Step 5: dev server 종료 + 최종 모든 테스트**

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && npm test && npx tsc --noEmit
```

Expected: 모든 테스트 PASS, tsc 에러 없음.

---

## Task 18: ROADMAP + README 갱신

**Files:**
- Modify: `/Users/yss/개발/build/vibe-flow/ROADMAP.md`
- Modify: `/Users/yss/개발/build/vibe-flow-dashboard/README.md`

- [ ] **Step 1: ROADMAP.md 업데이트**

`vibe-flow/ROADMAP.md`의 동적 캐릭터 시스템 항목 (현재 `[ ]`):

기존:
```markdown
- [ ] **🎮 동적 캐릭터 시스템 (게임화)** — vibe-coding에 재미 요소
```

변경 후:
```markdown
- [x] **🎮 동적 캐릭터 시스템 (게임화)** — vibe-coding에 재미 요소
  - **spec**: `docs/superpowers/specs/2026-04-30-dynamic-character-system-design.md`
  - **plan**: `docs/superpowers/plans/2026-05-01-dynamic-character-system.md`
  - **구현**: vibe-flow-dashboard repo `/characters` 페이지 (12 chibi 캐릭터, events.jsonl 반응)
  - **MVP 후속 후보**: dynamic-dialogue-llm, character-customization, character-roaming-phaser, character-leveling, pixel-artist-handover, vibe-flow-events-v2 (spec 13절 참고)
```

- [ ] **Step 2: vibe-flow-dashboard/README.md 업데이트**

`vibe-flow-dashboard/README.md` 끝에 다음 섹션 추가 (없으면 새로 추가, 기존 페이지 목록 있으면 확장):

```markdown
## /characters

12 에이전트가 events.jsonl에 반응하는 캐릭터 무대.

- 단일 픽셀 룸 + 12 chibi 캐릭터 (48×48)
- L2 light wander (5~15s) + L3 event-driven 이동
- 정적 대사 풀 (`src/app/characters/data/dialogue-pool.json`)
- Stage unlock (`.vibe-flow.json`의 `stage` 필드 0~4)
- 에셋: `public/sprites/<agent>-{idle,walk}-{l,r}.png` (현재 placeholder transparent)

실제 픽셀 캐릭터 PNG를 같은 파일명으로 교체하면 코드 변경 없이 적용됩니다.
```

- [ ] **Step 3: 두 repo 각각 commit**

```bash
cd /Users/yss/개발/build/vibe-flow && git add ROADMAP.md && git commit -m "docs(roadmap): 🎮 동적 캐릭터 시스템 [x] + spec/plan 링크"
```

```bash
cd /Users/yss/개발/build/vibe-flow-dashboard && git add README.md && git commit -m "docs: add /characters page section"
```

---

## 완료 후 확인

- [ ] 모든 단위 테스트 pass: `cd vibe-flow-dashboard && npm test`
- [ ] 타입 체크 pass: `cd vibe-flow-dashboard && npx tsc --noEmit`
- [ ] dev server에서 `/characters` 진입 시 12 캐릭터 화면 + wander + 말풍선 동작
- [ ] events.jsonl에 한 줄 append 시 해당 캐릭터 반응
- [ ] ROADMAP.md 항목 [x]로 변경됨

## 후속 spec 후보 (이 plan 끝나면)

spec 13절 그대로:
- dynamic-dialogue-llm — LLM 동적 대사
- character-customization — 사용자 이름/대사 커스텀
- vibe-flow-events-v2 — 의미적 이벤트 emit 추가
- character-roaming-phaser — Phaser 자유 로밍
- character-leveling — 레벨/뱃지
- pixel-artist-handover — 정식 픽셀아티스트 의뢰
