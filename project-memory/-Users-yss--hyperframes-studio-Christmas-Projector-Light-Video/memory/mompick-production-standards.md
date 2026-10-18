---
name: mompick-production-standards
description: "Production standards settled in the 여행수납가방 1안 project; apply them to every 맘픽 Reel (captions, cover, ding, SFX, no BGM, voice tone, 인스타정보 file)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c580430e-475a-49a9-aaf6-75c1f3883d47
  modified: 2026-10-09T09:24:03.411Z
---

On 2026-10-09 the user asked to apply the "여행수납가방 릴스 1안" standards to other projects ("1안에 적용한 기준으로 모두 적용"). Source project: `~/.hyperframes-studio/여행수납가방 릴스 1안 - 고통→해결/`. Reuse its `compositions/` templates and `assets/sfx/`.
- **Captions:** NanumSquareRound Bold 60px, centered mid-frame (top ~850), one line. `-webkit-text-stroke: 10px #000` plus `text-shadow: 2px 2px 10px rgba(0,0,0,.9), 0 0 8px rgba(0,0,0,.7)` (the old editor's "stroke 10, shadow blur 20% / distance 3"). Key word in yellow. One highlight line uses reel-text-pop at 64px.
- **Cover:** the first 0.133s (4 frames), following [[video-references-folder]] docs cover rules. Line 1 white, line 2 yellow with a dark outline, one emoji per line, heavy Pretendard ExtraBold. Use a curiosity structure: before/pain on top, answer blurred under a big yellow "?" below. No [광고] on the cover (the label starts at 0.133s). The first caption also starts at 0.133s. Save the cover frame as `완성본/커버*.png`.
- **"땡" on '나'** of "[나도] 남겨주세요": `follow-ding.mp3`, the bell extracted from the reference videos. Place it at the middle of '나', volume ~0.32 (about 6 dB under the voice).
- **Scene SFX:** a few short effects (휙, 반짝, 지퍼, 뽁, 부스럭…) at impact moments, quieter than the voice (0.35–0.6).
- **No BGM, no source audio:** the user adds music in Instagram, so all video stays muted.
- **The user's recording:** use their edited file as-is (breaths already cut). Apply tone correction toward the reference videos: boost 1.6–3.2 kHz and highs, match loudness, pitch +2 semitones (they asked for a higher voice). Keep the unprocessed file.
- **Work folder:** `video-work/날짜_상품/` gets `인스타정보/인스타정보*.md`, which holds a caption of about 500 characters in 5 paragraphs (pain → product name → features/how → bonus → [나도] + 정보 + DM 보내드릴게요 + profile-link line) with exactly 5 hashtags, the pinned-comment template and a 3-line Inpock message. It also gets a `상품사진/` folder. The product name comes from the Coupang main photo or a title the user gives; Coupang pages block scraping (403).

**Why:** The user refined these one by one in the 1안 session and wants them as the house standard.

**How to apply:** Before finishing any 맘픽 Reel, check each bullet. Related: [[user-mompick-reels]], [[video-references-folder]].
