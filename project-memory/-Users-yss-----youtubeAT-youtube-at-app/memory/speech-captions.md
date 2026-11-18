---
name: speech-captions
description: "말소리로 한국어 자막" mode (2026-10-05) — Whisper+VAD toolchain in ~/tools/whisper, why VAD is mandatory, model choice, bench clips, known gaps
metadata:
  type: project
---

Built 2026-10-05; uncommitted, like the rest of the app. Subtitle mode `speech`: transcribe speech → Claude translates (fromSpeech hint) → caption-render.py PNGs → ffmpeg overlay → `원래이름_한국어자막.mp4`. Pipeline: src/lib/speech-captions.ts (+ speech-cues.ts), driver scripts/speech-run.py, route prepareSpeechCaptions (darwin + arm64 only).

**Toolchain (outside the repo):** `~/tools/whisper/.venv`
- Python 3.13 via uv
- mlx-whisper 0.4.3, mlx 0.32.3
- faster-whisper, installed only for `faster_whisper.vad` (Silero, MIT). Its `decode_audio` crashes with the installed PyAV (`metadata_errors` kwarg), so audio is loaded with `mlx_whisper.audio.load_audio`.
- Pillow 12.3, so speech mode does not need the VSR venv.
- Models are cached in ~/.cache/huggingface: `whisper-large-v3-mlx` (default) and `-turbo`. Runs use `HF_HUB_OFFLINE=1`.

**Why:**
- Plain Whisper hallucinated on a music-only TikTok ("Terima kasih telah menonton", repeated "oh", timestamps past the end). `hallucination_silence_threshold` didn't help.
- VAD gating (speech < 1 s → skip) is necessary but NOT via `clip_timestamps`. mlx-whisper 0.4.3 still decodes the gaps between clips (review repro: "作曲 李宗盛" inside 42 s of music) and detects language from the file's first 30 s.
- Final design: concatenate only the VAD spans with **1 s of silence between them** (JOIN_GAP). Restore times per word: the span containing the word's midpoint, or the nearest span if it falls in a gap, clamped inside that span. Split segments at span joins.
- Without the silence, the next span's first word "今天" was stamped at the previous span's end (10.30 s instead of 55.10 s).
- On speech with music, large-v3 had a 16% character error rate vs 28% for turbo, at 1.9 s vs 1.2 s per 12 s of audio.

**How to apply:**
- Bench clips are made with `say -v "Flo (중국어(중국 본토))" -r 215` over the c1.mp4 video, plus a variant mixing in the TikTok music at volume 0.22.
- E2E: run `npx tsx <script>.mts` that imports src/lib/speech-captions.ts with a real spawner and a fake translator. The file must be `.mts`, because tsx treats `.ts` as CJS.
- Homebrew ffmpeg has no `drawtext` (no freetype): draw labels with Pillow.
- Results for the user are in ~/Desktop/말소리자막_확인.

**Known gaps:**
- Speech under music is still misheard; vocal separation (demucs) is a next step.
- Apple Silicon only (a server would need faster-whisper on CUDA).
- One ffmpeg input per caption. With default threads, hundreds of PNG inputs exhaust threads ("Resource temporarily unavailable"); ffmpeg still exits 0 but silently drops captions. Stress test, 600 one-frame overlays: lost 11–273 in 4/4 runs.
- Fix: `-filter_complex_threads 1` plus `-threads 1` before each PNG `-i`, which gave 0 lost in 4/4. MAX_CUES 500 is kept as margin.
- The replace mode's buildCompressArgs has the same pattern and is not fixed yet; this was reported to the user as a follow-up.
- `speech-run.py --check` (imports + local model) runs in the route before yt-dlp.
- A real Claude translation has not been verified, because the key lives in the browser.

Related: [[ui-and-asr-candidates]], [[subtitle-removal-status]], [[mac-idle-sleep-measurements]].
