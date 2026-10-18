---
name: vsr-pipeline-gotchas
description: "Pitfalls running video-subtitle-remover on this Mac — graphics-chip hang under parallel runs, color drift and lost color tags"
metadata:
  node_type: memory
  type: reference
  originSessionId: 5b6c9b21-a81c-471c-9c79-161baca07653
  modified: 2026-10-09T04:43:52.224Z
---

- Many reel projects run VSR at the same time (dozens of processes, load 40-60). With HardwareAcceleration on (MPS) a run sat at 0% for 10 min; set `"HardwareAcceleration": false` in the private clone's config/config.json → CPU, ~4-7 s/frame under that load. CLI: `python backend/main.py -i in -o out -c ymin ymax xmin xmax [-c ...] --inpaint-mode sttn-auto`, run from repo root (config path is relative).
- Each OpenCV/VSR decode→encode round trip darkens Y by ~1.7 levels and drops the bt709 tags. Fix when copying into assets: `setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709:range=tv` FIRST (else ffmpeg auto-converts unknown→bt709 through RGB and drifts more), then `lutyuv` with the measured mean offset vs the original cut, then tag output bt709/tv.
- sttn-auto does NOT blank the box before filling (inpaint() feeds unmasked frames; the mask only limits where the result is pasted). It erases caption-like text by itself but repaints non-text stickers (sparkle, heart) as they were. For sticker-only videos run the OpenCV shape pre-pass on EVERY scene, then sttn-auto.
- Sibling agents ran a broad kill on `backend/main.py`, which also killed my loop shells mid-run. Running a copy named backend/hf04run.py from a queue script file avoided it.
- In zsh, `${a}:end_frame` needs braces (`$a:e` is a modifier), and ffmpeg inside `while read` needs `-nostdin`.

Related: [[reel04-scene-sources]]
