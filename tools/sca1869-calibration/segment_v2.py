#!/usr/bin/env python3
"""SCA-1884 — landmark-anchored rep + phase segmentation (tightens SCA-1869 v0).

Why a v2: ``segment.py`` (SCA-1869) detects each drive's contact peak correctly,
but then lays a FIXED time-fraction template (``PHASE_TEMPLATE``) over the rep
window. Blind time slices drift relative to the actual stroke, so frames from
adjacent phases bleed into each phase pool. That inflates the per-phase
percentile spread, which is exactly why the SCA-1869 calibrated bands are too
wide (the demo comparison scores a non-discriminating 100/100) and were not
promoted (see docs/SCA-1869-CALIBRATION.md).

v2 keeps the proven contact-peak detector but anchors phase boundaries to
*kinematic landmarks* per rep, derived from the single robust scalar the footage
gives us — arm extension relative to torso (ComparisonEngine geometry parity):

  * contact peak  ``tc``   = local MAXIMUM of arm extension (ball strike, full reach)
  * takeback trough ``tb`` = MINIMUM of extension in the pre-contact window
                             (racket fully drawn back / arm coiled)
  * follow-through trough ``te`` = MINIMUM of extension in the post-contact window
                             (arm decelerated, end of follow-through)

Phases are then placed RELATIVE TO those anchors instead of blind fractions:

  ready / load            pre-window, before takeback begins (time-split, stable)
  takeback                drawing the racket back, ENDING at the trough ``tb``
  turn                    forward swing: ``tb`` -> just before contact
  contact                 a TIGHT window straddling the peak ``tc`` (the key fix)
  follow_through          ``tc`` -> trough ``te``
  recovery               after ``te``

The big tightening win is the contact phase: instead of a ~0.12-of-window time
slice that drifts off the strike, it is a narrow band straddling the measured
peak, so the contact bands (the most coaching-relevant) stop pooling swing
frames. Anchoring the takeback/turn split at the real trough ``tb`` (vs a blind
0.42 fraction) tightens those too.

Output schema is identical to segment.py so calibrate.py consumes it unchanged.

Usage: segment_v2.py <poses.json> <out_labeled.json> [--hand right|left]
"""
import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "sca1824-comparison-harness"))
import reference_port as rp  # noqa: E402  (feature geometry parity)

# Rep search window relative to the contact peak (seconds). Generous enough to
# contain the takeback trough (pre) and the follow-through trough (post).
PRE_S = 0.7
POST_S = 0.5
# Contact phase half-width (seconds): frames within +/-CONTACT_HALF_S of the
# measured peak are "contact". Narrow on purpose — this is the tightening.
CONTACT_HALF_S = 0.10
PEAK_PCTL = 0.70        # contact extension must exceed this percentile
MIN_SEP_S = 1.2         # min separation between contact peaks
MIN_ARM_CONF = 0.5      # right shoulder/elbow/wrist mean confidence floor

# Canonical phases in time order, used to sub-split the pre-takeback region.
PRE_PHASES = ["ready", "load", "takeback"]


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
    """Unchanged from segment.py — proven contact-peak detector."""
    ext = [rp.feature("arm_extension_rel_torso", f["joints"]) for f in frames]
    ext_s = smooth(ext)
    valid = sorted(v for v in ext_s if v is not None)
    if not valid:
        return [], ext_s
    thresh = valid[int(PEAK_PCTL * (len(valid) - 1))]
    peaks = []
    last_t = -1e9
    for i, f in enumerate(frames):
        v = ext_s[i]
        if v is None or v < thresh or arm_conf(f["joints"]) < MIN_ARM_CONF:
            continue
        lo, hi = max(0, i - 3), min(len(frames), i + 4)
        if v < max(x for x in ext_s[lo:hi] if x is not None):
            continue
        t = f["timestamp"]
        if t - last_t < MIN_SEP_S:
            if peaks and v > peaks[-1][1]:
                peaks[-1] = (t, v)
                last_t = t
            continue
        peaks.append((t, v))
        last_t = t
    return [t for t, _ in peaks], ext_s


def _trough_time(win, ext_by_t):
    """Timestamp of the minimum smoothed extension over `win` frames."""
    cand = [(ext_by_t.get(f["timestamp"]), f["timestamp"]) for f in win]
    cand = [(v, t) for v, t in cand if v is not None]
    if not cand:
        return None
    return min(cand)[1]


def _pre_phase(t, w0, tb):
    """Sub-split the pre-takeback span [w0, tb] into ready/load/takeback by thirds.

    The third nearest the trough is `takeback` (drawing back), so the takeback
    pool ends exactly at the measured deepest backswing rather than a blind
    fraction.
    """
    span = tb - w0
    if span <= 0:
        return "takeback"
    frac = (t - w0) / span
    idx = min(int(frac * len(PRE_PHASES)), len(PRE_PHASES) - 1)
    return PRE_PHASES[idx]


def label_frames(frames, contacts, ext_s):
    """Assign each frame a canonical phase from per-rep kinematic landmarks."""
    ext_by_t = {f["timestamp"]: ext_s[i] for i, f in enumerate(frames)}
    labeled = []
    reps = 0
    for tc in contacts:
        w0, w1 = tc - PRE_S, tc + POST_S
        win = [f for f in frames if w0 <= f["timestamp"] <= w1]
        if len(win) < 4 or arm_conf(_nearest(win, tc)["joints"]) < MIN_ARM_CONF:
            continue
        pre_win = [f for f in win if f["timestamp"] < tc - CONTACT_HALF_S]
        post_win = [f for f in win if f["timestamp"] > tc + CONTACT_HALF_S]
        # Landmarks: takeback trough (pre), follow-through trough (post).
        tb = _trough_time(pre_win, ext_by_t) or (tc - PRE_S * 0.45)
        te = _trough_time(post_win, ext_by_t) or (tc + POST_S * 0.6)
        reps += 1
        for f in win:
            t = f["timestamp"]
            if abs(t - tc) <= CONTACT_HALF_S:
                phase = "contact"
            elif t < tc:
                # before contact: takeback region ends at trough tb, then turn
                phase = "turn" if t >= tb else _pre_phase(t, w0, tb)
            else:
                phase = "follow_through" if t <= te else "recovery"
            lf = dict(f)
            lf["phase"] = phase
            lf["repContact"] = round(tc, 3)
            lf["repTakebackTrough"] = round(tb, 3)
            lf["repFollowThroughTrough"] = round(te, 3)
            labeled.append(lf)
    return labeled, reps


def _nearest(frames, t):
    return min(frames, key=lambda f: abs(f["timestamp"] - t))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("poses")
    ap.add_argument("out")
    ap.add_argument("--hand", default="right", choices=["right", "left"])
    args = ap.parse_args()

    doc = json.load(open(args.poses))
    frames = doc.get("jointSamples") or doc.get("frames") or []
    contacts, ext_s = detect_contacts(frames)
    labeled, reps = label_frames(frames, contacts, ext_s)

    from collections import Counter
    dist = Counter(f["phase"] for f in labeled)
    out = {
        "_meta": {
            "artifact_type": "pose_analysis_result",
            "issue": "SCA-1884",
            "generated_by": "tools/sca1869-calibration/segment_v2.py",
            "derived_from": doc.get("videoPath"),
            "method": "arm-extension contact-peak detection + per-rep kinematic-"
                      "landmark phase anchoring (takeback trough / contact peak / "
                      "follow-through trough); tightens SCA-1869 fixed time template",
            "contact_half_width_s": CONTACT_HALF_S,
            "detected_reps": reps,
            "note": "Landmark-anchored v0 segmentation of unscripted instructional "
                    "footage. Phase boundaries are anchored to measured kinematic "
                    "events, not blind time fractions. Calibrated bands remain "
                    "machine-proposed pending coach review.",
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
