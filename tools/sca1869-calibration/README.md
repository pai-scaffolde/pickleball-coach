# SCA-1869 — v0 generic range calibration

Calibrates the v0 **generic** feature ranges (`idealMin`/`idealMax` per feature
per phase) for `reference_forehand_drive_v0.json` and
`reference_backhand_drive_v0.json` from **cleared footage**, replacing the
hand-authored bands. Follow-up to SCA-1864; unblocked by the SCA-1860 Vision
pose pipeline.

## What this does

`calibrate.py` consumes a pose-extraction artifact (the `jointSamples` contract
emitted by `PoseExtractionService` / `PoseCaptureService`) plus a reference
exemplar, and rebuilds each phase's `ranges` block from the observed footage.

- **Feature geometry is imported from the SCA-1824 comparison reference port**
  (`tools/sca1824-comparison-harness/reference_port.py`), which mirrors
  `ComparisonEngine.swift` line-for-line. Bands therefore mean exactly what the
  app scores against — calibration and comparison share one geometry.
- **Bands are derived, then generically widened.** For each phase×feature we
  take the robust spread of observed values (p15–p85 when ≥4 frames, else the
  median), pad it, then floor it to a generic minimum width:
  - angle features (deg): pad ±8°, min total width 30°, clamped to [0,180]
  - ratio features (rel-torso): pad ±0.10, min total width 0.40
  This keeps v0 **generic** (Option C): one cleared rep of one person can never
  produce a person-tight band. Widths are coach-reviewable.
- **Phases with no measurable footage carry forward the hand-authored band**
  (`source: hand_authored_carryforward`).
- Output is marked `review_status: machine_proposed_pending_coach_review` — the
  project ships coach-reviewed rules, not AI guesses (cf. SCA-1823).

## Rights gate (Option C / cleared-public posture)

Calibration mirrors `RightsGate.swift` (SCA-1826). A real run **refuses** unless
the `--rights-id` row in `exemplar-rights-register.json`:

1. has `rights_status` ∈ {`cleared-internal`, `cleared-public`}, **and**
2. has a `license_ref` release doc that **exists on disk**, **and**
3. its `asset_path` footage binary **exists on disk**.

`--dry-run` bypasses the gate for **methodology validation only** and stamps the
output `shippable: false`. Dry-run output must never be committed as the
shipped reference.

## Turnkey command (run when cleared footage lands)

```sh
# 1. Extract poses from the cleared clip (Vision pipeline, SCA-1860):
#    produces a jointSamples artifact, e.g. forehand-cleared-poses.json
# 2. Calibrate (rights gate enforced):
python3 tools/sca1869-calibration/calibrate.py \
  --poses   <forehand-cleared-poses.json> \
  --reference PickleballCoach/PickleballCoach/Resources/reference_forehand_drive_v0.json \
  --out       PickleballCoach/PickleballCoach/Resources/reference_forehand_drive_v0.json \
  --report    docs/artifacts/SCA-1869-forehand-calibration-report.json \
  --rights-id fixture-forehand-drive-1rep-v0
# 3. Coach-review the report, then re-run the comparison harness and update
#    docs/artifacts/SCA-1824-comparison-artifact.json + the spec evidence block.
```

## Status / blocker

The engine is built and verified (rights gate refuses uncleared footage; dry-run
produces valid, schema-parity output). **It is blocked on the cleared footage
asset itself**, which is not in the repo:

- **Forehand** — `fixture-forehand-drive-1rep-v0` is registered `cleared-internal`,
  but neither the footage binary (`tests/fixtures/fixture-forehand-drive-1rep-v0.mp4`)
  nor its signed release (`docs/assets/releases/fixture-forehand-drive-1rep-v0-release.pdf`)
  is committed. Both must land before calibration can run.
- **Backhand** — no cleared backhand footage exists. Requires an Option A
  self-recorded clip with a signed release (RIGHTS_PLAN.md Appendix A),
  registered in the rights register, before calibration.

The two pose artifacts currently in the repo (`SCA-1819-pose-spike-artifact.json`
and the hand-authored references) are **synthetic** — not footage-derived — so
they cannot produce shippable calibrated bands.
