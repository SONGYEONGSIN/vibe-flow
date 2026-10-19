---
name: mompick-reel-workflow
description: "How the user hands off the posting set (caption, pinned comment, Infork DM) for 맘픽 reels — from a Coupang product main photo"
metadata:
  node_type: memory
  type: user
  originSessionId: 3602d5e9-b847-4711-93ee-bd10978d38a1
  modified: 2026-10-09T06:15:14.918Z
---

The user (맘픽 @mom._.pic reels, Coupang Partners) used to give Gemini the **Coupang product main photo** and get back the posting set: caption (exactly 5 hashtags), pinned comment, and Infork DM text. Current handoff (set 2026-10-09): the user pastes the **Coupang product link in chat**; I look it up with the Partners API ([[coupang-partners-api]]) and save the set as an md file in the work folder's `인스타정보/` subfolder (`/Users/yss/서진하/video-work/<date>_<product>/인스타정보/`, e.g. `인스타정보-2안.md`). Product photos or page screenshots, if any, go in `상품사진/` next to it and are used for feature details the API lacks.

Formats come from `/Users/yss/서진하/video-references/docs/gemini-대화-주제별정리.md`:
- Caption: story → benefit → "[나도]" CTA, 5 hashtags.
- Pinned comment template: "👇 (한 줄 훅) ✨ / ✔️ 댓글에 [나도] 남겨주세요 / ✔️혹시 DM이 안 오면 팔로우 확인해 주세요!🙏 / ✔️숨은 요청함도 꼭 확인해 주세요💌".
- Infork: first line "[아래 링크를 통해 구매하시면 쿠팡 파트너스 활동의 일환으로, 일정 수수료를 받습니다.]", core summary, last line "🔻아래 클릭 후 [검색어]를 검색해 주세요🔻".

Read product name/features off the photo; ask for the Coupang product title if the photo lacks them. Related: [[cover-follows-reference-docs]].
