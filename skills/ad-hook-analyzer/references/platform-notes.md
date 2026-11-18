# Platform Notes - Hook Windows, View Counting, Denominators

This file is the platform-differences reference: hook windows for normalising a batch (workflow step 2) and counting rules for the calibration step. Everything here is platform-defined and changes over time - when a number matters, verify it against the platform's current help documentation before relying on it.

**The core warning**: no platform exposes "hook rate" as a native metric. It is always a constructed ratio, and constructions differ. Two dashboards can report different "hold rates" for the same ad because one divides completion-style plays by impressions and the other by 3-second plays.

Never compare a hook rate, view rate, or hold rate across platforms, across dashboards with different constructions, or across a platform's own counting changes. Within one account: lock one definition, write it on every scorecard, calibrate only against it.

## Meta (Facebook/Instagram)

- **Hook window**: feed placements, first ~3 seconds.
- **Autoplay**: muted by default - sound-off legibility is a hard constraint. Meta's creative guidance recommends carrying the opening with text, graphics, and captions.
- **View counting**: 2-second continuous play is the shortest view unit (2+ continuous seconds, ~50% of video in view); 3-second video play is the standard short metric (3+ seconds, or ~97% of a shorter video; replays excluded); ThruPlay = completion or at least 15 seconds.
- **Hook-rate construction**: `3-second video plays ÷ impressions` - the dominant practitioner definition. Because Meta autoplays in feed, video plays ≈ impressions, so this reads roughly as "share of impressions retained past 3 seconds."
- **Hold-rate constructions in circulation**: `ThruPlays ÷ impressions` _and_ `ThruPlays ÷ 3-second plays` - both are in active use; this is the two-dashboards trap. State which one the account uses.

## TikTok

- **Hook window**: first ~3 seconds - TikTok's own Creative Codes emphasise hooking within the first 3 seconds (platform-echoed heuristic, partially evidence-backed via TikTok Marketing Science / Kantar and Ipsos studies).
- **View counting**: 2-second video view (played at least 2 seconds, replays excluded) is the shortest unit; 6-second view (or an engagement in the first 6 seconds) is the standard short metric; quartile completions at 25/50/75/100%.
- **Hook-rate construction**: `2-second views ÷ impressions` (some practitioners call this "thumb-stop rate"). Not comparable with Meta's 3-second construction - a "better hook rate on TikTok than Meta" claim is comparing different metrics.
- Sound-on culture is stronger than on Meta/LinkedIn, but muted and captioned viewing is common enough that sound-off legibility still gates.

## YouTube / Google Ads

Windows and counting differ _per format_ - normalise each candidate to the format actually booked:

- **Skippable in-stream**: the skip button appears at 5 seconds, so the hook window is the first ~5 seconds. A paid "view" counts at 30 seconds, completion, or interaction - whichever comes first - so view rate here measures something very different from a feed hook rate.
- **Bumper (6s) and non-skippable**: forced views - no view is counted in the skippable sense, and there is no scroll to stop. "Stop the scroll" logic does not apply at all; judge continuity, branding, and qualification instead.
- **In-feed**: a view = a click through to the watch page - closer to a thumbnail/headline test than a video hook test.
- **Counting-change dates that break comparisons**:
  - On **31 March 2025**, YouTube switched Shorts to play-based counting (any start or replay counts; the older stricter metric was renamed _engaged views_).
  - On **24 August 2026**, play-based counting extended to long-form, live, and podcasts.

  Public view counts before and after each date are different metrics - never trend or calibrate across them. Monetization still runs on engaged views.

## LinkedIn

- **Hook window**: feed, first ~3 seconds - same feed logic as Meta.
- **Autoplay**: muted by default - captions and on-screen text are effectively mandatory.
- **View counting**: a view = 2+ continuous seconds with at least 50% of the player on screen (MRC-aligned). This is a weak "pause" signal, not attention - treat LinkedIn view counts as inflated relative to real attention, and prefer completion and watch-time metrics for calibration. Practitioner-reported median watch time sits near ~6 seconds (ZenABM's figure - directional, not official).
- **Counting-change date**: in **October 2022** LinkedIn changed video completion rate from `completions ÷ views` to `completions ÷ plays`. Completion-rate data spanning that date is not comparable.
- Mostly B2B inventory: the 95:5 out-of-market logic applies, so calibrating a LinkedIn batch on short-view rates alone is doubly weak - the metric is soft _and_ the objective is usually memory, not the click.

## Folklore ledger - famous numbers, real origins

If any of these appear (in the user's brief, an agency deck, a brief you are reviewing), correct the record in the same breath or leave them out entirely:

- **"You have 0.25 seconds to capture attention"** - a 2016 Fors Marsh finding that people can _recall_ feed content at statistically significant rates after 0.25 seconds of exposure. A recall-at-exposure statistic, not an attention deadline.
- **"1.7 seconds per piece of content"** - Facebook's own 2016 average for time spent with mobile content. A decade-old average, not a rule; researchers (Field, Nelson-Field) argue it is below the threshold for reliable brand effect anyway.
- **"85% of video is watched without sound"** - a 2016 Digiday report of a few publishers' self-reported numbers; Facebook never confirmed it. Design for sound-off because of muted autoplay, not because of this number.
- **"The average attention span is 8 seconds"** - debunked; no credible primary source. Do not use.

Prefer the well-sourced material instead:

- Nelson-Field/Amplified attention-decay and memory-threshold data.
- Motion's 2026 disclosed-methodology benchmarks.
- Google's ABCD framework: the only opening framework with disclosed large-sample validation, Kantar/Ipsos-measured, associated with up to a 30% lift in short-term sales likelihood.
- The 95:5 rule for B2B.
