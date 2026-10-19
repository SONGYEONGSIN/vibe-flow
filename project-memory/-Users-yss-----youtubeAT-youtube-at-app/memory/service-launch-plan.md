---
name: service-launch-plan
description: User intends to launch the downloader/subtitle remover as a service (2026-10-04); benchmark target is Vmake AI; model-license constraints
metadata:
  type: project
---

On 2026-10-04 the user said they plan to launch this as a service. People told them "v-maker", most likely Vmake AI (vmake.ai, Starii Tech, Palo Alto), is widely used and leaves almost no trace of removed subtitles.

What we know about Vmake: a cloud "generative fill" using colour, texture and motion; the model is undisclosed; batch of 30; API; manual removal and protected areas; credit pricing.

**Licences for commercial use (checked 2026-10-04):**
- OK: our pipeline. VSR framework (Apache-2.0) in LaMa mode, LaMa, PaddleOCR, OpenCV, and our own real-pixel propagation.
- NOT OK without permission:
  - ProPainter (NTU S-Lab, non-commercial). VSR's ProPainter mode bundles it.
  - E2FGVI (CC BY-NC 4.0).
  - MiniMax-Remover (CC BY-NC 4.0).
  - DiffuEraser (depends on ProPainter).
  - CLEAR (research-only).

**Why:** quality decisions must stay within commercially usable components. Legal exposure (platform ToS, removing watermarks or credits as rights-management information) needs a lawyer before launch.

**How to apply:**
- Compare against Vmake with ~/Desktop/자막제거_Vmake비교:
  - 1_Vmake에_올릴_영상 holds c1–c5 + tiktok inputs;
  - 2_우리_결과 holds v14 outputs;
  - 4_채점용_정답 holds clean.mp4 + a manifest with Desktop paths, which reproduces c1 20.50 dB.
- Scratchpad files can vanish: final4/ was emptied on 2026-10-04.
- See [[subtitle-removal-status]] and [[subtitle-removal-alternatives]].

**Site decisions (2026-10-05):**
- The website is the video downloader only.
  - Other features (YouTube automation, finders, TTS, imagegen …) were moved uncommitted to ../youtube-at-app-보관함/.
  - The pre-redesign src backup is in 보관함/디자인개편-전-20261005.
- Routes:
  - `/` is the landing page: hero with a CSS phone mockup (no third-party footage), features, how it works, pricing hypotheses (free / 14,900 / 49,000) and FAQ with a rights notice.
  - `/studio` is the app.
- The working title "영상 현지화 스튜디오" lives in src/lib/site.ts. The user wants general positioning, not "쿠팡 파트너스".
- Design system: shadcn/ui (radix-nova preset, neutral), light by default plus dark via next-themes, brand violet token, Pretendard Variable font, word-break keep-all.
- 2026-10-05 the :3000 dev server was confirmed serving the new CSS (a hard reload is enough).
- Studio UX (2026-10-05): one card per video, pre-created as 대기 from parseUrls (the server splits the same way, so indices match); running % / done + 폴더 열기 (opens the card's own dir) / failed + reason + in-place 다시 시도; a stream cut or fatal turns unfinished cards into failed; raw log collapsed under 자세히 보기; wiring covered by a jsdom flow test (VideoDownloader.flow.test.tsx); landing hero mockup animates find → erase → Korean caption (motion-safe only, static final frame otherwise).
- The user picked "shadcn/ui + Solace UI 구획" for the design system, but Solace UI has no license (see [[ui-and-asr-candidates]]), so none of its code was imported; awaiting their call.

**Git (2026-10-08):**
- All work is committed on branch `feat/localization-studio`; nothing is pushed and there is no PR. Commits:
  - 945c18a — the baseline;
  - e5e2c22 — replace-mode ffmpeg thread pinning;
  - 6ddc787, b67dc93 — landing copy for speech captions;
  - be50ab2 — Solace sections (bento grid + phone carousel). This made the landing CSS-only and dropped motion, taking home JS from 278 to 236 kB gz.
- Spelling is inconsistent: the studio and JobList say "샤오홍수", the landing says "샤오홍슈". Not fixed yet; reported to the user.
