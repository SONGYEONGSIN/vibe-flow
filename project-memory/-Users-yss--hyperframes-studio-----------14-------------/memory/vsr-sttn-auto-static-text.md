---
name: vsr-sttn-auto-static-text
description: video-subtitle-remover sttn-auto leaves burned-in subtitles intact on static shots; what erase pre-pass works for mompick reel 14 footage
metadata:
  node_type: memory
  type: project
  originSessionId: 9505707b-85fc-4f39-9622-d4f73c32e9ac
  modified: 2026-10-09T04:17:41.299Z
---

For reel 14 (2026-10-09, travel organizer, source 720x1280 with blurred bands rows 0-159 and 1120-1279, subtitle line rows ~974-1015):
sttn-auto alone only blurred the Chinese subtitle — it feeds raw pixels (no hole) and copies the same letters from neighbour frames when camera/text are static. A glyph-only pre-erase before STTN is required on every shot here, not just "static" ones.

- Glyph mask: white (min>200, low chroma) pixels next to dark outline, dilate 7px (4px left dark shadow smudges).
- OpenCV Telea: fine on plain floor/wall; bleeds blue zipper edges and smears the bag print.
- LaMa (VSR's own backend/models/big-lama) on a 256-row window: best on the patterned bag; slight grey tint on stripes.
- Column-wise vertical fill: best on the striped pink suitcase.
- Many sibling reel agents run VSR concurrently on the same GPU, so each STTN run can take 5+ min.
- zsh does not word-split `$var`; run per-line loops under `bash -c`.

**Why:** the user's recipe (OpenCV then STTN only for static scenes) under-delivers on this footage.
**How to apply:** for the other travel-organizer reels, pre-erase every shot and pick the eraser by background; compare original / pass in band crops before using. Related: [[mompick-reel-format]]
