#!/usr/bin/env python3
"""SCA-1869 — rep + phase segmentation for v0 calibration.

Input footage for v0 is unscripted instructional video (multiple demo reps,
talking-head gaps, cuts), not a clean single-rep fixture. This segmenter finds
the drive strokes and labels each frame with a canonical phase so calibrate.py
can pool per-phase distributions.

Method (documented because it is approximate — bands are coach-reviewable):
  1. Per frame, compute arm_extension_rel_torso (reuses ComparisonEngine port
     geometry) and the mean confidence of the right shoulder/elbow/wrist.
  2. A drive's contact is the local MAXIMUM of arm extension (arm fully
     extended at ball strike). Detect contact peaks: above the configured
     percentile, min separation, with reliable right-arm confidence.
  3. Around each contact peak, lay a fixed phase template over a rep window
     (backswing is longer than follow-through) and label frames by time slice.
  4. Pool frames across all detected reps per canonical phase.

Usage: segment.py <poses.json> <out_labeled.json> [--hand right|left]
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "sca1824-comparison-harness"))
import reference_port as rp  # noqa: E402  (feature geometry parity)

# Rep window relative to the contact peak (seconds). Backswing (pre) is longer
# than the follow-through (post) for a drive.
PRE_S = 0.7
POST_S = 0.5
# Canonical phase template as fractions of the [peak-PRE, peak+POST] window.
# Tuned so the contact slice straddles the peak (PRE / (PRE+POST) ~= 0.58).
PHASE_TEMPLATE = [
    ("ready", 0.00, 0.08),
    ("load", 0.08, 0.20),
    ("takeback", 0.20, 0.42),
    ("turn", 0.42, 0.54),
    ("contact", 0.54, 0.66),
    ("follow_through", 0.66, 0.85),
    ("recovery", 0.85, 1.00),
]
PEAK_PCTL = 0.70        # contact extension must exceed this percentile
MIN_SEP_S = 1.2         # min separation between contact peaks
MIN_ARM_CONF = 0.5      # right shoulder/elbow/wrist mean confidence floor


def arm_conf(j):
    pts = [j.get("right_shoulder"), j.get("right_elbow"), j.get("right_wrist")]
    cs = [p["confidence"] for p in pts if p]
    return sum(cs) / len(cs) if len(cs) == 3 else 0.0


def smooth(vals, k=2):
    out = []
    n = len(vals)
    for i in range(n):
        lo, hi = max(0, i - k), min(n, i + k + 1)
        win = [v for v in vals[lo:hi] if v is not None]
        out.append(sum(win) / len(win) if win else None)
    return out


def detect_contacts(frames):
    ext = [rp.feature("arm_extension_rel_torso", f["joints"]) for f in frames]
    ext_s = smooth(ext)
    valid = sorted(v for v in ext_s if v is not None)
    if not valid:
        return []
    thresh = valid[int(PEAK_PCTL * (len(valid) - 1))]
    peaks = []
    last_t = -1e9
    for i, f in enumerate(frames):
        v = ext_s[i]
        if v is None or v < thresh or arm_conf(f["joints"]) < MIN_ARM_CONF:
            continue
        # local maximum within +/-3 frames
        lo, hi = max(0, i - 3), min(len(frames), i + 4)
        if v < max(x for x in ext_s[lo:hi] if x is not None):
            continue
        t = f["timestamp"]
        if t - last_t < MIN_SEP_S:
            # keep the higher peak
            if peaks and v > peaks[-1][1]:
                peaks[-1] = (t, v)
                last_t = t
            continue
        peaks.append((t, v))
        last_t = t
    return [t for t, _ in peaks]


def label_frames(frames, contacts):
    """Assign each frame a canonical phase from the nearest rep window."""
    labeled = []
    reps = 0
    for tc in contacts:
        w0, w1 = tc - PRE_S, tc + POST_S
        win = [f for f in frames if w0 <= f["timestamp"] <= w1]
        if len(win) < 4 or arm_conf(_nearest(win, tc)["joints"]) < MIN_ARM_CONF:
            continue
        reps += 1
        span = w1 - w0
        for f in win:
            frac = (f["timestamp"] - w0) / span if span > 0 else 0
            phase = _phase_for(frac)
            lf = dict(f)
            lf["phase"] = phase
            lf["repContact"] = round(tc, 3)
            labeled.append(lf)
    return labeled, reps


def _nearest(frames, t):
    return min(frames, key=lambda f: abs(f["timestamp"] - t))


def _phase_for(frac):
    for name, lo, hi in PHASE_TEMPLATE:
        if lo <= frac < hi:
            return name
    return "recovery"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("poses")
    ap.add_argument("out")
    ap.add_argument("--hand", default="right", choices=["right", "left"])
    args = ap.parse_args()

    doc = json.load(open(args.poses))
    frames = doc.get("jointSamples") or doc.get("frames") or []
    contacts = detect_contacts(frames)
    labeled, reps = label_frames(frames, contacts)

    from collections import Counter
    dist = Counter(f["phase"] for f in labeled)
    out = {
        "_meta": {
            "artifact_type": "pose_analysis_result",
            "issue": "SCA-1869",
            "generated_by": "tools/sca1869-calibration/segment.py",
            "derived_from": doc.get("videoPath"),
            "method": "arm-extension contact-peak detection + fixed phase template per rep, pooled across reps",
            "detected_reps": reps,
            "phase_template": PHASE_TEMPLATE,
            "note": "Approximate v0 segmentation of unscripted instructional footage; "
                    "phase boundaries are template-based, not hand-annotated. "
                    "Calibrated bands are machine-proposed pending coach review.",
        },
        "videoPath": doc.get("videoPath"),
        "detectedReps": reps,
        "jointSamples": labeled,
    }
    json.dump(out, open(args.out, "w"), indent=2, sort_keys=True)
    print(f"{doc.get('videoPath')}: {len(contacts)} contact peaks, {reps} usable reps, "
          f"{len(labeled)} labeled frames -> {args.out}")
    print("  phase frame counts:", dict(dist))


if __name__ == "__main__":
    main()
