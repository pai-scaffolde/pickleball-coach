#!/usr/bin/env python3
"""SCA-1824 comparison — faithful reference port of ComparisonEngine.swift.

This computes the EXACT same geometry and range/delta scoring as
PickleballCoach/Services/ComparisonEngine.swift. It exists only so the
comparison can be run and the artifact regenerated on a host whose local Swift
CommandLineTools toolchain is broken (duplicate SwiftBridging modulemap). The
Swift file is the product code; this port mirrors it line-for-line in behaviour.

Usage: reference_port.py <user.json> <reference.json> <out.json>
"""
import json
import math
import sys

PHASE_MAP = {
    "ready": "ready",
    "preparation": "load", "load": "load", "weight_load": "load",
    "backswing": "takeback", "backswing_peak": "takeback", "takeback": "takeback",
    "forward_swing": "turn", "turn": "turn", "hip_shoulder_turn": "turn",
    "pre_contact": "contact", "contact": "contact", "contact_zone": "contact",
    "follow_through": "follow_through",
    "recovery": "recovery", "reset": "recovery", "balance": "recovery",
}
CANONICAL_ORDER = ["ready", "load", "takeback", "turn", "contact", "follow_through", "recovery"]
FEATURE_ORDER = [
    "right_elbow_angle_deg",
    "right_knee_angle_deg",
    "hip_shoulder_separation_deg",
    "wrist_height_rel_torso",
    "arm_extension_rel_torso",
]
MIN_CONF = 0.5
# SCA-1864: below this shoulder-width/torso ratio the capture is treated as
# side-on and the axial-rotation line-angle feature is excluded from scoring.
SIDE_ON_FRONTALITY_THRESHOLD = 0.30
# Per-feature scoring weights. The 2D hip/shoulder line-angle is a weak axial
# rotation proxy, so it is down-weighted and cannot dominate a phase score.
FEATURE_WEIGHTS = {"hip_shoulder_separation_deg": 0.25}


def weight(key):
    return FEATURE_WEIGHTS.get(key, 1.0)


def mean_frontality(poses):
    vals = []
    for p in poses:
        j = p["joints"]
        t = torso_length(j)
        ls, rs = point(j, "left_shoulder"), point(j, "right_shoulder")
        if t is None or ls is None or rs is None:
            continue
        vals.append(dist(ls, rs) / t)
    return sum(vals) / len(vals) if vals else None


def r3(v):
    return round(v * 1000) / 1000


def point(joints, name):
    j = joints.get(name)
    if j is None or float(j["confidence"]) < MIN_CONF:
        return None
    return (float(j["x"]), float(j["y"]))


def mid(joints, a, b):
    pa, pb = point(joints, a), point(joints, b)
    if pa is None or pb is None:
        return None
    return ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2)


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def torso_length(joints):
    sh = mid(joints, "left_shoulder", "right_shoulder")
    hip = mid(joints, "left_hip", "right_hip")
    if sh is None or hip is None:
        return None
    d = dist(sh, hip)
    return d if d > 1e-4 else None


def angle_at(joints, vertex, a, b):
    v, pa, pb = point(joints, vertex), point(joints, a), point(joints, b)
    if v is None or pa is None or pb is None:
        return None
    v1 = (pa[0] - v[0], pa[1] - v[1])
    v2 = (pb[0] - v[0], pb[1] - v[1])
    dot = v1[0] * v2[0] + v1[1] * v2[1]
    m1 = math.hypot(*v1)
    m2 = math.hypot(*v2)
    if m1 <= 1e-6 or m2 <= 1e-6:
        return None
    cosv = max(-1, min(1, dot / (m1 * m2)))
    return math.degrees(math.acos(cosv))


def line_angle(joints, a, b):
    pa, pb = point(joints, a), point(joints, b)
    if pa is None or pb is None:
        return None
    return math.degrees(math.atan2(pb[1] - pa[1], pb[0] - pa[0]))


def angular_diff(a, b):
    d = a - b
    while d > 180:
        d -= 360
    while d < -180:
        d += 360
    return d


def feature(key, joints):
    if key == "right_elbow_angle_deg":
        return angle_at(joints, "right_elbow", "right_shoulder", "right_wrist")
    if key == "right_knee_angle_deg":
        return angle_at(joints, "right_knee", "right_hip", "right_ankle")
    if key == "hip_shoulder_separation_deg":
        sl = line_angle(joints, "left_shoulder", "right_shoulder")
        hl = line_angle(joints, "left_hip", "right_hip")
        if sl is None or hl is None:
            return None
        return abs(angular_diff(sl, hl))
    if key == "wrist_height_rel_torso":
        t = torso_length(joints)
        w = point(joints, "right_wrist")
        s = point(joints, "right_shoulder")
        if t is None or w is None or s is None:
            return None
        return (w[1] - s[1]) / t
    if key == "arm_extension_rel_torso":
        t = torso_length(joints)
        s = point(joints, "right_shoulder")
        w = point(joints, "right_wrist")
        if t is None or s is None or w is None:
            return None
        return dist(s, w) / t
    return None


def mean_feature(key, poses):
    vals = [v for v in (feature(key, p["joints"]) for p in poses) if v is not None]
    return sum(vals) / len(vals) if vals else None


def compare_feature(key, user_value, rng):
    if user_value is None:
        return {"feature": key, "userValue": None, "idealMin": rng["idealMin"],
                "idealMax": rng["idealMax"], "delta": 0,
                "status": "insufficient_confidence", "featureScore": 0}
    width = max(rng["idealMax"] - rng["idealMin"], 1e-6)
    if user_value < rng["idealMin"]:
        delta, status = user_value - rng["idealMin"], "below"
    elif user_value > rng["idealMax"]:
        delta, status = user_value - rng["idealMax"], "above"
    else:
        delta, status = 0, "within"
    score = max(0, 1 - abs(delta) / width)
    return {"feature": key, "userValue": r3(user_value), "idealMin": rng["idealMin"],
            "idealMax": rng["idealMax"], "delta": r3(delta), "status": status,
            "featureScore": r3(score)}


def main():
    if len(sys.argv) != 4:
        sys.exit("usage: reference_port.py <user.json> <reference.json> <out.json>")
    user = json.load(open(sys.argv[1]))
    ref = json.load(open(sys.argv[2]))

    by_phase = {}
    for s in user["jointSamples"]:
        cp = PHASE_MAP.get(s.get("phase", ""))
        if cp:
            by_phase.setdefault(cp, []).append(s)

    ref_phases = {p["phase"]: p for p in ref["phases"]}
    phase_reports = []
    measured_scores = []

    for cp in CANONICAL_ORDER:
        rp = ref_phases.get(cp)
        if rp is None:
            continue
        poses = by_phase.get(cp, [])
        feats = []
        weighted_sum = 0.0
        weight_total = 0.0
        for key in FEATURE_ORDER:
            if key not in rp["ranges"]:
                continue
            uv = mean_feature(key, poses)
            rep = compare_feature(key, uv, rp["ranges"][key])
            # SCA-1864: exclude the 2D axial-rotation feature on side-on captures.
            if key == "hip_shoulder_separation_deg" and rep["status"] != "insufficient_confidence":
                fr = mean_frontality(poses)
                if fr is not None and fr < SIDE_ON_FRONTALITY_THRESHOLD:
                    rep = dict(rep, status="low_view_confidence")
            feats.append(rep)
            if rep["status"] not in ("insufficient_confidence", "low_view_confidence"):
                w = weight(key)
                weighted_sum += rep["featureScore"] * w
                weight_total += w
        measured = weight_total > 0
        phase_score = (weighted_sum / weight_total) * 100 if measured else 0
        if measured:
            measured_scores.append(phase_score)
        phase_reports.append({
            "phase": cp, "userFrameCount": len(poses), "features": feats,
            "phaseScore": round(phase_score * 10) / 10, "measured": measured,
        })

    overall = sum(measured_scores) / len(measured_scores) if measured_scores else 0
    unmeasured = [p["phase"] for p in phase_reports if not p["measured"]]
    notes = []
    if unmeasured:
        notes.append("Phases with no measurable features (missing segment or low confidence): "
                     + ", ".join(unmeasured) + ".")
    side_on = [p["phase"] for p in phase_reports
               if any(f["status"] == "low_view_confidence" for f in p["features"])]
    if side_on:
        notes.append("hip_shoulder_separation_deg excluded as low-view-confidence (side-on capture; "
                     "2D cannot read axial rotation) for: " + ", ".join(side_on) + ".")
    notes.append("hip_shoulder_separation_deg is down-weighted (×0.25): a single-camera 2D "
                 "line-angle is a weak axial-rotation proxy. Reliable torso rotation needs depth/3D pose.")
    notes.append("Comparison is range/delta on scale-normalized features. "
                 "No pixel alignment, no ghost overlay, no pro footage.")

    report = {
        "strokeType": ref["strokeType"], "referenceId": ref["id"],
        "referenceRightsStatus": ref["rightsStatus"],
        "method": "range_delta_on_scale_normalized_features",
        "ghostOverlay": False, "alignment": "phase_keyed_not_pixel",
        "minJointConfidence": MIN_CONF, "phases": phase_reports,
        "overallScore": round(overall * 10) / 10,
        "measuredPhaseCount": len(measured_scores), "notes": notes,
    }
    doc = {
        "_meta": {
            "artifact_type": "side_by_side_comparison_report",
            "issue": "SCA-1824",
            "generated_by": "ComparisonEngine reference port (reference_port.py) — identical geometry/scoring to ComparisonEngine.swift",
            "user_source": sys.argv[1].split("/")[-1],
            "reference_source": sys.argv[2].split("/")[-1],
            "note": "Phase-keyed comparison of a user clip against a pose-only generic exemplar (Option C). No pixel alignment, no pro footage, no ghost overlay. Local Swift CommandLineTools toolchain has a duplicate SwiftBridging modulemap defect; rebuild via Xcode/CI compiles ComparisonEngine.swift directly.",
        },
        "report": report,
    }
    json.dump(doc, open(sys.argv[3], "w"), indent=2, sort_keys=True)

    print("SCA-1824 comparison complete")
    print(f"  reference: {report['referenceId']} [{report['referenceRightsStatus']}]")
    print(f"  method:    {report['method']} | ghostOverlay={report['ghostOverlay']} | alignment={report['alignment']}")
    print(f"  overall:   {report['overallScore']}/100 across {report['measuredPhaseCount']} measured phases")
    for p in phase_reports:
        mark = f"{p['phaseScore']:.1f}" if p["measured"] else "n/a"
        print(f"  - {p['phase']:<16} score={mark}  frames={p['userFrameCount']}")
    print(f"  wrote: {sys.argv[3]}")


if __name__ == "__main__":
    main()
