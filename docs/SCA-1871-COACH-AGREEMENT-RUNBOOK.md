# SCA-1871 — Gate 4: Coach Agreement Review Session (Runbook)

**Gate (from [SCA-1826 Gates Spec](/SCA/issues/SCA-1826#document-gates-spec)):**
A qualified pickleball coach agrees with the app's top recommendation on
**70–80%** of accepted beta clips.

**Pass criterion:** ≥ 21 / 30 reviewable clips (70%) rated `agree`.

> **Status: DEMO RUN COMPLETE (2026-06-06, board-authorized).** Gary directed:
> *"It's a demo. ballpark generation is fine. Spin up an agent to act like a
> coach."* A full demo run was executed end-to-end and is recorded below. For a
> **real launch gate**, prerequisites still hold: a real beta corpus + a
> qualified *human* coach; the human-coach prep below remains the turnkey path.

## Demo run result (board-authorized 2026-06-06)

30 ballpark forehand clips were synthesized; the **real** `RuleBasedFeedbackEngine`
was compiled (`swiftc`) and run on each (`tools/sca1871-coach-agreement/main.swift`),
and an independent **coach agent** (USAPA-coach persona, Opus) rated each top
recommendation. Full measure → fail-action → re-measure loop:

| Pass | Agreement | Result | Notes |
|------|-----------|--------|-------|
| v1 | 18/30 = 60% | **FAIL** | Engine headlined borderline (1–2° / few-%) values as the #1 fix. Archived: `docs/artifacts/SCA-1871-coach-review-log-v1-fail.json`. |
| v2 | 18/21 = 86% | **PASS** | Fail-action applied: coach-guided **dead-band** widened improvement thresholds in `FeedbackRuleSet.swift` (stance 0.95/1.35, knee 138/172, hip-sep 18, follow-through −0.10). 9 borderline clips now correctly raise no headline (`n/a`). |

Result log: `docs/assets/coach-review-log.json` (v2). Reproduce: build the harness
(see below), run `gen_top_recs`, then `coach_agreement.py score`.

> **Ratification pending:** the `FeedbackRuleSet.swift` dead-band is a change to
> coach-authored content. Before it ships in production, a **human coach** should
> ratify the widened thresholds. Owner: Gary / coach. Revert the rule diff if
> demo-only is preferred.

### Build the demo harness
```
swiftc -O \
  PickleballCoach/PickleballCoach/Models/PoseAnalysisResult.swift \
  PickleballCoach/PickleballCoach/Models/MechanicsObservation.swift \
  PickleballCoach/PickleballCoach/Models/FeedbackRule.swift \
  PickleballCoach/PickleballCoach/Models/FeedbackRuleSet.swift \
  PickleballCoach/PickleballCoach/Services/FeedbackEngine.swift \
  tools/sca1871-coach-agreement/main.swift \
  -o tools/sca1871-coach-agreement/gen_top_recs
```

---

> For a **real launch gate** (not the demo), the original requirements hold:
> (1) a real beta corpus of 30 accepted clips and (2) a qualified *human*
> pickleball coach. **No agent may fabricate a real-gate coach verdict** — the
> independent human review is the entire point of the production gate.

## Prerequisites to unblock

| # | Prerequisite | Owner | Done when |
|---|--------------|-------|-----------|
| 1 | 30 accepted beta clips (each must have `CaptureQualityGate` passed) collected with their pose analyses + reviewable footage | Product / beta program (Gary) | 30 clips + footage paths available |
| 2 | A qualified pickleball coach scheduled for an independent review session | Product (Gary) | Coach booked |

## Session procedure

1. **Select 30 accepted clips.** Each must have passed `CaptureQualityGate`.
   Record `clipId`, `footagePath`, and `captureGatePassed: true` in the log.
2. **Compute each clip's top recommendation.** Run
   `RuleBasedFeedbackEngine(strokeType: "forehand_drive").generateFeedback(from:)`
   on the clip's `PoseAnalysisResult`. The result is one `ClipFeedback` per
   phase, **already sorted ascending by `phaseIndex`**.
   - **Top recommendation** = the **first** `ClipFeedback` whose
     `primaryObservation.severity == .improvement`.
   - If **no** card is `.improvement` (all `strength` / `neutral`, or
     insufficient data), the clip has **no** top recommendation → record
     `coachVerdict: "n/a"` (excluded from the denominator).
   - Populate `topRecommendation.{ruleId, phaseIndex, phaseTitle, observation,
     citedMetricName, citedMetricValue}` from `primaryObservation`.
3. **Independent coach review.** For each clip, the coach watches the footage
   **without** seeing the app's pick first, forms their own primary fix, then
   compares to the app's top recommendation and records:
   - `agree` — app's top recommendation is the right primary fix.
   - `disagree` — wrong fix, false positive, or a more important issue was missed.
   - `coachNotes` — free text (required on every `disagree`).
4. **Log** to `docs/assets/coach-review-log.json` (schema/template already in repo).
5. **Score** deterministically:
   ```
   python3 tools/sca1871-coach-agreement/coach_agreement.py score
   ```
   Exit codes: `0` PASS · `1` FAIL · `2` invalid/incomplete · `3` pending.

## Fail action (< 70% agreement)

The scorer prints the **lowest-agreement rule IDs** (ranked by disagreement
count). With the coach, revise the offending thresholds or observation
templates in
`PickleballCoach/PickleballCoach/Models/FeedbackRuleSet.swift`, then re-run the
affected clips and re-score. Current `forehand_drive` rule IDs:

| Phase | Rule IDs |
|-------|----------|
| ph1 stance | `ph1.stance.good`, `ph1.stance.narrow`, `ph1.stance.wide` |
| ph3 knee   | `ph3.knee.good`, `ph3.knee.upright`, `ph3.knee.deep` |
| ph5 hip turn | `ph5.hip_turn.good`, `ph5.hip_turn.low`, `ph5.hip_turn.high` |
| ph8 follow-through | `ph8.follow_through.good`, `ph8.follow_through.low` |

## Artifacts in this repo

- `docs/assets/coach-review-log.json` — 30-slot template / result log (named by the issue).
- `tools/sca1871-coach-agreement/coach_agreement.py` — `init` (regenerate template) + `score` (validate & compute). Pass/fail boundary verified at 21/30 = 70%.
- This runbook.
