---
name: landing-ai-tell-audit
description: taste-skill "AI 티" audit of the landing (2026-10-08) — user fixed items 1·4·5 first; items 2 (real images) and 3 (section rhythm) are next; pre-launch gaps
metadata:
  type: project
---

On 2026-10-08 the user installed `Leonxlnx/taste-skill` (skills `design-taste-frontend`, `redesign-existing-projects`, global in ~/.claude/skills) and asked whether the landing looks AI-made. The audit proposed five fixes. The user said "1, 4, 5번 먼저 고치고 다음 수정하자", meaning fix those first and do the rest next.

- **Done (uncommitted at the time):**
  - **1. Colour.** Violet → cobalt `--brand`; brand gradients removed.
  - **4. Decoration.** The ✨ "출시 준비 중" badge is gone. Pill badges became square labels. Every CTA is now labelled "무료로 시작하기".
  - **5. Finishing.** Added an icon.tsx/apple-icon.tsx favicon, an opengraph-image.tsx share image, a 404 page and a skip link. Removed the em-dash from the title.
- **Next: 2. Real images.** Replace the div-drawn phone/bento mockups with real studio captures or before/after frames. This needs the user's choice of source: studio capture, their own footage, or Higgsfield generation (costs credits).
- **Suggested, not done:** drop the feature-card filler labels 핵심/일괄/화질 and keep only 베타. This was outside item 4, so the change was reverted. Ask the user, e.g. together with item 3.
- **Next: 3. Rhythm.**
  - Cut the five centred eyebrow labels (기능/변환 예시/사용 방법/요금/FAQ) down to 1–2.
  - Left-align some headings.
  - Fold "사용 방법" into "변환 예시", since the 3-step story is told four times.
- **Pre-launch gaps:**
  - The footer's 이용약관 / 개인정보처리방침 still say "(준비 중)". These need real legal text from the user.
  - Set `metadataBase` once the domain is decided. The build currently warns and falls back to localhost.
  - `public/` still holds the unused Create Next App SVGs (only mentioned, not deleted).

**Why:** the user is preparing a commercial launch, and Vmake is the bar ([[service-launch-plan]]). The design system is shadcn/ui + Solace sections ([[ui-and-asr-candidates]]).

**How to apply:**
- Start the next design pass from items 2 and 3, and ask which image source to use.
- Keep the one-accent rule (cobalt only).
- Keep the one-CTA-label rule.
- Keep the share/icon colours in `src/lib/brand.ts` in sync with globals.css. `theme.test.ts` enforces this.
