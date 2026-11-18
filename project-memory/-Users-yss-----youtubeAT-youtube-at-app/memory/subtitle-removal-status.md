---
name: subtitle-removal-status
description: State of the downloader's subtitle-removal feature after 2026-10-02 (LaMa + real-pixel fill) — what works, known gaps, how quality is measured
metadata:
  type: project
---

As of 2026-10-02 the "자막 제거" option drives VSR (~/tools/video-subtitle-remover, LAMA mode) through scripts/vsr-run.py. The driver:
- narrows text detection to caption bands;
- erases only "still" caption pixels;
- widens rows to catch trailing emoji;
- un-blends semi-transparent caption boxes;
- **new 2026-10-02:** fills caption pixels with real pixels from ±15 neighbouring frames before LaMa. LaMa fills only the rest. Frames with a caption box keep the old path. Acceptance rules:
  - ORB 2000 features plus a RANSAC homography;
  - at least 25% of matches must agree;
  - ring mean error ≤ 8 and every 32 px ring tile ≤ 24;
  - each neighbour adds ≥ 10% of the hole, and each frame is ≥ 20% filled.

The app then composites caption bands onto the original and re-times frames by index. Nothing is committed: the user commits only on request.

**Final bench, v12 → v14 (caption PSNR / flicker@STEP6 / time):**

| case | caption PSNR | flicker@STEP6 | time |
|---|---|---|---|
| c1 | 18.05 → 20.50 | 0.79 → 0.93 | 176 → 256 s |
| c2 | 18.85 → 19.12 | 1.63 → 1.71 | 154 → 219 s |
| c4 | 21.78 → 22.13 | 0.92 → 0.94 | 130 → 203 s |
| c5 | 17.45 → 17.69 | 1.55 → 1.59 | 128 → 191 s |

- c3 (box) is unchanged.
- Real 21 s TikTok: 121 → 253 s.

**Known gaps:**
- emoji alone on a wrapped line;
- mid-brightness coloured boxes;
- text or boxes at the frame edge;
- captions under 4 frames;
- XHS start offset ≤ 67 ms;
- caption pixels the still mask misses (animated stickers, very short captions) can be copied from neighbours;
- static shots still try all 30 neighbours. A farthest-first early exit is a follow-up and needs its own bench.

**Gotcha:** VSR imports ProPainter's RAFT, which calls cv2.setNumThreads(0). The driver re-enables threads during the fill, otherwise it is 4× slower. On macOS (GCD), getNumThreads reports 1 when disabled, and only setNumThreads(0) disables again.

**How to apply:**
- Bench changes with scripts/bench/run-bench.sh. Cases are in the session scratchpad; regenerate them with make-cases.py.
- Keep long runs under `caffeinate -s -i` ([[mac-idle-sleep-measurements]]).
- score.py samples flicker every 6th frame (STEP=6), which hid a pasted wedge fragment on c1 frames 1–4. It was caught only by every-frame scoring plus looking at frames.
- Every-frame mean-of-ratios explodes at duplicated source frames (dG ≈ 0). Use the sum ratio Σ dO / Σ dG per segment: ground truth = 1.0, v12 = 0.69, v14 = 1.00.
- Before blaming an "artifact", compare against the clean ground truth: the c1 244–247 box shape was real content.
- Python tests: `python -B scripts/vsr_run_test.py`, 61 tests, about 10 s. vitest wraps them with a 60 s timeout.
- See [[subtitle-removal-alternatives]] for rejected methods.

**Subtitle replacement (2026-10-05):**
- The "한국어로 바꾸기" mode chains removeSubtitles with a `deps.overlays` hook (subtitle-replacer.ts): caption-events → translation → caption-render.py (Pillow, Pretendard) → PNG overlays in the SAME final encode (`gte(t,s)*lt(t,e)`). Output is `_자막교체.mp4`.
- Translation uses Anthropic SDK `messages.create` with `output_config.format: zodOutputFormat(...)`, effort low, max_tokens 16000, then checks stop_reason (max_tokens/refusal) and zod-parses the text itself — `messages.parse()` threw English SDK errors on truncated/refused answers. Forced tool_choice was rejected in review as a risk with thinking models. Tests drive the real SDK with a fake `fetch`.
- The key comes from browser localStorage `key_claude` and is sent in the request body.
- Not yet verified with a real API call: E2E used a fake translator.
- Known gaps:
  - emoji are dropped (no color emoji font);
  - greedy line wrap can orphan the last word;
  - box style is black only (VSR prints alpha, not colour);
  - timing is ±0.25 s (0.5 s detection samples).
