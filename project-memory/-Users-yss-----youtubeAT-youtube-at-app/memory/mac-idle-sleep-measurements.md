---
name: mac-idle-sleep-measurements
description: The user's Mac idle-sleeps ~1 min after last input; background jobs/benchmarks stall and wall-clock timings lie unless run under caffeinate -i
metadata:
  type: project
---

The user's Mac (M4 Pro, no battery — pmset shows "Charge:0%") has `pmset sleep 1`: it enters idle sleep about a minute after the last user input, then only DarkWakes ~45 s every ~15 min. Claude Code's own `caffeinate -i -t 300` holds only while a turn is active, so jobs left running in the background while waiting for a notification crawl (2026-09-30: a ~100 s VSR run took 1573 s; the gaps matched `pmset -g log` sleep durations to within 2 s).

**Why:** A whole morning of timing experiments ran during sleep and produced a wrong conclusion (blamed a per-job TMPDIR for a 2x slowdown).
2026-10-05 again: a full `npx vitest run` launched as a long foreground command hit Maintenance Sleep → the Python suite (normally 10 s) took 986 s and failed its 60 s timeout; the Chrome extension also disconnected. Re-run under caffeinate: 293/293 in 11 s.

**How to apply:** Wrap any long background job, benchmark, or full verification run (`caffeinate -s -i npx vitest run`) in caffeinate; before trusting wall-clock timings, check `pmset -g log | grep -E " (Sleep|Wake|DarkWake) "` for the run window. Related: [[subtitle-removal-pipeline]].
