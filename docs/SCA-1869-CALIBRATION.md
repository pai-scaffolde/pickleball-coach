# SCA-1869 — v0 generic range calibration from cleared footage

**Status:** calibration pipeline proven end-to-end on cleared footage; calibrated
bands delivered as reviewable proposals. **Not** auto-promoted into the bundled
reference `ranges` — see *Recommendation*.

## Rights basis (board decision)

Footage sourcing for v0 was authorized by the board on 2026-06-06 via Paperclip
confirmation `305810d2` on [SCA-1875](/SCA/issues/SCA-1875) ("Remove guardrails —
I own the legal risk"), scoped by the board as a **wireframe/demo to prove out
Scaffolde**, internal-dev only, not production/public. The two source clips are
registered `usage_scope: internal-dev` in `exemplar-rights-register.json`:

| Stroke | Asset | Source |
|--------|-------|--------|
| Forehand | `yt-forehand-drive-navratil-v0` | YouTube `YHjdSLwZCuU` (Zane Navratil Pickleball) |
| Backhand | `yt-backhand-drive-selkirk-v0` | YouTube `Oh78YGV8iVM` (Selkirk TV) |

Per the issue's Option C posture, **only generic scalar feature bands** are produced.
The raw per-frame Vision pose tracks (which are pro-derived) are gitignored
(`docs/artifacts/sca1869-poses/`), regenerable via `extract_poses.swift`; they are
not committed and do not ship.

## Pipeline (all under `tools/sca1869-calibration/`)

1. **`extract_poses.swift`** — headless Apple Vision (`VNDetectHumanBodyPoseRequest`)
   extractor, time-based sampling, same joint set / normalized space as
   `PoseExtractionService.swift`. Run at 10 Hz over each 90 s clip
   (forehand: 810 frames; backhand: 775 frames).
2. **`segment.py`** — detects drive strokes as arm-extension contact peaks and lays
   a fixed 7-phase template over each rep window, pooling frames across reps
   (forehand: 14 reps / 169 labeled frames; backhand: 15 reps / 195 frames).
   *Approximate*: phase boundaries are template-based, not hand-annotated.
3. **`calibrate.py`** — robust p15–p85 per-phase bands on ComparisonEngine-parity
   features, padded and floored to generic widths. Rights-gated (passed for both
   registered assets). Output flagged `machine_proposed_pending_coach_review`.

Artifacts: `docs/artifacts/SCA-1869-{forehand,backhand}-calibration-report.json`,
proposed calibrated references `docs/artifacts/SCA-1869-reference_{forehand,backhand}_calibrated_v0.json`,
demonstration comparison `docs/artifacts/SCA-1869-comparison-on-calibrated-forehand.json`.

## Result — footage corroborates centers, but widths are noisy

The real pro footage **corroborates the existing hand-authored / literature band
centers**. Most telling: forehand **contact elbow median = 155°**, squarely inside
the literature band `[150,175]` that the [SCA-1861](/SCA/issues/SCA-1861)
`mechanicsThresholds` cite from USA Pickleball / biomechanics sources. Across all
forehand phase-features, **10 / 17 calibrated medians fall inside the prior band.**

But the derived *band widths* are inflated by segmentation noise (unscripted
instructional video, template phase boundaries). The demonstration comparison
against the calibrated reference scores **100/100** — i.e. the wide bands are too
lenient to discriminate good vs poor mechanics. The 7/17 medians that land outside
prior bands track phase-template misalignment (e.g. contact `wrist_height` median
−0.75 vs prior `[-0.45, 0.10]`), not a real disagreement about good technique.

## Conflict: do not clobber the SCA-1861 literature bands

The bundled reference's `phases[].ranges` are **shared** by ComparisonEngine
(SCA-1824) and MechanicsScoringEngine (SCA-1861), and SCA-1861 sourced them from
coaching literature with citations (rights-clean Option C). Overwriting them with
the rougher footage bands would degrade mechanics scoring. So this work does **not**
modify the bundled reference `ranges` or `mechanicsThresholds`.

## Recommendation (coach review)

1. Treat the footage calibration as **validation** of the literature bands' centers
   (it corroborates them), not as a replacement.
2. Before any promotion, tighten phase segmentation (hand-annotate a few clean reps,
   or add a real phase detector) so band *widths* are meaningful.
3. A coach should review the per-feature report and decide, per feature, whether to
   nudge any band — keeping the tighter literature widths. Tracked as a follow-up.
