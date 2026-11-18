---
name: external-repos-checked
description: Repos the user asked to evaluate for subtitle/watermark removal on 2026-10-02 (OpenMontage, OpenCut, Agent-Reach) and the verdicts
metadata:
  type: reference
---

Checked 2026-10-02. Clones are in ~/tools.

- **OpenMontage** (calesthio/OpenMontage, AGPL-3.0):
  - agentic video-production framework with no burned-in subtitle removal; its subtitle tools only ADD captions;
  - the closest feature is a cloud Gemini `edit_video` that regenerates 3–10 s 720p clips (~$0.10/s, needs an API key);
  - its docs point to an external claude-code-video-toolkit (Modal ProPainter, DEWATERMARK), which was not inspected.
- **OpenCut** (OpenCut-App/OpenCut, MIT):
  - CapCut-style editor; main is a rewrite scaffold, and the classic version is archived;
  - no removal. It only has in-browser Whisper auto-captions, plus a Gaussian blur and rectangle masks for manual cover-up.
- **Agent-Reach** (Panniantong/Agent-Reach; venv at ~/tools/Agent-Reach/.venv):
  - X search via twitter-cli needs the user's X cookies `auth_token` and `ct0` as env TWITTER_AUTH_TOKEN/TWITTER_CT0. The README advises a throwaway account (ban risk).
  - Without the env vars, twitter-cli tries to read browser cookies or the Keychain, so do not run it that way.
  - Never run. The user was asked for cookies but has not provided them yet.
  - A fallback web search of X found WatermarkRemover-AI (Florence-2 + LaMa, macOS), the LTX2.3 IC-Edit LoRA (CUDA, 29 GB) and Douyin no-watermark downloaders. None beat the current pipeline.
