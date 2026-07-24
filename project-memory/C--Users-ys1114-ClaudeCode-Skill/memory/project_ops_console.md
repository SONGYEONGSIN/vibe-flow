---
name: OPS console project state
description: OPS console — Linear-style internal admin SaaS at C:\Users\ys1114\ClaudeCode\ops-console\, currently P1 done + Stitch design workflow active for login page
type: project
originSessionId: 31d8f8df-1fce-462c-8211-720f4b89583a
---
OPS console is a Korean internal operations admin tool the user is building. Located at `C:\Users\ys1114\ClaudeCode\ops-console\`.

**Stack**: Next.js 16 (Tailwind v4 + shadcn/ui v4), TypeScript, Auth.js v5 with Microsoft Entra ID SSO planned, Recharts, lucide-react, Inter + Pretendard fonts. Dev server pinned to port 3010.

**Plan**: 4 phases — P1 scaffold/design-tokens (✅ done, tag v0.1.0-p1), P2 auth (login + Entra ID + signup), P3 app shell (sidebar with 30 menus across 6 sections + ⌘K), P4 dashboard (실시간 현황 with 6 widgets).

**Style**: Linear-inspired minimal — dark mode default + light toggle, Linear violet `#5e6ad2` single accent, sharp 6-8px radii, no shadows (1px borders only). All design tokens live in `styles/tokens.css` and are mapped via `@theme` block in `app/globals.css` (Tailwind v4, no `tailwind.config.ts`).

**Key files**:
- `docs/specs/2026-05-07-ops-console-design.md` — full 12-section spec
- `docs/plans/2026-05-07-P1-scaffold.md` — completed P1 plan
- `stitch/WORKFLOW.md` — Stitch import progress tracker
- `stitch/login/prompt.md` — Stitch input prompt for login page (ready to paste)
- `prototypes/` — 6 design exploration HTMLs (landing v1/v2, dashboard-skill v1/v2, dashboard-frontend-design v1/v2)

**Why**: User wants a single console replacing scattered tools (메신저/메일/캘린더/스프레드시트) for ops team to manage 179 services across 30 menus in 6 sections (개요, 요청·자료, 서비스 그룹, 분석·AI, 매뉴얼·가이드, 관리). 17 operators are target users.

**How to apply**: When user says "이어서" or asks about OPS console, check `stitch/WORKFLOW.md` for current step. Login is the active page in the Stitch workflow. Stitch step 1 (enhance-prompt) is done; user needs to take prompt to https://stitch.withgoogle.com next, then come back with downloads to run `design-md` skill (step 4).
