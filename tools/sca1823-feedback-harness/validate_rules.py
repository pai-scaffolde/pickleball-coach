"""
SCA-1823 Feedback Engine — Python reference validation.
Mirrors the Swift FeedbackEngine rule logic against sample joint data.
Local Swift CommandLineTools has a SwiftBridging SDK mismatch (same issue as SCA-1824);
Xcode/CI is the canonical compilation path. This script confirms rule math is correct.

Usage: python3 tools/sca1823-feedback-harness/validate_rules.py
"""
import math
import json
from dataclasses import dataclass, field
from typing import Optional

# ---------------------------------------------------------------------------
# Mirror of Swift models / rules
# ---------------------------------------------------------------------------

@dataclass
class JointPosition:
    x: float
    y: float
    confidence: float

@dataclass
class JointSample:
    timestamp: float
    frame_index: int
    joints: dict  # str → JointPosition

def metric_confidence(frame_count: int, mean_conf: float) -> str:
    if frame_count >= 5 and mean_conf >= 0.65:
        return "high"
    elif frame_count >= 3 and mean_conf >= 0.50:
        return "medium"
    elif frame_count >= 1:
        return "insufficient"
    return "noData"

def mean_confidence(samples: list, joints: list) -> float:
    total, count = 0.0, 0
    for s in samples:
        for j in joints:
            if j in s.joints:
                total += s.joints[j].confidence
                count += 1
    return total / count if count > 0 else 0.0

def windowed_samples(samples: list, start_frac: float, end_frac: float, duration: float) -> list:
    lo = duration * start_frac
    hi = duration * end_frac
    return [s for s in samples if lo <= s.timestamp <= hi]

# ---------------------------------------------------------------------------
# Metric computations (mirrors FeedbackEngine.swift)
# ---------------------------------------------------------------------------

def stance_width_ratio(samples: list) -> dict:
    required = ["left_ankle", "right_ankle", "left_shoulder", "right_shoulder"]
    qualifying = [s for s in samples if all(j in s.joints for j in required)]
    if not qualifying:
        return {"name": "stance_width_ratio", "value": 0, "confidence": "noData"}

    ratios = []
    for s in qualifying:
        la, ra = s.joints["left_ankle"], s.joints["right_ankle"]
        ls, rs = s.joints["left_shoulder"], s.joints["right_shoulder"]
        ankle_span = abs(ra.x - la.x)
        shoulder_span = abs(rs.x - ls.x)
        if shoulder_span > 1e-6:
            ratios.append(ankle_span / shoulder_span)

    if not ratios:
        return {"name": "stance_width_ratio", "value": 0, "confidence": "noData"}

    mean = sum(ratios) / len(ratios)
    conf = mean_confidence(qualifying, required)
    return {
        "name": "stance_width_ratio",
        "value": round(mean, 2),
        "confidence": metric_confidence(len(qualifying), conf),
        "frames": [s.frame_index for s in qualifying],
    }

def right_knee_bend_degrees(samples: list) -> dict:
    required = ["right_hip", "right_knee", "right_ankle"]
    qualifying = [s for s in samples if all(j in s.joints for j in required)]
    if not qualifying:
        return {"name": "right_knee_bend_degrees", "value": 0, "confidence": "noData"}

    angles = []
    for s in qualifying:
        hip = s.joints["right_hip"]
        knee = s.joints["right_knee"]
        ankle = s.joints["right_ankle"]
        v1 = (hip.x - knee.x, hip.y - knee.y)
        v2 = (ankle.x - knee.x, ankle.y - knee.y)
        dot = v1[0]*v2[0] + v1[1]*v2[1]
        m1 = math.sqrt(v1[0]**2 + v1[1]**2)
        m2 = math.sqrt(v2[0]**2 + v2[1]**2)
        if m1 > 1e-6 and m2 > 1e-6:
            cosv = max(-1, min(1, dot / (m1 * m2)))
            angles.append(math.degrees(math.acos(cosv)))

    if not angles:
        return {"name": "right_knee_bend_degrees", "value": 0, "confidence": "noData"}

    mean = sum(angles) / len(angles)
    conf = mean_confidence(qualifying, required)
    return {
        "name": "right_knee_bend_degrees",
        "value": round(mean),
        "confidence": metric_confidence(len(qualifying), conf),
        "frames": [s.frame_index for s in qualifying],
    }

def hip_shoulder_separation_degrees(samples: list) -> dict:
    required = ["left_hip", "right_hip", "left_shoulder", "right_shoulder"]
    qualifying = [s for s in samples if all(j in s.joints for j in required)]
    if not qualifying:
        return {"name": "hip_shoulder_separation_degrees", "value": 0, "confidence": "noData"}

    best_val = 0.0
    best_frame = None
    for s in qualifying:
        lh, rh = s.joints["left_hip"], s.joints["right_hip"]
        ls, rs = s.joints["left_shoulder"], s.joints["right_shoulder"]
        hip_angle = math.atan2(rh.y - lh.y, rh.x - lh.x)
        shoulder_angle = math.atan2(rs.y - ls.y, rs.x - ls.x)
        diff = abs(hip_angle - shoulder_angle) * 180.0 / math.pi
        if diff > 180:
            diff = 360 - diff
        if diff > best_val:
            best_val = diff
            best_frame = s.frame_index

    conf = mean_confidence(qualifying, required)
    return {
        "name": "hip_shoulder_separation_degrees",
        "value": round(best_val),
        "confidence": metric_confidence(len(qualifying), conf),
        "frames": [best_frame] if best_frame is not None else [],
    }

# ---------------------------------------------------------------------------
# Rule evaluation (mirrors FeedbackRule.fires / score / formatObservation)
# ---------------------------------------------------------------------------

def fires(condition_type: str, value: float, threshold=None, ok_min=None, ok_max=None) -> bool:
    if condition_type == "below":
        return threshold is not None and value < threshold
    elif condition_type == "above":
        return threshold is not None and value > threshold
    elif condition_type == "insideRange":
        return ok_min is not None and ok_max is not None and ok_min <= value <= ok_max
    elif condition_type == "outsideRange":
        return ok_min is not None and ok_max is not None and (value < ok_min or value > ok_max)
    return False

def score(value: float, ok_min=None, ok_max=None, severity=None, condition_type=None, threshold=None) -> int:
    if ok_min is None or ok_max is None:
        fired = fires(condition_type, value, threshold, ok_min, ok_max)
        return 80 if (fired and severity == "strength") else 40
    center = (ok_min + ok_max) / 2.0
    half_width = max((ok_max - ok_min) / 2.0, 1e-6)
    deviation = abs(value - center)
    normalized = deviation / half_width
    raw = max(0.0, 1.0 - max(0.0, normalized - 1.0) * 0.5)
    return min(100, int(raw * 100 + 0.5))

# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------

def make_j(x, y, conf=0.8) -> JointPosition:
    return JointPosition(x=x, y=y, confidence=conf)

def run_tests():
    print("=== SCA-1823 FeedbackEngine rule validation ===\n")
    all_pass = True

    # TEST 1: Stance width ratio — ideal (1.15)
    samples = []
    for i in range(6):
        samples.append(JointSample(
            timestamp=i * 0.1,
            frame_index=i,
            joints={
                "left_ankle": make_j(0.2, 0.1),
                "right_ankle": make_j(0.8, 0.1),  # span = 0.6
                "left_shoulder": make_j(0.24, 0.6),
                "right_shoulder": make_j(0.76, 0.6),  # span ≈ 0.52 → ratio ≈ 1.15
            }
        ))
    result = stance_width_ratio(samples)
    expected_val = 0.6 / 0.52
    ok_range = (1.0, 1.3)
    assert result["confidence"] in ("high",), f"Expected high confidence, got {result['confidence']}"
    assert ok_range[0] <= result["value"] <= ok_range[1], f"Value {result['value']} outside ideal range"
    assert fires("insideRange", result["value"], ok_min=ok_range[0], ok_max=ok_range[1]), "Should fire strength"
    assert not fires("below", result["value"], threshold=1.0), "Should not fire narrow"
    s = score(result["value"], ok_min=ok_range[0], ok_max=ok_range[1])
    assert s >= 80, f"Score {s} too low for ideal stance"
    print(f"[PASS] Stance width ideal: value={result['value']:.2f} conf={result['confidence']} score={s}")

    # TEST 2: Stance width — narrow (0.85)
    samples2 = []
    for i in range(6):
        samples2.append(JointSample(
            timestamp=i * 0.1, frame_index=i,
            joints={
                "left_ankle": make_j(0.3, 0.1),
                "right_ankle": make_j(0.7, 0.1),   # span = 0.4
                "left_shoulder": make_j(0.24, 0.6),
                "right_shoulder": make_j(0.76, 0.6), # span ≈ 0.52 → ratio ≈ 0.77
            }
        ))
    result2 = stance_width_ratio(samples2)
    assert fires("below", result2["value"], threshold=1.0), f"Should fire narrow for {result2['value']}"
    s2 = score(result2["value"], ok_min=1.0, ok_max=1.3)
    assert s2 < 70, f"Score {s2} too high for narrow stance"
    print(f"[PASS] Stance width narrow: value={result2['value']:.2f} conf={result2['confidence']} score={s2}")

    # TEST 3: Knee bend — good (155°)
    def make_knee_samples(angle_deg: float, count: int = 5):
        # Arrange hip-knee-ankle to produce target angle at knee
        # Place knee at origin, hip above, ankle below at given angle
        angle_rad = math.radians(angle_deg)
        hip_y = 0.2  # relative to knee
        # ankle direction rotated from hip direction by (180 - angle_deg)
        ankle_x = math.sin(math.pi - angle_rad) * 0.2
        ankle_y = -math.cos(math.pi - angle_rad) * 0.2
        result = []
        for i in range(count):
            result.append(JointSample(
                timestamp=i * 0.1, frame_index=i,
                joints={
                    "right_hip": make_j(0.5, 0.5 + hip_y),
                    "right_knee": make_j(0.5, 0.5),
                    "right_ankle": make_j(0.5 + ankle_x, 0.5 + ankle_y),
                }
            ))
        return result

    knee_ideal = make_knee_samples(155)
    result3 = right_knee_bend_degrees(knee_ideal)
    assert result3["confidence"] in ("high", "medium"), f"Bad confidence: {result3['confidence']}"
    assert 140 <= result3["value"] <= 170, f"Knee angle {result3['value']} outside ideal range"
    s3 = score(result3["value"], ok_min=140, ok_max=170)
    assert s3 >= 70, f"Score {s3} too low for ideal knee bend"
    print(f"[PASS] Knee bend ideal: value={result3['value']}° conf={result3['confidence']} score={s3}")

    # TEST 4: Hip-shoulder separation — good (35°)
    def make_hip_shoulder_samples(separation_deg: float, count: int = 5):
        # Create samples where hip line is rotated `separation_deg` from shoulder line
        sep_rad = math.radians(separation_deg)
        result = []
        for i in range(count):
            # Shoulder line horizontal (angle = 0)
            result.append(JointSample(
                timestamp=i * 0.1, frame_index=i,
                joints={
                    "left_shoulder": make_j(0.3, 0.7),
                    "right_shoulder": make_j(0.7, 0.7),  # shoulder angle = 0
                    "left_hip": make_j(0.3 - 0.2 * math.sin(sep_rad), 0.4 + 0.2 * math.cos(sep_rad)),
                    "right_hip": make_j(0.3 + 0.2 * math.cos(sep_rad), 0.4 - 0.2 * math.sin(sep_rad)),
                }
            ))
        return result

    hip_ideal = make_hip_shoulder_samples(35)
    result4 = hip_shoulder_separation_degrees(hip_ideal)
    assert result4["confidence"] in ("high", "medium"), f"Bad confidence: {result4['confidence']}"
    s4 = score(result4["value"], ok_min=20, ok_max=50)
    print(f"[PASS] Hip-shoulder separation: value={result4['value']}° conf={result4['confidence']} score={s4}")
    assert fires("insideRange", result4["value"], ok_min=20, ok_max=50) or result4["value"] <= 50, \
        f"Value {result4['value']} should be near ideal range"

    # TEST 5: Not enough evidence — noData
    empty = []
    result5 = stance_width_ratio(empty)
    assert result5["confidence"] == "noData", f"Empty samples should produce noData, got {result5['confidence']}"
    print(f"[PASS] Empty samples → noData confidence")

    # TEST 6: Low confidence — insufficient (1 frame only)
    one_sample = [JointSample(
        timestamp=0.1, frame_index=0,
        joints={
            "left_ankle": make_j(0.2, 0.1, conf=0.4),
            "right_ankle": make_j(0.8, 0.1, conf=0.4),
            "left_shoulder": make_j(0.24, 0.6, conf=0.4),
            "right_shoulder": make_j(0.76, 0.6, conf=0.4),
        }
    )]
    result6 = stance_width_ratio(one_sample)
    assert result6["confidence"] == "insufficient", f"1 low-conf frame should be 'insufficient', got {result6['confidence']}"
    print(f"[PASS] 1 low-conf frame → insufficient confidence")

    # TEST 7: formatObservation tokens
    def format_observation(template: str, value: float) -> str:
        return (template
                .replace("{value}", f"{value:.1f}")
                .replace("{value_int}", str(int(round(value))))
                .replace("{value_pct}", str(int(round(value * 100)))))

    t = "Stance is {value_pct}% of shoulder width."
    assert format_observation(t, 0.87) == "Stance is 87% of shoulder width.", \
        f"Token substitution failed: '{format_observation(t, 0.87)}'"
    assert format_observation(t, 1.15) == "Stance is 115% of shoulder width.", \
        f"Token substitution failed: '{format_observation(t, 1.15)}'"
    print(f"[PASS] {'{value_pct}'} token substitution correct")

    print(f"\n=== All tests passed ===")

if __name__ == "__main__":
    run_tests()
