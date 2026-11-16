---
name: codex-split-pane-orca
description: "To talk to Codex, use the split pane next to this Claude session in Orca — never open a new Codex tab"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 6ac41cfc-052b-4996-b1d0-596997348464
  modified: 2026-10-31T05:28:55.898Z
---

When the user says Codex is open "옆 분할터미널", talk to **that** pane (same Orca tab as this session: find the terminal whose tabId equals `$ORCA_TAB_ID` via `/Applications/Orca.app/Contents/Resources/bin/orca terminal list --json`). Do not create a new Codex tab/terminal.

**Why:** On 2026-10-31 I opened a separate "Codex · 공모전" tab to get around a blocked send; the user objected ("새로운 탭을 켰네.. 현재 창 옆에 코덱스 켜놨다고") and said to use the split pane from now on.

**How to apply:**
- Use the app-bundled CLI `/Applications/Orca.app/Contents/Resources/bin/orca` (the `/usr/local/bin/orca` lacks some subcommands).
- `terminal read` → `terminal wait --for tui-idle --timeout-ms N` → `terminal send --text ... --enter --wait-submit N`.
- If wait reports `blockedReason` (`agent-update-prompt`, `agent-trust-workspace`, `agent-hooks-review-prompt`), ask the user to clear it in that pane; trust/hook decisions are theirs.
- `codex exec` from this shell fails auth because Orca-launched Codex uses `CODEX_HOME=~/Library/Application Support/orca/codex-runtime-home/home`.
- Related project: [[meta-ai-festival-project]]
