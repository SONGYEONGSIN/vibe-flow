---
name: reel04-scene-sources
description: "Reel 04 (6in1 puppy bag): which original-video frames each cleaned clip in assets/clean/ came from, and what was skipped"
metadata:
  node_type: memory
  type: project
  originSessionId: 5b6c9b21-a81c-471c-9c79-161baca07653
  modified: 2026-10-09T03:48:00.068Z
---

Original: assets/六合一收纳袋…_685ce28a0000000011001492.mp4 (30fps, 720x1280, 679 frames). No burned-in Chinese subtitles; only a wiggling yellow sparkle sticker top-left (x0-25, y22-111) and a static pink heart bottom-left (x21-39, y1240-1255). Removed with OpenCV pre-pass + VSR sttn-auto, areas `-c 18 116 0 30 -c 1237 1258 18 42`.

Cleaned clip → original frame range (inclusive): 01 unfold-flatlay 24-123 · 02 unzip-underwear 124-144 · 03 rolled-clothes 156-194 · 04 bed-unfold 320-356 · 05 sofa-stuffing 357-410 · 06 rack-socks-zip 437-520 · 07 door-hang 521-548 · 08 into-suitcase 577-618 · 09 suitcase-handle 619-652 · 10 wide-end 653-678 · 11 yellow-top 195-228 · 12 fold-tote 549-576 · 13 sofa-press 411-436.

Skipped on purpose: frames 229-319 (7.6-10.6s) show a card with Chinese text and a red stamp in the mesh pocket.

**Why:** if the voice recording (녹음/04*) needs longer shots, extend from these ranges instead of re-guessing; never cross the scene cuts at 124,145,195,229,251,274,298,320,357,437,521,549,577,619,653.
**How to apply:** re-cut more frames → same pipeline, see [[vsr-pipeline-gotchas]].
