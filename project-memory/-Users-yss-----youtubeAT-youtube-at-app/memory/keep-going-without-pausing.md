---
name: keep-going-without-pausing
description: User wants queued work carried through to the end in one go — never end a turn announcing next steps without doing them
metadata:
  type: feedback
---

When there are known remaining steps (fixes to apply, tests to run, videos to open), do them in the same turn. Do not end a turn with "I'll do X next" and stop.

**Why:** on 2026-10-02 to 10-04 the user had to ask "끊김?", "연결 끊겼나" and "멈추지 말고 진행해야지" after I ended turns that only announced the next step.

**How to apply:**
- After a background job finishes, immediately do everything that follows from it.
- Only stop for user decisions, credentials, or long background waits. When stopping for a wait, say what is running and that it will continue automatically.
- Related: [[subtitle-removal-status]].
