---
name: mompick-production-standards
description: "House standards for every 맘픽 Reel build (captions, cover, [광고] label, ding, SFX, no BGM, voice tone) and where the templates live"
metadata:
  node_type: memory
  type: feedback
  originSessionId: f2114c72-0a58-4965-86c5-64fccb33c154
  modified: 2026-10-14T04:54:57.590Z
---

Settled in the 여행수납가방 1안 project (2026-10-09); the user asked to apply them to every Reel. Templates: `~/.hyperframes-studio/여행수납가방 릴스 1안 - 고통→해결/` → `compositions/` (ad-label, cover, reel-text, reel-text-pop) and `assets/sfx/` (incl. `follow-ding.mp3`), `assets/fonts/`.
- Captions: NanumSquareRound Bold 60px, centered mid-frame (top ~850), one line, `-webkit-text-stroke: 10px #000` + `text-shadow: 2px 2px 10px rgba(0,0,0,.9), 0 0 8px rgba(0,0,0,.7)`, key word yellow; one highlight line via reel-text-pop at 64px.
- Cover: first 0.133s (4 frames). Line 1 white, line 2 yellow with a dark outline, one emoji per line, Pretendard ExtraBold; curiosity split (pain on top, answer blurred under a big yellow "?"). Give 3 options, #1 recommended. No [광고] on the cover; label and first caption start at 0.133s. Save the cover frame as `완성본/커버*.png`.
- 2026-10-14 (미소 Reel) the user replaced the split cover with the look of the brand's top reference Reel: one full moving scene, no split and no "?", big white lines plus the punch line in a sky-blue box, their own copy ("4인가족 이사견적 비교하다 탈탈 털림"). For brand collabs that come with a reference, ask whether they want that look before defaulting to the split.
- "땡" (`follow-ding.mp3`) at the middle of '나' in "[나도] 남겨주세요", volume ~0.32. A few scene SFX at impacts (0.35–0.6).
- No BGM and no source audio (the user adds music in Instagram).
- Voice: use the user's edited recording as-is; keep the unprocessed file. 1안 chain (from its run log): `highpass=f=75, afftdn=nr=8:nf=-50, firequalizer(tone-match EQ), asetrate/aresample/atempo pitch shift, acompressor=threshold=-22dB:ratio=3:attack=5:release=90:makeup=2, loudnorm=I=-15:TP=-1.5:LRA=7`, 44.1 kHz mono.
- Measure each take before reusing the EQ: takes differ a lot (2026-10-14 the new take already had the presence the 1안 take lacked). Tone target = the approved 1안 `voice-final-high.wav` (within ~2 dB per 1/3-octave band 315 Hz–8 kHz, -15 LUFS).
- Pitch: always raw take +2 semitones. 2026-10-14 I matched a naturally higher take (212 Hz) to the 1안 pitch instead (219 Hz) and the user asked "톤을 좀 더 올려줘", so the +2 st version (~241 Hz) became final. Keep the lower version as an alternate.

**Why:** The user refined these one by one and wants them as the house standard.
**How to apply:** Check each bullet before finishing any Reel. Related: [[user-mompick-reels]], [[miso-moving-collab]].
