---
name: vsr-edge-subtitles
description: video-subtitle-remover sttn-auto leaves subtitles cut off at the frame edge; fill the box with the sttn-det model instead
metadata:
  node_type: memory
  type: reference
  originSessionId: 8c6df4d4-fab7-407c-81bd-1f0c8b971027
  modified: 2026-10-09T04:01:38.548Z
---

In reel 13's source (<원본 #13>), the Chinese subtitle sits at the very bottom edge (y≈1255–1280 of 720×1280), with only the tops of the letters showing. In YaoFANGUK/video-subtitle-remover, `--inpaint-mode sttn-auto` sends the frames in without blanking the area. Its model decides for itself what is text, so it left these half-cut letters almost untouched.

What worked: call `backend.inpaint.sttn_det_inpaint.STTNDetInpaint.inpaint()` with an explicit box mask. The mask values must be **0/255**; 0/1 gives an empty mask. Give it a 720×400 bottom crop resized to 432×240, then paste back only the masked rows. Do an OpenCV glyph-erase pass first on near-static shots.

On macOS, the first run of a fresh venv in /tmp can sit for minutes in dyld/XProtect checks at 0% CPU. It isn't hung.

**How to apply:** if subtitles are re-removed for this project (or a sibling 여행수납가방 reel), skip straight to the explicit-mask STTN fill for edge subtitles.
