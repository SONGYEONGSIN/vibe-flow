---
name: subtitle-removal-alternatives
description: 2026-10-01 trials of other fill methods (real-pixel propagation, MiniMax-Remover, CLEAR) on this Mac — what won with identical masks, setup gotchas
metadata:
  type: project
---

User asked (2026-10-01) to keep the production LaMa pipeline untouched and find a fill that looks less "erased". Final comparison used the product's own per-frame masks. They were recorded by wrapping scripts/vsr-run.py's `batch_masks`, with frame numbers taken from VideoCapture read order; output was bit-identical to the normal run.

**Results on synthetic case c1 (caption-area PSNR / flicker):**
- product LaMa: 18.05 / 0.79;
- real-pixel homography propagation v3: 20.83 / 1.02. Up to +4 dB on busy ceiling patterns; also clearly best on the real TikTok (a Christmas stocking, snowflakes).
- MiniMax band-crop: 18.55 / 1.06. Best only where lights move independently of the camera. It distorts detailed content (Santa stocking) and leaves faint seam lines on flat walls; 2.6–3.9 s/frame.

An earlier comparison with masks estimated from output differences (>14) was misleading: those masks were far too wide in busy scenes. Always record the real masks.

**Propagation v3 recipe:**
- ORB features plus RANSAC homography to ±15 neighbours;
- accept a neighbour only if its ring error is ≤ 8 and it covers ≥ 10% of the hole;
- if under 20% of the hole is filled, use LaMa for the whole frame;
- composite LaMa only inside the remaining hole.

**Pitfall:** pasting only masked pixels from the product's LaMa output shows rectangle seams on flat walls. The product's whole-strip paste hides them, at the cost of slightly smearing patterns around the caption.

**Setup gotchas:**
- MiniMax at ~/tools/MiniMax-Remover:
  - patch `.to("cuda:0")` → device and RoPE to float32;
  - use 21-frame chunks;
  - 6 steps are enough;
  - band-crop at native resolution beats full frame at 480x832.
- CLEAR (~/tools/CLEAR-code):
  - its base is really Wan2.1-Fun-V1.1-1.3B-Control;
  - DiffSynth 8332ece via PYTHONPATH; transformers <4.57;
  - float64 → float32 patch;
  - it shifts colour and is research-only licensed, so it was excluded.

**Why:** the propagation fill was integrated into vsr-run.py on 2026-10-02 (see [[subtitle-removal-status]]); these notes explain why MiniMax/CLEAR were not.

**What is gone and what remains (checked 2026-10-09):**
- **Gone:** the experiment scripts, and the outputs in scratchpad `cmp/` (`c1_mmr.mp4`, `tiktok_mmr.mp4`, `c1_prop.mp4`, `tiktok_prop.mp4`). The folder was emptied and nothing was copied to the Desktop.
- **Still installed:** `~/tools/MiniMax-Remover` with weights and the 2 patched files, so a rerun only needs a new driver.
- **Rerun inputs:** they are in `~/Desktop/자막제거_Vmake비교/1_Vmake에_올릴_영상/`.
- **Save location:** put any rerun on the Desktop, not the scratchpad. The user asked about these MiniMax results on 2026-10-09.

**How to apply:** time runs alone, under `caffeinate -s -i` ([[mac-idle-sleep-measurements]]). Production state is in [[subtitle-removal-status]].
