---
name: reel02-rough-cut-state
description: "여행수납가방 릴스 02 — rough cut done 2026-10-09, waiting for the user's voice recording; how subtitles were removed"
metadata:
  node_type: memory
  type: project
  originSessionId: 2652236b-22a6-4620-a917-9f7f27a41dd0
  modified: 2026-10-09T04:31:24.566Z
---

As of 2026-10-09 the 02 reel (맘픽 style, 2안 '저만 몰랐나요?') is a rough cut timed to script length (19s). Script/cover/caption/DM are in /Users/yss/서진하/video-work/2026-10-09_여행수납가방/대본-02.md. Voice will arrive in that folder's 녹음/ as files starting with 02 → split per sentence, retime scenes + captions to it.

- Footage is tight: only ~19.6s of usable unique shots (10.3–11.8s shows an ID card, 22.3s+ is other bags). The ending reuses the opening hanging shot as a loop; slow playback rates (0.64–0.99) fill time. A longer voice will need more slow-down or reuse.
- The video hangs on a wall hook, not a door, so the script says "고리에 툭".
- Subtitle removal: video-subtitle-remover lives at /tmp/vsr-src (venv /tmp/vsr-env, Python 3.12, MPS). Boxes in 720x960 source px: horizontal 724-780 × 292-432, vertical 668-838 × 370-420.
- **Why:** sttn-auto alone left readable ghosts on still shots and missed the white typing-cursor bar and vertical text. **How to apply:** run an OpenCV pass first on every segment (top-hat stroke mask + dark rim, filled with the local average of surrounding non-text pixels), then sttn-auto; process each shot separately (hidden cuts at 9.07, 11.23, 11.97, 12.63, 13.30, 14.37, 20.67s).
