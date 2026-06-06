# SCA-1884 — v0 footage segmentation tightening + band-promotion decision

**Status:** segmentation tightened and re-calibrated; band promotion **decided —
do not promote footage widths** (board ratification requested). No shipped
artifact (`reference_*_drive_v0.json`, `mechanicsThresholds`) is modified.

Follow-up to [SCA-1869](/SCA/issues/SCA-1869), which proved the calibration
pipeline end-to-end and delivered per-stroke band proposals but **did not**
promote them, because the band *widths* were inflated by template segmentation
noise (demo comparison scored a non-discriminating 100/100). SCA-1884's job:
tighten segmentation so widths are meaningful, then decide promotion.

## What was done (issue step 1 — tighten segmentation)

`tools/sca1869-calibration/segment.py` (v1) detected each drive's contact peak
correctly but then laid a **fixed time-fraction template** over the rep window —
blind time slices that drift relative to the actual stroke, pooling adjacent-phase
frames together and inflating spread.

New: `tools/sca1869-calibration/segment_v2.py` keeps the proven contact-peak
detector but **anchors phase boundaries to per-rep kinematic landmarks** derived
from arm-extension (ComparisonEngine geometry parity):

- contact peak `tc` = local MAX of arm extension (fullest reach at strike)
- takeback trough `tb` = MIN of extension in the pre-contact window (racket back)
- follow-through trough `te` = MIN of extension in the post-contact window

Phases are placed relative to those landmarks instead of blind fractions
(takeback ends at the measured trough; contact straddles the measured peak).

Re-segmented + re-calibrated both strokes (rights gate passed for both registered
assets). Artifacts under `docs/artifacts/sca1884/`.

## Result — tightening hits a footage-variance ceiling, not a segmentation ceiling

**1. Landmark anchoring only moved inflation around.** Total band-width sum
dropped modestly (forehand 552.5 → 502.2; backhand 369.4 → 361.7), but the
distribution shifted: low-value phases tightened (e.g. forehand takeback elbow
−50°, but that pool collapses to ~2 frames — a degenerate "tightening"), while
the coaching-critical **contact** and **turn** phases actually *widened*
(forehand contact elbow +19°, turn elbow +20°). Net: not a promotion-grade win.

**2. The contact phase cannot be tightened below the literature width — even at
the theoretical limit.** Probing the tightest kinematically-homogeneous contact
pool (frames at ≥ 0.99 × each rep's peak extension — the literal instant of
fullest reach):

| Stroke | Contact-pool elbow p15–p85 | Spread | Median | Literature band |
|--------|----------------------------|--------|--------|-----------------|
| Forehand | [124°, 173°] | **49°** | 154° | `[150,175]` (width 25°) |
| Backhand | [154°, 177°] | **23°** | 165° | (prior width ~35°) |

The forehand contact elbow median (154°) sits **squarely inside** the literature
band `[150,175]` — strong corroboration of the band *center*. But the *spread*
(49°) is ~2× the literature width and does not shrink with tighter pooling. That
is irreducible variance in **single-source, unscripted instructional footage**:
camera-angle / frontality sensitivity of the 2D elbow feature, mixed drive
demonstrations, and the fact that knee/hip-driven phases (load, ready, recovery)
cannot be timed from an arm-extension scalar at all.

**3. The tightened reference still does not discriminate.** Re-running the demo
comparison (`SCA-1819` user clip vs the v2-calibrated forehand reference) still
scores **100/100** across all phases — the v2 bands are still too lenient.
`docs/artifacts/sca1884/SCA-1884-comparison-on-v2-forehand.json`.

## Decision — do not promote footage-derived widths

The width inflation is **not** primarily segmentation noise (which we could fix);
it is irreducible variance in the v0 footage corpus. Better segmentation
confirms rather than removes it. Therefore:

1. **Keep** the [SCA-1861](/SCA/issues/SCA-1861) cited literature bands
   (`reference_*_drive_v0.json` `phases[].ranges`, `mechanicsThresholds`). They
   are shared with ComparisonEngine (SCA-1824) and MechanicsScoringEngine;
   overwriting them with footage widths would degrade mechanics scoring.
2. **Use the footage as validation of band *centers*** — which it corroborates
   (forehand contact elbow median 154° ∈ `[150,175]`; backhand contact elbow
   median 165° near prior). No center needs nudging on this evidence.
3. **No `reference_*` or comparison-artifact changes.** SCA-1869's posture
   stands, now backed by quantitative tightening evidence rather than a single
   100/100 observation.

### What would unblock genuine width promotion (out of scope, future)

- Multi-rep, **scripted** drive footage (or hand-annotated clean reps) — removes
  talking-head / mixed-drive contamination.
- A **multi-signal** phase detector (knee angle → load, hip rotation → turn,
  arm extension → contact) instead of a 1D arm-extension scalar.
- Multiple cleared sources per stroke to average out single-demonstrator and
  camera-frontality bias.

## Artifacts

- `tools/sca1869-calibration/segment_v2.py` — landmark-anchored segmenter.
- `docs/artifacts/sca1884/forehand-navratil-labeled-v2.json`,
  `backhand-selkirk-labeled-v2.json` — v2 segmentations.
- `docs/artifacts/sca1884/reference_{forehand,backhand}_calibrated_v2.json` —
  v2 calibrated references (proposals only; **not** bundled).
- `docs/artifacts/sca1884/SCA-1884-{forehand,backhand}-calibration-report.json` —
  per-feature v1→v2 evidence.
- `docs/artifacts/sca1884/SCA-1884-comparison-on-v2-forehand.json` — still 100/100.
