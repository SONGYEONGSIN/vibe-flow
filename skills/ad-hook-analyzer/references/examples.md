# Worked Examples

Fictional products and numbers-free banding throughout - these show the output shape and the reasoning, not real benchmark data.

## Scorecard Shape

Every scorecard follows this field-by-field shape, filled in per batch:

```
HOOK BATCH SCORECARD - <product/offer>, <platform + exact placement>, <date>
batch        : <N> candidates | input: <script|transcript|storyboard|shot list|cut description>
hook window  : first <N>s | audience: <cold|warm> <B2B|B2C>
dashboard    : hook rate = <numerator> / <denominator> (from Interview)

gates
  <candidate>: sound-off <pass|FAIL> | promise-payoff <pass|FAIL> | qualification <pass|FAIL> | variation <pass|FAIL - merged with X>

bands (gate-passing candidates only; strong/adequate/weak)
  <candidate>: time-to-signal <band> | sound-off <band> | qualification <band> | specificity <band>
               | brand timing <band - objective it serves> | continuity <band> | placement fit <band>

ranking (pairwise, valid within this batch only - not a performance prediction)
  1. <candidate> - <why it won its head-to-heads>
  2. <candidate> - ...
  raise-the-rank
  <candidate>: <one concrete change that would move it up>
  rungs deleted: <rung> - <constraint that removed it from this batch's menu>

shipping check : <N> openings clear all gates and differ on concept - <meets|BELOW> the 3-opening floor
calibration    : after launch, compare this predicted order against measured hook-rate order
                 (same definition, platform, placement); log rank agreement
```

## Example 1 - B2C batch, worked in full

- Product: a $79 dishwasher-safe cast-iron skillet, DTC brand.
- Platform: Meta, feed placements, cold prospecting, B2C.
- Input: scripts with first-frame descriptions.
- Dashboard hook rate: `3-second video plays ÷ impressions` (confirmed in Interview).
- Rest of ad (all four candidates share it): 20 seconds of dishwasher demo, seasoning-free cooking shots, offer card with 30-day guarantee.

The four candidates' openings (first 3 seconds):

- **A "Offer open"**: skillet placed into a running dishwasher; on-screen text "Cast iron. Dishwasher safe. $79."
- **B "Kitchen chaos"**: creator theatrically shoves an entire pot rack off a counter, crash sound carries the joke; text "I'm done with all of it."
- **C "Scrub confession"**: close-up of hands scrubbing a rusted skillet; text "Love cast iron. Hate babying it?"
- **D "Scrub confession v2"**: same rusted-skillet footage as C; new text line "Cast iron shouldn't be a chore."

```
HOOK BATCH SCORECARD - $79 dishwasher-safe cast-iron skillet, Meta feed, 2026-08-26
batch        : 4 candidates | input: scripts with first-frame descriptions
hook window  : first 3s | audience: cold B2C
dashboard    : hook rate = 3-second video plays / impressions

gates
  A: sound-off pass | promise-payoff pass | qualification pass | variation pass
  B: sound-off FAIL (joke lives in the crash audio; muted, it reads as clumsiness)
     | promise-payoff pass | qualification FAIL (stops everyone; nothing signals cookware buyer)
     | variation pass
  C: sound-off pass | promise-payoff pass | qualification pass | variation pass
  D: sound-off pass | promise-payoff pass | qualification pass
     | variation FAIL - merged with C (identical visual; wording-only sibling is not a test cell)

bands (gate-passing candidates only; strong/adequate/weak)
  A: time-to-signal strong | sound-off strong | qualification adequate | specificity strong
     | brand timing strong - DR objective, product-as-brand-cue, no logo card
     | continuity strong | placement fit strong
  C: time-to-signal strong | sound-off strong | qualification strong | specificity adequate
     | brand timing adequate - brand only implied until the demo
     | continuity strong | placement fit strong

ranking (pairwise, valid within this batch only - not a performance prediction)
  1. A - vs C: both signal fast and hold continuity; A wins on specificity (a checkable
     claim plus the price) and on being the offer in miniature. Motion's 2026 data is a
     tiebreaker, not proof: offer-only hooks had the highest hit rate in its BFCM-window
     dataset.
  2. C - qualifies the cast-iron owner more sharply than A, but its promise is abstract
     until the demo arrives.
  3. B - cannot rank top on two gate failures regardless of its scroll-stopping power.
  raise-the-rank (cheapest rung that removes the failure)
  A: [rung 1, text rewrite] name the pain A assumes ("no seasoning, no rust") in the text
     to close the qualification gap with C.
  C: [rung 1, text rewrite] add one checkable element (the price, or "survives 1,000
     cycles") to the text - substantiate the cycle claim before it runs.
  D: [rung 3, re-cut] open on the rust rather than the scrubbing, from footage already
     shot - that is the visual difference the variation gate wants; drop D otherwise.
  B: [rung 5, rebuild] make the chaos read muted AND implicate cookware in frame 1 - two
     gate failures, so this is a new candidate re-entering the gates, not a fix.

shipping check : 2 openings clear all gates and differ on concept - BELOW the 3-opening
                 floor. Do not ship as-is: revise B and D (or add a new concept) first.
calibration    : after launch, compare this order (A, C, +revisions) against measured
                 hook-rate order, same definition and placement; log rank agreement.
```

## Example 2 - B2B contrast, condensed

- Product: payroll-compliance platform for companies employing across borders.
- Platform: LinkedIn feed, cold, B2B.
- Objective: stated as memory/pipeline, not immediate signup.

Two candidates:

- **P "Role call-out"**: static-feeling shot of a payroll dashboard mid-error, brand's distinctive colour frame; text "Running payroll in 3 countries?"
- **Q "Big number tease"**: dramatic stock footage of a shredded contract; text "The $2M mistake nobody talks about."

Both pass sound-off, continuity, and variation. Banding highlights - and where B2B diverges from Example 1:

- **Identical logic to B2C**: time-to-signal (both land inside 3s: strong), sound-off (both text-carried: strong), continuity (both set up the compliance story: strong).
- **Divergent - qualification**: P qualifies by role and situation, exactly what the 95:5 logic wants when ~95% of buyers are out-of-market: strong. Q's curiosity is universal - finance-adjacent viewers of every kind stay: weak, and on a cold B2B budget that is close to a gate question.
- **Divergent - brand timing**: with a memory objective, P's early distinctive-asset branding bands strong; Q holds all branding to the end card - weak against a 17-point brand-linkage drop reported by TikTok for end-loaded branding (asserted figure, but the direction matches the memory objective).
- **Metric caution on the scorecard**: LinkedIn's 2-second/50% view definition is a weak signal; calibrate this batch on completion and watch time, not view rate.

Pairwise: P over Q. Raise-the-rank for Q, at rung 3 (re-cut) rather than rung 1: naming the role in the text is a minutes-long fix, but Q's stock footage is the structural fault, so the rung-1 rewrite alone would not clear it. Replacing that footage with the branded dashboard converges Q toward P, so it must then pass the real-variation gate against P.

## Example 3 - negative example: the analysis done wrong

The same Example 1 batch, analysed badly:

> "Candidate B is the clear winner - Hook Score: 9.1/10. Its pattern interrupt is the
> strongest scroll-stopper in the batch and should achieve a 40%+ hook rate, well above
> the 30% benchmark. A: 7.4/10. C: 7.1/10. D: 7.0/10. Recommend putting most of the
> test budget behind B."

Why every part of this is wrong:

1. **Fabricated precision.** "9.1/10" and "7.4 vs 7.1" claim resolution no pre-launch judgment has. The evidence behind this skill (near-zero-to-negative hook-rate/ROAS correlation, poor inter-rater reliability) is precisely why decimals are banned - two competent analysts would not reproduce these numbers.
2. **Gate override by cleverness.** B failed sound-off and qualification. A gate-failer cannot rank top no matter how arresting it is; ranking it first funds the documented failure mode where the scroll stops and nothing converts.
3. **Attention treated as performance.** "Should achieve a 40%+ hook rate" predicts an absolute in-market number from a script, then treats that number as success. Hook rate measures attention, not sales - a high one on an unqualified audience is how a 43%-hook-rate ad ends up with mediocre ROAS.
4. **A benchmark imported blind.** "The 30% benchmark" arrives with no denominator, placement, traffic temperature, or source - exactly the kind of directional folklore the calibration step exists to replace with the account's own history.
5. **D scored as a fourth cell.** It shares C's visual; the platform will not treat it as a distinct variation, so its "7.0" describes a test cell that does not exist.

## Common Failure Modes

| Trap                                                                      | Why it burns                                                                                  | Fix                                                                                                        |
| ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Emitting a numeric or composite hook score                                | False precision the evidence contradicts; invites cross-batch comparison                      | Bands per dimension, pairwise rank within batch only                                                       |
| Ranking or weighting the seven scoring dimensions                         | Nothing in the evidence orders them; a printed weighting directs budget on invented precision | Leave them unranked by design; rank candidates pairwise, and re-weight only from the account's own winners |
| Picking the most thorough revision instead of the cheapest one that works | A reshoot spends a production cycle to fix what a text rewrite fixes in minutes               | Take the lowest rung of Raising a Rank that removes the failure                                            |
| Ranking a clever gate-failer top "because it will stop everyone"          | Attention without qualification is the documented high-hook-rate/no-ROAS failure              | Gates are absolute; a gate-failer cannot rank top                                                          |
| Scoring candidates against different time windows                         | A 3s feed open vs an 8s in-stream open is not one comparison                                  | Normalise to the placement's window first (workflow step 2)                                                |
| Treating wording-only siblings as separate cells                          | The platform collapses them; the "test" tests nothing                                         | Merge at the variation gate; demand a visual difference                                                    |
| Comparing hook rates across platforms or dashboards                       | Different denominators produce different numbers for the same ad                              | Lock one definition per account; calibrate only within it                                                  |
| Treating the ranking as a performance prediction                          | Hook metrics correlate near zero (or negative) with ROAS                                      | Frame every output as budget shortlisting; the market decides                                              |
| Keeping the generic rubric after calibration fails                        | The account's winners are telling you the weighting is wrong                                  | Re-derive weights from the account's own past winners                                                      |
| Scoring a bumper/non-skippable like a feed hook                           | The view is forced; there is no scroll to stop                                                | Score continuity, branding, qualification only; say so                                                     |
