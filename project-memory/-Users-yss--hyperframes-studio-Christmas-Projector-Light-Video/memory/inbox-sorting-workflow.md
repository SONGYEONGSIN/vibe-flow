---
name: inbox-sorting-workflow
description: "When the user says \"정리해줘\", sort new videos from ~/서진하/video-work/_받은영상 into dated per-product folders after watching them"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c580430e-475a-49a9-aaf6-75c1f3883d47
  modified: 2026-10-09T02:47:55.697Z
---

The user drops videos to work on into `/Users/yss/서진하/video-work/_받은영상/` and asks to "정리해줘". Then:
1. Open each video (contact sheet of frames) and use the file name/title to identify the product.
2. Per product, create `video-work/YYYY-MM-DD_상품명/` (today's date) with `원본/`, `녹음/`, `완성본/`, `대본.md`, and **move** the videos into `원본/` so the inbox empties. Group same-product clips; split mixed products.
3. If the product can't be identified with confidence, ask the user instead of guessing a name.
4. Report per product: length, resolution, burned-in captions, foreign money/price tags, anything to fix before editing.

**Why:** The user agreed on 2026-10-09 to use a single inbox and have it sorted on request, so files never mix between products and each video's work is findable by date and product.

**How to apply:** Only sort when asked. Nothing runs automatically, because identifying products needs someone to watch the video. Related: [[video-references-folder]], [[user-mompick-reels]].
