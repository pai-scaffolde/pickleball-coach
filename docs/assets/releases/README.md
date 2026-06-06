# Signed releases — drop zone

This directory holds the **signed talent/likeness releases** that back footage
assets in [`docs/assets/exemplar-rights-register.json`](../exemplar-rights-register.json).
Each release is the `license_ref` of exactly one register row. The rights gate in
`tools/sca1869-calibration/calibrate.py` (and `RightsGate.swift`, SCA-1826)
**refuses to run** until the `license_ref` file named by a row exists on disk here.

> Governed by [`docs/RIGHTS_PLAN.md`](../../RIGHTS_PLAN.md), Appendix A. This is an
> engineering gate, not legal advice — route public launches through counsel.

## How to use

1. Record the clip (Option A, self-recorded — RIGHTS_PLAN.md §2).
2. Fill in and physically sign [`TALENT_LIKENESS_RELEASE_TEMPLATE.md`](TALENT_LIKENESS_RELEASE_TEMPLATE.md)
   for every person on camera (parent/guardian if a minor).
3. Scan the signed page to PDF and commit it here at the **exact path** the
   register row's `license_ref` names.
4. Commit the footage binary at the row's `asset_path`.
5. Run the turnkey calibration command in
   [`tools/sca1869-calibration/README.md`](../../../tools/sca1869-calibration/README.md).

## Expected files (currently missing — blocks SCA-1875 / SCA-1869)

| Register id | `license_ref` (commit here) | `asset_path` (footage) | Status |
| --- | --- | --- | --- |
| `fixture-forehand-drive-1rep-v0` | `fixture-forehand-drive-1rep-v0-release.pdf` | `tests/fixtures/fixture-forehand-drive-1rep-v0.mp4` | ⛔ both missing |
| _backhand (record + register first)_ | `fixture-backhand-drive-1rep-v0-release.pdf` | `tests/fixtures/fixture-backhand-drive-1rep-v0.mp4` | ⛔ no clip recorded, no register row |

Filenames must match the register row character-for-character — the gate does a
literal path-exists check relative to repo root.

## Privacy note

These are signed legal documents containing a real person's name and signature.
Keep them to internal-dev surfaces. Do not surface release PDFs in any public or
bundled app surface; they back the asset, they are not themselves an asset.
