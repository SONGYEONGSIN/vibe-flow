---
name: ui-and-asr-candidates
description: Verdicts (2026-10-05) on Solace UI blocks and Phonon-2 speech recognition for the commercial launch — license and language fit
metadata:
  type: reference
---

Checked 2026-10-05 from items in the user's X AI digest (~/.aside/.../artifacts/X-AI-Digest.md).

- **Solace UI** (solaceui.com, shadcn registry `@solaceui`, author @harshitlog):
  - The code is public without login.
  - **There is no LICENSE anywhere** (terms page 404, nothing in registry.json), so by default it is all rights reserved.
  - Some blocks embed React Bits (MIT + Commons Clause, no redistribution) and Motion Primitives (MIT).
  - Missing sections: pricing, FAQ, CTA and steps.
  - Some items need undeclared deps (ogl, use-sound), motion ^12, and remote images on assets.solaceui.com.
  - The author's mobile-saas-template repo IS MIT (pricing / cta / logos).
  - Re-checked 2026-10-05: when the author listed it in shadcn's registry directory (github.com/shadcn-ui/ui/issues/8650, closed), they ticked "open source and publicly accessible". There is still no LICENSE.
  - The user asked "못가져와?". They were told it can be imported but has no written commercial grant, and were given a one-line DM draft to @harshitlog.
  - 2026-10-08: the user said "가져와", accepting the risk. Adapted with provenance comments:
    - bento-grid-2 → src/components/landing/Features.tsx with our own FeatureMockups;
    - phone-mockups-1 → PhoneCarousel.tsx and PhoneFrame.tsx, with drawn screens in PhoneShowcase.tsx.
  - Not used:
    - bento-grid-1 and -4 (third-party logos and portraits; -4 needs ogl);
    - bento-grid-3 (built around app-logo illustrations).
  - Adaptations:
    - theme tokens instead of zinc/hex;
    - an HTML screen layer instead of foreignObject (Safari transforms);
    - server-side rendering with no isClient placeholder;
    - our own useSyncExternalStore reduced-motion hook (motion's hook caches its first value globally);
    - transitions limited to translate/scale/opacity/shadow (transition-all faded the cards on a theme switch);
    - motion ^12.43 (the blocks target 12).
  - The author's confirmation is still pending.
- **Phonon-2** (FermionResearch, CC-BY-4.0 weights derived from NVIDIA Parakeet, MLX):
  - **English only.** No Mandarin, Korean or Japanese, so it is useless for XHS/Douyin sources.
  - Training data includes SPGISpeech, whose terms allow academic/internal use only; it needs legal review even for English.
  - For a speech → Korean caption feature, use Whisper large-v3(-turbo), MIT:
    - mlx-whisper or whisper.cpp on Mac;
    - faster-whisper on a Linux GPU server;
    - word timestamps can feed the existing translate → caption-render → overlay pipeline.

Whisper large-v3 + Silero VAD was then built as the `speech` mode — see [[speech-captions]].

Related: [[service-launch-plan]], [[subtitle-removal-status]].
