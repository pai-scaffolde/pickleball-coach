# SCA-1872 — Gate 6: User Drill Recall Survey (Runbook)

**Gate (from [SCA-1826 Gates Spec](/SCA/issues/SCA-1826#document-gates-spec)):**
After viewing feedback, beta users can correctly identify the **one thing** the
app told them to practice.

**Pass criterion:** ≥ 16 / 20 reviewable users (80%) correctly recall their top drill.

> **Status: two halves.**
> 1. **Structural / engineering prerequisite — DONE (this issue).** The spec
>    requires the `drill` surfaced *prominently* ("one card = one drill"). The
>    feedback card now renders the drill as a bold **"Practice this"** CTA block
>    (headline-weight drill text, accent-tinted) and marks the top card with a
>    **"The one thing to practice today"** banner + accent border. See
>    `ClipFeedbackView.swift`. Build verified (`xcodebuild … BUILD SUCCEEDED`).
> 2. **Process measurement — BLOCKED.** Requires a real cohort of 20 beta users
>    who have viewed feedback and a human grader to run the exit question. No
>    beta cohort exists yet. The artifacts below make the survey turnkey the
>    moment that cohort exists. **No agent may fabricate user answers or recall
>    verdicts** — the independent human recall measurement is the entire point.

## Prerequisites to unblock the measurement

| # | Prerequisite | Owner | Done when |
|---|--------------|-------|-----------|
| 1 | 20 beta users who have completed a session and viewed the feedback screen | Product / beta program (Gary) | 20 sessions with viewed feedback |
| 2 | A human grader to ask the exit question and judge recall per user | Product (Gary) | Grader assigned for the cohort |

The 20-user cohort is shared with the other process gates (G1 capture success
[SCA-1870](/SCA/issues/SCA-1870), G4 coach agreement [SCA-1871](/SCA/issues/SCA-1871));
recall can be measured in the same beta sessions.

## Survey procedure

1. **One user, one completed session.** The user finishes analysis and views the
   feedback cards in `ClipFeedbackView`.
2. **Compute their top drill.** The top recommendation = the **first**
   `ClipFeedback` (ascending `phaseIndex`) whose
   `primaryObservation.severity == .improvement`; its `primaryObservation.drill`
   is the "one thing to practice." Record it as `topDrill`.
   - If **no** card is `.improvement`, the user had no drill → `recallVerdict: "n/a"`
     (excluded from the denominator).
3. **Ask the exit question verbatim** (do not prompt toward the answer):
   > "What one thing did the app tell you to practice today?"
   Record the verbatim reply as `userAnswer`.
4. **Grade recall.** The grader marks:
   - `understood` — the answer matches the `topDrill` (same drill / its essence).
   - `not_understood` — recalled the wrong thing or could not recall.
   - `graderNotes` — free text (required on every `not_understood`).
5. **Log** to `docs/assets/drill-recall-log.json` (schema/template already in repo).
6. **Score** deterministically:
   ```
   python3 tools/sca1872-drill-recall/drill_recall.py score --suggest
   ```
   `--suggest` prints a token-overlap hint (fraction of the drill's key words
   present in the answer) for ungraded rows — an aid only; the grader decides.
   Exit codes: `0` PASS · `1` FAIL · `2` invalid/incomplete · `3` pending.

## Fail action (< 80% recall)

Improve drill visibility in `ClipFeedbackView.swift` further — the first pass
(done in this issue) added the **"Practice this"** CTA, headline-weight drill
text, and the top-card banner/border. If recall is still short, consider:
moving the drill above the observation, a larger/branded CTA button, haptic or
animated emphasis on the top card, or a single drill-only summary screen. Then
re-survey and re-score.

## Artifacts in this repo

- `PickleballCoach/PickleballCoach/Views/ClipFeedbackView.swift` — prominent
  drill CTA + top-recommendation emphasis (structural prerequisite, SCA-1872).
- `docs/assets/drill-recall-log.json` — 20-slot template / result log.
- `tools/sca1872-drill-recall/drill_recall.py` — `init` (regenerate template) +
  `score` (validate & compute). Pass/fail boundary verified at 16/20 = 80%.
- This runbook.
