#!/usr/bin/env python3
"""SCA-1861 mechanics scoring — faithful reference port of MechanicsScoringEngine.swift.

Computes the EXACT same deterministic forehand-drive mechanics score as
PickleballCoach/Services/MechanicsScoringEngine.swift. It exists so the score can
be produced and verified for determinism on a host whose local Swift
CommandLineTools toolchain is broken (duplicate SwiftBridging modulemap). The
Swift file is the product code; this port mirrors it in behaviour, and it REUSES
the SCA-1824 ComparisonEngine port (tools/sca1824-comparison-harness/reference_port.py)
for all geometry and range/delta scoring — exactly as the Swift engine reuses
ComparisonEngine rather than forking it.

Input is a [PoseFrame] timeline: {"frames": [{timestamp, joints, bodyDetected}]}.

Usage: reference_port.py <pose-timeline.json> <reference.json> <out.json> [clipId]
"""
import json
import os
import sys

# Reuse the SCA-1824 ComparisonEngine port (same geometry + scoring).
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "sca1824-comparison-harness"))
import reference_port as cmp  # noqa: E402

SCORED_PHASE = "contact"

CATEGORY_LABEL = {
    "right_elbow_angle_deg": "elbow extension",
    "right_knee_angle_deg": "knee bend",
    "hip_shoulder_separation_deg": "hip–shoulder separation",
    "wrist_height_rel_torso": "contact height",
    "arm_extension_rel_torso": "arm extension",
}
CATEGORY_UNIT = {
    "right_elbow_angle_deg": "°",
    "right_knee_angle_deg": "°",
    "hip_shoulder_separation_deg": "°",
}


def round1(v):
    return round(v * 10) / 10


def fmt(v, unit):
    if unit == "°":
        return f"{int(round(v))}{unit}"
    return f"{round(v * 100) / 100:.2f}"


def contact_features(joints, ranges):
    """Mirror ComparisonEngine: build FeatureComparison list for the contact
    phase, in FeatureKey order, from a single frame's joints."""
    feats = []
    for key in cmp.FEATURE_ORDER:
        if key not in ranges:
            continue
        uv = cmp.feature(key, joints)
        feats.append(cmp.compare_feature(key, uv, ranges[key]))
    return feats


def correction(status, label):
    if status == "within":
        return f"On target — keep this {label}."
    if status == "below":
        return f"Increase your {label} toward the ideal band."
    if status == "above":
        return f"Reduce your {label} toward the ideal band."
    return f"Not enough reliable pose data to coach {label} this rep."


def observation(fc, frame_index):
    feature = fc["feature"]
    label = CATEGORY_LABEL.get(feature, feature)
    unit = CATEGORY_UNIT.get(feature, "")
    uv = fc["userValue"]
    if uv is not None:
        measured = fmt(uv, unit)
        if fc["status"] == "within":
            severity = "strength"
        elif fc["status"] in ("below", "above"):
            severity = "improvement"
        else:
            severity = "neutral"
        confidence = "medium" if fc["status"] == "low_view_confidence" else "high"
    else:
        measured = "not measurable"
        severity = "neutral"
        confidence = "noData"
    ideal = f"{fmt(fc['idealMin'], unit)}–{fmt(fc['idealMax'], unit)}"
    text = f"{label}: {measured} / ideal {ideal}"
    return {
        "ruleId": f"mechanics.{feature}",
        "severity": severity,
        "observation": text,
        "correction": correction(fc["status"], label),
        "drill": "",
        "citedMetricName": feature,
        "citedMetricValue": uv if uv is not None else -1,
        "citedFrameIndices": [frame_index],
        "metricConfidence": confidence,
    }


def score(frames, reference, clip_id):
    ranges = None
    for p in reference["phases"]:
        if p["phase"] == SCORED_PHASE:
            ranges = p["ranges"]
            break
    if ranges is None:
        return None

    # Key frame = peak right-wrist speed (textbook contact proxy), torso-normalized.
    # Ties resolve to the lowest index. Falls back to the first measurable frame.
    best_index = None
    best_speed = -float("inf")
    first_measurable = None
    prev_wrist = None
    for idx, fr in enumerate(frames):
        if not fr.get("bodyDetected"):
            continue
        j = fr["joints"]
        wrist = cmp.point(j, "right_wrist")
        torso = cmp.torso_length(j)
        if wrist is None or torso is None:
            continue
        if first_measurable is None:
            first_measurable = idx
        if prev_wrist is not None:
            speed = cmp.dist(wrist, prev_wrist) / torso
            if speed > best_speed:
                best_speed = speed
                best_index = idx
        prev_wrist = wrist

    stroke = reference["strokeType"]
    chosen = best_index if best_index is not None else first_measurable
    if chosen is None:
        return {"id": clip_id, "clipId": clip_id, "strokeType": stroke,
                "keyFrameTimestamp": -1, "scores": {}, "observations": []}

    idx = chosen
    ts = frames[idx]["timestamp"]
    feats = contact_features(frames[idx]["joints"], ranges)
    scores = {}
    observations = []
    for fc in feats:
        scores[fc["feature"]] = round1(fc["featureScore"] * 100)
        observations.append(observation(fc, idx))
    return {"id": clip_id, "clipId": clip_id, "strokeType": stroke,
            "keyFrameTimestamp": ts, "scores": scores, "observations": observations}


def main():
    if len(sys.argv) not in (4, 5):
        sys.exit("usage: reference_port.py <pose-timeline.json> <reference.json> <out.json> [clipId]")
    timeline = json.load(open(sys.argv[1]))
    reference = json.load(open(sys.argv[2]))
    # Fixed clipId so the score is bitwise-reproducible (mirrors id = clip.id).
    clip_id = sys.argv[4] if len(sys.argv) == 5 else "00000000-0000-0000-0000-000000001861"

    frames = timeline["frames"] if "frames" in timeline else timeline
    result = score(frames, reference, clip_id)

    doc = {
        "_meta": {
            "artifact_type": "mechanics_score",
            "issue": "SCA-1861",
            "generated_by": "MechanicsScoringEngine reference port (reference_port.py) — mirrors MechanicsScoringEngine.swift, reuses the SCA-1824 ComparisonEngine port",
            "timeline_source": sys.argv[1].split("/")[-1],
            "reference_source": sys.argv[2].split("/")[-1],
            "thresholds_version": reference.get("mechanicsThresholds", {}).get("version"),
            "note": "Forehand-drive mechanics scored at the deterministic contact key frame (peak arm extension). Every observation carries measured vs reference. Local Swift toolchain is broken; Xcode/CI compiles MechanicsScoringEngine.swift directly (see verify_swift_parity.sh).",
        },
        "mechanicsScore": result,
    }
    json.dump(doc, open(sys.argv[3], "w"), indent=2, sort_keys=True)

    print("SCA-1861 mechanics score complete")
    print(f"  stroke:        {result['strokeType']}")
    print(f"  keyFrame ts:   {result['keyFrameTimestamp']}s")
    print(f"  categories:    {len(result['scores'])}")
    for o in result["observations"]:
        print(f"  - {o['severity']:<11} {o['observation']}")
    print(f"  wrote: {sys.argv[3]}")


if __name__ == "__main__":
    main()
