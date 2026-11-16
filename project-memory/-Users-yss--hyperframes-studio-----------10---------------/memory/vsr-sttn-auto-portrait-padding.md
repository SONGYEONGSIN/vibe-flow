---
name: vsr-sttn-auto-portrait-padding
description: video-subtitle-remover sttn-auto silently leaves subtitles on 720x1280 portrait video unless the frame is padded sideways first
metadata:
  node_type: memory
  type: reference
  originSessionId: adddd5f3-c42e-4ccd-be72-bff30c02640e
  modified: 2026-10-09T04:25:50.082Z
---

YaoFANGUK/video-subtitle-remover (`backend/main.py --inpaint-mode sttn-auto -c ymin ymax xmin xmax`) "completes" on 720x1280 portrait clips but the Chinese subtitle is still there (output ≈ input). Cause: STTN works on a full-width strip `W*3/16` tall resized to 640x120; on portrait video the text is ~2x too large in that strip, so the model doesn't treat it as a subtitle. Verified 2026-10-09: same model erases its own landscape test clip fine.

Fix that worked: mirror-pad each frame 360px left and right (720→1440 wide, `cv2.BORDER_REFLECT`), shift the box x by +360, run the CLI unchanged, then crop `crop=720:1280:360:0`. Text gone, background (suitcase edges, stripes) rebuilt.

Also: the run always prints an "Audio extraction failed" traceback for silent input; harmless. Many parallel agents on the same Mac share the GPU (MPS), so each shot takes 2–5 min.

Related: [[mompick-reels-workflow]]
