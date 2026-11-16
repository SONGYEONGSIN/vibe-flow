---
name: vsr-sttn-keeps-stickers
description: video-subtitle-remover sttn-auto only erases text; non-text stickers inside the box survive unless pre-erased with OpenCV
metadata:
  node_type: memory
  type: feedback
  originSessionId: b1ffeeb2-670f-4260-819d-029f5b0ed8f1
  modified: 2026-10-09T04:49:47.636Z
---

In video-subtitle-remover `sttn-auto`, the boxes passed with `-c` are not blanked before the model runs: the model is trained to erase text, so yellow planet stickers and heart bubbles inside a box come out untouched on moving scenes. Only clips that were OpenCV-pre-erased first came out clean.

**Why:** On 2026-10-09 (reel 11), 6 of 13 clips still showed the corner stickers after STTN. They were only caught by looking at snapshot frames, so each of those clips had to be run a second time.

**How to apply:** For every clip, OpenCV-inpaint the sticker shapes before STTN. Build the mask from the per-pixel temporal std over the whole source: static sticker pixels have a low std. Erase the subtitle letter shapes first only on near-static scenes, as the user asked. Then count saturated-yellow pixels in the sticker boxes of every output clip to confirm they are gone. Several other reel projects run VSR on the same Mac at the same time, so expect 2 to 7 minutes per clip from contention for the Mac's GPU. Related: [[reel-11-status]]
