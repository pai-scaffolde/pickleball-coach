#!/usr/bin/env python3
"""SCA-1868 — Compare-wiring verification (sudo-free, no Swift toolchain).

The local CommandLineTools swiftc cannot build the app (duplicate SwiftBridging
modulemap + SDK/compiler mismatch; Xcode not installed), so — as established for
SCA-1824 — the pure logic is verified by a behaviour-identical Python port and
the SwiftUI compile/render is delegated to CI (ios-build.yml).

This script proves the SCA-1868 wiring logic that ComparisonInputBuilder.swift
ports into the app, over the REAL SCA-1819 pose artifact and BOTH bundled
exemplars:

  1. exemplarResourceName(forShotType:)   — forehand / backhand / default mapping
  2. phasePoses(from: PoseAnalysisResult)  — honors per-sample phase labels
  3. phasePoses time-window fallback       — segments into the 7 canonical phases
  4. userPosesByPhase                       — one representative pose per phase
  5. end-to-end: ComparisonEngine produces a POPULATED report (overall score,
     measured phases, per-feature deltas) for BOTH forehand and backhand refs.

Exit 0 = every check passed.
"""
import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ARTIFACT = os.path.join(ROOT, "docs/artifacts/SCA-1819-pose-spike-artifact.json")
REF_FH = os.path.join(ROOT, "PickleballCoach/PickleballCoach/Resources/reference_forehand_drive_v0.json")
REF_BH = os.path.join(ROOT, "PickleballCoach/PickleballCoach/Resources/reference_backhand_drive_v0.json")
ENGINE = os.path.join(ROOT, "tools/sca1824-comparison-harness/reference_port.py")

CANONICAL_ORDER = ["ready", "load", "takeback", "turn", "contact", "follow_through", "recovery"]
PHASE_MAP = {
    "ready": "ready",
    "preparation": "load", "load": "load", "weight_load": "load",
    "backswing": "takeback", "backswing_peak": "takeback", "takeback": "takeback",
    "forward_swing": "turn", "turn": "turn", "hip_shoulder_turn": "turn",
    "pre_contact": "contact", "contact": "contact", "contact_zone": "contact",
    "follow_through": "follow_through",
    "recovery": "recovery", "reset": "recovery", "balance": "recovery",
}

failures = []
def check(name, cond, detail=""):
    mark = "ok  " if cond else "FAIL"
    print(f"  [{mark}] {name}" + (f" — {detail}" if detail else ""))
    if not cond:
        failures.append(name)


# ---- Ports of ComparisonInputBuilder ---------------------------------------

def exemplar_resource_name(shot_type):
    return ("reference_backhand_drive_v0"
            if "backhand" in shot_type.lower()
            else "reference_forehand_drive_v0")

def phase_poses_from_analysis(analysis):
    samples = analysis["jointSamples"]
    if not samples:
        return []
    if any(s.get("phase") for s in samples):
        return [{"phase": s["phase"], "joints": s["joints"]} for s in samples if s.get("phase")]
    return _time_window_segmented([(s["timestamp"], s["joints"]) for s in samples])

def phase_poses_time_window(samples):
    return _time_window_segmented([(s["timestamp"], s["joints"]) for s in samples])

def _time_window_segmented(timed):
    times = [t for t, _ in timed]
    lo, hi = min(times), max(times)
    span = hi - lo
    out = []
    n = len(CANONICAL_ORDER)
    for ts, joints in timed:
        frac = (ts - lo) / span if span > 1e-9 else 0.0
        idx = min(n - 1, max(0, int(frac * n)))
        out.append({"phase": CANONICAL_ORDER[idx], "joints": joints})
    return out

def user_poses_by_phase(poses):
    grouped = {}
    for p in poses:
        cp = PHASE_MAP.get(p["phase"])
        if cp:
            grouped.setdefault(cp, []).append(p)
    return {phase: lst[len(lst) // 2]["joints"] for phase, lst in grouped.items()}


# ---- Checks -----------------------------------------------------------------

def run_engine(artifact_path, ref_path, out_path):
    subprocess.run([sys.executable, ENGINE, artifact_path, ref_path, out_path],
                   check=True, capture_output=True, text=True)
    doc = json.load(open(out_path))
    return doc.get("report", doc)

def main():
    artifact = json.load(open(ARTIFACT))

    print("1) exemplarResourceName(forShotType:)")
    check("forehand_drive -> forehand ref", exemplar_resource_name("forehand_drive") == "reference_forehand_drive_v0")
    check("backhand_drive -> backhand ref", exemplar_resource_name("backhand_drive") == "reference_backhand_drive_v0")
    check("BackHand (mixed case) -> backhand ref", exemplar_resource_name("BackHand") == "reference_backhand_drive_v0")
    check("unknown -> forehand default", exemplar_resource_name("dink") == "reference_forehand_drive_v0")

    print("2) phasePoses(from: PoseAnalysisResult) — honors per-sample labels")
    poses = phase_poses_from_analysis(artifact)
    labelled = [s for s in artifact["jointSamples"] if s.get("phase")]
    check("artifact carries per-sample phase labels", len(labelled) > 0, f"{len(labelled)} labelled samples")
    check("one PhasePose per labelled sample", len(poses) == len(labelled), f"{len(poses)} poses")
    check("phases map onto canonical taxonomy",
          all(PHASE_MAP.get(p["phase"]) for p in poses),
          "raw labels: " + ",".join(sorted({p["phase"] for p in poses})))

    print("3) phasePoses time-window fallback (phase labels stripped)")
    stripped = [{k: v for k, v in s.items() if k != "phase"} for s in artifact["jointSamples"]]
    fb = phase_poses_time_window(stripped)
    fb_phases = {p["phase"] for p in fb}
    check("every fallback pose tagged with a canonical phase", fb_phases.issubset(set(CANONICAL_ORDER)))
    check("fallback spans multiple canonical phases", len(fb_phases) >= 5, f"{len(fb_phases)} phases: {sorted(fb_phases)}")
    check("fallback covers all samples", len(fb) == len(stripped))

    print("4) userPosesByPhase — representative pose per canonical phase")
    ubp = user_poses_by_phase(poses)
    check("keys are canonical phases", set(ubp).issubset(set(CANONICAL_ORDER)), f"{sorted(ubp)}")
    check("each phase yields a non-empty joint dict", all(len(j) > 0 for j in ubp.values()))

    print("5) end-to-end report populates for BOTH stroke types")
    for label, ref in (("forehand", REF_FH), ("backhand", REF_BH)):
        rep = run_engine(ARTIFACT, ref, f"/tmp/sca1868-{label}.json")
        measured = rep.get("measuredPhaseCount", 0)
        overall = rep.get("overallScore", 0)
        phases = rep.get("phases", [])
        has_deltas = any(
            any("delta" in f for f in p.get("features", []))
            for p in phases
        )
        check(f"{label}: reference loaded", rep.get("strokeType") is not None,
              f"strokeType={rep.get('strokeType')} ref={rep.get('referenceId')}")
        check(f"{label}: measured phases > 0", measured > 0, f"measuredPhaseCount={measured}")
        check(f"{label}: overall score in (0,100]", 0 < overall <= 100, f"overall={overall}")
        check(f"{label}: per-feature deltas present", has_deltas)
        check(f"{label}: phase picker would have entries", len(phases) > 0, f"{len(phases)} phases")

    print()
    if failures:
        print(f"VERIFY FAIL — {len(failures)} check(s) failed: {failures}")
        sys.exit(1)
    print("VERIFY OK — SCA-1868 compare-wiring logic verified over the real "
          "SCA-1819 artifact and both bundled exemplars.")

if __name__ == "__main__":
    main()
