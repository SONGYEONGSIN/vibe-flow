---
name: Layout debugging — Tailwind v4 mockup ↔ React port 격차 좁히기
description: Tailwind v4 + Next.js 환경에서 mockup HTML과 React 포팅 결과의 좌표 격차를 좁히는 진단 패턴 + 자주 만나는 root cause 3종 (CSS Cascade Layers, html font-size, line-height tokens, line-height inherit)
type: feedback
originSessionId: fa4d7468-5d81-4499-b474-305dc529d2ce
---
Folio /login refinement (2026-04-26 plan)에서 mockup vs React port 격차 진단·fix 과정에서 발견한 패턴. dashboard 등 차후 mockup-React 정합 작업에서 그대로 재현 가능.

## 진단 워크플로

`design-sync` sync%만으로는 **사람 눈에 들어오는 격차를 못 잡음** — login 94%였는데도 사용자가 "차이가 많다" 인지. **좌표 단위 진단이 결정적.**

1. **`scripts/diagnose-layout.mjs`로 baseline** — 14 element의 mockup vs ours boundingBox 비교 (Δx, Δy, size). 격차 inventory 자동 추출.
2. **`scripts/diagnose-computed.mjs`로 root cause 진단** — Playwright의 `getComputedStyle()`로 element-level CSS 비교. `padding-block`, `line-height`, `font-size`, `height`, `min-height` 등.
3. **카테고리별 incremental fix** — Cat A(크기), Cat B(vertical), Cat C(horizontal). 각 fix 후 baseline 재측정해 진전 확인.

## 자주 만나는 root cause 4종

### 1. Unlayered `*` 리셋이 Tailwind utilities를 silently override

```css
/* 잘못된 코드 — 모든 padding/margin utilities를 무력화 */
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}
```

증상: `py-3`, `lg:px-7`, `mb-5` 등이 0px 적용. 좌표 진단 시 panel padding이 panel 자식에 안 닿음 (Δx -40 같은 큰 horizontal 시프트).

원인: `@import "tailwindcss"`가 utilities를 `@layer utilities` 안에 배치. CSS Cascade Layers spec상 unlayered 선언 > 모든 layered 선언. 따라서 `@layer` 밖의 `*` 리셋이 specificity와 무관하게 utilities를 이김.

**Fix:**
```css
@layer base {
  * {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }
}
```

### 2. `html` font-size 13px → rem 기반 utility 19% 작아짐

```css
/* 잘못된 코드 — Tailwind v4의 rem-based spacing 영향 */
html, body {
  font-size: 13px;
  ...
}
```

증상: `min-h-12`(=3rem)이 `3 × 13 = 39px` (의도 48px). button height 48 expected가 39 (-9px) 출력.

원인: Tailwind v4 default `--spacing: 0.25rem`. `min-h-12 = calc(.25rem * 12) = 3rem`. html font-size가 16(브라우저 default) 아닌 13px이면 1rem=13px → 모든 rem-based utility가 19% 작아짐.

**Fix:**
```css
/* html 빼고 body만 */
body {
  font-size: var(--text-md);
  ...
}
```

mockup CSS는 `html, body { font-size: 13px }`이지만 mockup은 Tailwind 미사용이라 영향 없음. 우리만 Tailwind rem-based utility 쓰므로 html을 16px(default)에 두고 body만 13px.

### 3. Tailwind v4 default `--text-*--line-height`가 cascade 끊음

증상: 폼 element들의 누적 vertical 시프트 (Δy -4 ~ -6 누적).

원인: Tailwind v4 default theme는 `--text-xs--line-height: calc(1/0.75) = 1.333` 등 정의. `text-xs` utility 사용 시 font-size + line-height **둘 다** 출력 → body의 `line-height: 1.5` cascade 끊음. h2/divider/footer 등이 1.333 line-height로 계산돼 누적 시프트.

**Fix:** `globals.css`에 별도 `@theme` 블록 추가 (non-inline, 그래야 default 값 override):
```css
@theme {
  --text-3xs--line-height: 1.5;
  --text-2xs--line-height: 1.5;
  --text-xs--line-height: 1.5;
  --text-sm--line-height: 1.5;
  --text-md--line-height: 1.5;
  --text-lg--line-height: 1.5;
  --text-xl--line-height: 1.5;
  --text-2xl--line-height: 1.5;
  --text-3xl--line-height: 1.5;
}
```

`@theme inline` 블록은 변수 참조 인라인 용도이고 default theme의 `--text-*--line-height`는 그 안에 없어 override 안 됨. 별도 non-inline `@theme` 블록 필수.

### 4. `<input>` line-height inherit (Tailwind preflight `font: inherit`)

증상: input height가 mockup 39px 대비 44px (+5px overshoot). `padding 12+12 + line-height 13×1.5(=19.5) = 43.5 ≈ 44`.

원인: Tailwind v4 preflight `button, input, ... { font: inherit; }`로 body의 `line-height: 1.5` inherit. mockup `<input>`은 line-height 미명시 → browser default `normal` (≈1.15) → height = 13×1.15 + 24 = 39.

**Fix**: input className에 `[line-height:normal]` 추가. `leading-none`(1.0)은 mockup -2 underflow.

```tsx
<input
  ...
  className="... [line-height:normal]"
/>
```

## 다른 함정 (회귀 위험)

- **mockup과 우리 SSO 버튼 등의 inner content 길이 차이**: disabled UX 표시용으로 추가한 라벨(예: "· 준비 중")이 button 폭을 늘려 `justify-center` 중앙정렬 시 텍스트 위치가 mockup에서 시프트. **disabled + opacity + title 속성**으로 UX 보존하고 라벨 자체는 제거.
- **dev server 두 개 동시 띄우기**: `next dev -p 3001`과 e2e webServer `next dev -p 3010`이 같은 `.next/dev` 폴더 lock 충돌. 한쪽 잠시 kill → 다른 쪽 spawn → 종료 후 다시 띄움 패턴.

**Why:** 2026-04-26 Folio /login refinement plan 실행에서 위 4종 root cause로 누적 격차가 발생함을 발견. 각 cause는 독립적이지만 `globals.css` 한두 줄 fix로 한 번에 해결 가능 (Bug 1, Bug 2, Bug 3는 globals.css), Bug 4만 page.tsx의 input className 1단어 추가.

**How to apply (dashboard reconstruction에서 재사용):**
1. dashboard에서도 동일하게 `diagnose-layout.mjs` baseline + `diagnose-computed.mjs` deep-dive
2. 위 4 cause가 이미 Folio globals.css fix됨 → dashboard도 자동으로 영향 받음. dashboard plan은 추가 cause만 진단
3. dashboard 특유 inspector / sidebar / menubar 등의 mockup vs React 격차는 **컴포넌트 추출 + 구조 재구성** 단계에서 적용 (login plan은 inline 유지 결정)
