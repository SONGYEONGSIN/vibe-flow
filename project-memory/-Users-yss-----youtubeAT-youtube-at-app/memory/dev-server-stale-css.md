---
name: dev-server-stale-css
description: next dev (16.2.1 Turbopack) here stops picking up file edits — stale CSS/HTML; a fresh start after clearing .next/dev/cache/turbopack shows current code
metadata:
  type: project
---

On 2026-10-08, localhost:3000 kept serving old code after edits. Verified facts:

- **Long-running server (started 2026-09-29):**
  - It served an old `globals.css` even though the source was changed and `touch`ed.
  - `next build` produced the correct CSS.
  - A Turbopack panic ("Input image not found", `$TMPDIR/next-panic-*.log`) happened when `src/app/favicon.ico` was deleted while dev ran. The log shows that process did attempt HMR updates on edits.
- **Restarting without clearing the cache** still served the stale CSS. The Turbopack disk cache was holding it.
- **After `rm -rf .next/dev/cache/turbopack` + restart:**
  - The first request compiles current disk content correctly.
  - Later edits, `touch` included, are never picked up: no "Compiled" log lines, even with a browser HMR client connected.
  - This was the same whether dev was started with `nohup npm run dev &` or as a managed background task.
- **Ruled out:**
  - Node `fs.watch` gets events in this repo's path.
  - fd limits are high.
  - The folder name "서진하" is NFD both on disk and in `process.cwd()`.
- **Cause:** not found.

**Why:** a stale dev server makes correct code look broken. A wrong conclusion here once nearly sent me to "fix" working CSS.

**How to apply:**
- Never trust localhost:3000 visuals right after an edit. Either restart dev after clearing `.next/dev/cache/turbopack`, or check with `next build && next start -p 3001`.
- Before restyling, fetch the served HTML/CSS and grep for the change.
- Stop dev before deleting files Next treats as metadata images.
- Related: [[mac-idle-sleep-measurements]].
