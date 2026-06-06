#!/usr/bin/env python3
"""SCA-1869 — calibrate v0 generic feature ranges from cleared footage.

Turns a pose-extraction artifact (PoseExtractionService / PoseCaptureService
output: ``jointSamples`` with per-frame ``phase`` + ``joints``) into calibrated
``idealMin``/``idealMax`` bands per feature per phase, replacing the
hand-authored bands in a ``reference_*_drive_v0.json`` exemplar.

Design contract (why this exists and what it must NOT do):

  * Option C / cleared-public genericity. The output is a *generic* v0 band
    informed by calibration — NOT a person-specific track. We never copy an
    observed value verbatim into a tight band; every band is widened to a
    documented generic minimum width so one rep of one person cannot produce
    bands that only that person can satisfy. No identifiable pose track is
    embedded; only scalar feature bands are emitted.

  * Rights gate at the calibration boundary. Calibration MUST run only on
    footage whose row in the exemplar-rights-register has a cleared status AND
    a present ``license_ref`` release doc on disk. This mirrors RightsGate.swift
    (SCA-1826): no calibration from uncleared or release-less footage. Pass
    ``--rights-id <register-id>``; the tool refuses otherwise. ``--dry-run``
    bypasses the gate for METHODOLOGY validation only and stamps the output as
    a non-shippable dry run.

  * Geometry parity. Feature math is imported from the SCA-1824 comparison
    reference port, which is a line-for-line mirror of ComparisonEngine.swift.
    Calibration and comparison therefore compute identical features — a band
    calibrated here means the same thing the app scores against.

Usage:
    calibrate.py --poses POSES.json --reference REF.json --out OUT.json \\
        (--rights-id REGISTER_ID | --dry-run) [--register PATH]

Exit non-zero (and writes nothing) if the rights gate fails.
"""
import argparse
import importlib.util
import json
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
PORT_PATH = os.path.join(REPO_ROOT, "tools", "sca1824-comparison-harness", "reference_port.py")
DEFAULT_REGISTER = os.path.join(
    REPO_ROOT, "PickleballCoach", "PickleballCoach", "Resources", "exemplar-rights-register.json"
)


def _load_port():
    """Import the comparison reference port as a module for feature parity."""
    spec = importlib.util.spec_from_file_location("reference_port", PORT_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


PORT = _load_port()

# Per-feature-type calibration policy. These widths keep v0 bands GENERIC
# (Option C): the band is the observed robust spread, padded, then floored to a
# minimum total width so a single cleared rep cannot yield a person-tight band.
# Final widths are coach-reviewable (see tools/sca1869-calibration/README.md).
ANGLE_FEATURES = {
    "right_elbow_angle_deg",
    "right_knee_angle_deg",
    "hip_shoulder_separation_deg",
}
RATIO_FEATURES = {
    "wrist_height_rel_torso",
    "arm_extension_rel_torso",
}
# (percentile_pad, min_total_width, clamp_lo, clamp_hi, round_ndigits)
POLICY = {
    "angle": dict(pad=8.0, min_width=30.0, clamp=(0.0, 180.0), ndigits=0),
    "ratio": dict(pad=0.10, min_width=0.40, clamp=(None, None), ndigits=2),
}
# Use percentiles (not min/max) so a single noisy frame can't blow out a band.
LO_PCT, HI_PCT = 15, 85
MIN_SAMPLES_FOR_PERCENTILE = 4


def feature_kind(key):
    if key in ANGLE_FEATURES:
        return "angle"
    if key in RATIO_FEATURES:
        return "ratio"
    return None


def percentile(sorted_vals, pct):
    """Linear-interpolation percentile on a pre-sorted list."""
    if not sorted_vals:
        return None
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    rank = (pct / 100.0) * (len(sorted_vals) - 1)
    lo = int(rank)
    frac = rank - lo
    if lo + 1 >= len(sorted_vals):
        return sorted_vals[-1]
    return sorted_vals[lo] + frac * (sorted_vals[lo + 1] - sorted_vals[lo])


def collect_values(key, poses):
    """All valid feature values for `key` across `poses` (uses port geometry)."""
    return [v for v in (PORT.feature(key, p["joints"]) for p in poses) if v is not None]


def calibrate_band(key, poses, prior):
    """Derive a generic calibrated band for one (phase, feature).

    Returns (band_dict, evidence_dict). Falls back to the hand-authored prior
    band when there is no measurable footage for this feature in this phase.
    """
    kind = feature_kind(key)
    vals = collect_values(key, poses)
    if kind is None:
        return dict(prior), {"source": "carryforward_unknown_feature", "nSamples": len(vals)}
    if not vals:
        return dict(prior), {"source": "hand_authored_carryforward", "nSamples": 0,
                             "reason": "no measurable frames for this feature in this phase"}

    pol = POLICY[kind]
    vals_sorted = sorted(vals)
    median = statistics.median(vals_sorted)
    if len(vals_sorted) >= MIN_SAMPLES_FOR_PERCENTILE:
        lo_raw = percentile(vals_sorted, LO_PCT)
        hi_raw = percentile(vals_sorted, HI_PCT)
        basis = f"p{LO_PCT}-p{HI_PCT}"
    else:
        lo_raw = hi_raw = median
        basis = "median (too few frames for percentiles)"

    lo = lo_raw - pol["pad"]
    hi = hi_raw + pol["pad"]
    # Floor to generic minimum width, centered on the observed center.
    if hi - lo < pol["min_width"]:
        center = (lo + hi) / 2.0
        lo = center - pol["min_width"] / 2.0
        hi = center + pol["min_width"] / 2.0
    clo, chi = pol["clamp"]
    if clo is not None:
        lo = max(lo, clo)
    if chi is not None:
        hi = min(hi, chi)
    nd = pol["ndigits"]
    lo_r = round(lo, nd) if nd else int(round(lo))
    hi_r = round(hi, nd) if nd else int(round(hi))
    band = {"idealMin": lo_r, "idealMax": hi_r}
    evidence = {
        "source": "calibrated", "nSamples": len(vals_sorted),
        "observedMedian": round(median, 3), "basis": basis,
        "priorMin": prior.get("idealMin"), "priorMax": prior.get("idealMax"),
    }
    return band, evidence


def check_rights(register_path, rights_id):
    """Enforce the calibration rights gate. Returns the asset row or raises."""
    with open(register_path) as f:
        reg = json.load(f)
    rows = {a["id"]: a for a in reg.get("assets", [])}
    asset = rows.get(rights_id)
    if asset is None:
        raise SystemExit(f"RIGHTS GATE: no register row for id '{rights_id}' in {register_path}")
    status = asset.get("rights_status")
    if status not in ("cleared-internal", "cleared-public"):
        raise SystemExit(
            f"RIGHTS GATE: asset '{rights_id}' has rights_status='{status}'. "
            "Calibration requires cleared-internal or cleared-public.")
    license_ref = asset.get("license_ref")
    if not license_ref:
        raise SystemExit(
            f"RIGHTS GATE: asset '{rights_id}' has no license_ref. A signed "
            "release doc path is required before calibrating from this footage.")
    license_abs = os.path.join(REPO_ROOT, license_ref)
    if not os.path.exists(license_abs):
        raise SystemExit(
            f"RIGHTS GATE: license_ref '{license_ref}' for asset '{rights_id}' "
            f"does not exist on disk ({license_abs}). Commit the signed release "
            "before calibrating.")
    asset_path = asset.get("asset_path")
    if asset_path and not os.path.exists(os.path.join(REPO_ROOT, asset_path)):
        raise SystemExit(
            f"RIGHTS GATE: asset_path '{asset_path}' for '{rights_id}' is not on "
            "disk. The cleared footage binary must be present to calibrate.")
    return asset


def build_calibrated_reference(poses_doc, ref, register_path, rights_id, dry_run):
    samples = poses_doc.get("jointSamples") or poses_doc.get("frames") or []
    by_phase = {}
    for s in samples:
        cp = PORT.PHASE_MAP.get(s.get("phase", ""))
        if cp:
            by_phase.setdefault(cp, []).append(s)

    out_phases = []
    evidence_phases = []
    for phase in ref["phases"]:
        cp = phase["phase"]
        poses = by_phase.get(cp, [])
        new_ranges = {}
        ev_features = []
        for key in PORT.FEATURE_ORDER:
            if key not in phase.get("ranges", {}):
                continue
            band, ev = calibrate_band(key, poses, phase["ranges"][key])
            new_ranges[key] = band
            ev_features.append({"feature": key, **band, **ev})
        # Preserve any feature ordering / extra keys not in FEATURE_ORDER.
        for key, prior in phase.get("ranges", {}).items():
            if key not in new_ranges:
                band, ev = calibrate_band(key, poses, prior)
                new_ranges[key] = band
                ev_features.append({"feature": key, **band, **ev})
        out_phase = dict(phase)
        out_phase["ranges"] = new_ranges
        out_phases.append(out_phase)
        evidence_phases.append({
            "phase": cp, "frameCount": len(poses), "features": ev_features,
        })

    calibrated_ref = dict(ref)
    calibrated_ref["phases"] = out_phases
    note = ref.get("description", "")
    calibrated_ref["calibration"] = {
        "issue": "SCA-1869",
        "method": "robust per-phase percentile band on scale-normalized features, "
                  "padded and floored to generic minimum width (Option C)",
        "feature_geometry": "imported from ComparisonEngine reference port (parity)",
        "policy": {"angle": POLICY["angle"], "ratio": POLICY["ratio"],
                   "lo_pct": LO_PCT, "hi_pct": HI_PCT},
        "dry_run": dry_run,
        "rights_id": rights_id,
        "shippable": not dry_run,
        "review_status": "machine_proposed_pending_coach_review",
    }
    report = {
        "_meta": {
            "artifact_type": "calibration_report",
            "issue": "SCA-1869",
            "generated_by": "tools/sca1869-calibration/calibrate.py",
            "reference_id": ref.get("id"),
            "stroke_type": ref.get("strokeType"),
            "rights_id": rights_id,
            "dry_run": dry_run,
            "shippable": not dry_run,
            "pose_source": poses_doc.get("_meta", {}).get("artifact_type"),
            "note": ("DRY RUN — methodology validation only, NOT shippable bands. "
                     if dry_run else "")
            + "Machine-proposed generic bands; coach review required before bundling.",
        },
        "phases": evidence_phases,
    }
    return calibrated_ref, report


def main():
    ap = argparse.ArgumentParser(description="Calibrate v0 generic feature ranges (SCA-1869).")
    ap.add_argument("--poses", required=True, help="pose-extraction artifact JSON")
    ap.add_argument("--reference", required=True, help="reference_*_drive_v0.json to recalibrate")
    ap.add_argument("--out", required=True, help="output calibrated reference JSON path")
    ap.add_argument("--report", help="optional calibration report JSON path")
    ap.add_argument("--rights-id", help="register id of the cleared footage (enforces rights gate)")
    ap.add_argument("--register", default=DEFAULT_REGISTER, help="exemplar-rights-register.json path")
    ap.add_argument("--dry-run", action="store_true",
                    help="methodology validation only; bypasses rights gate, marks output non-shippable")
    args = ap.parse_args()

    if not args.dry_run and not args.rights_id:
        sys.exit("Refusing: pass --rights-id <register-id> for a real calibration, "
                 "or --dry-run for methodology validation only.")

    if not args.dry_run:
        asset = check_rights(args.register, args.rights_id)
        print(f"RIGHTS GATE PASSED: '{args.rights_id}' "
              f"[{asset['rights_status']}] license_ref={asset.get('license_ref')}")

    poses_doc = json.load(open(args.poses))
    ref = json.load(open(args.reference))
    calibrated_ref, report = build_calibrated_reference(
        poses_doc, ref, args.register, args.rights_id, args.dry_run)

    json.dump(calibrated_ref, open(args.out, "w"), indent=2)
    print(f"wrote calibrated reference: {args.out}"
          + (" [DRY RUN — non-shippable]" if args.dry_run else ""))
    if args.report:
        json.dump(report, open(args.report, "w"), indent=2)
        print(f"wrote calibration report:  {args.report}")

    # Console summary.
    for ph in report["phases"]:
        print(f"  {ph['phase']:<16} frames={ph['frameCount']}")
        for f in ph["features"]:
            src = f.get("source")
            n = f.get("nSamples")
            print(f"      {f['feature']:<28} [{f['idealMin']}, {f['idealMax']}] "
                  f"src={src} n={n}")


if __name__ == "__main__":
    main()
