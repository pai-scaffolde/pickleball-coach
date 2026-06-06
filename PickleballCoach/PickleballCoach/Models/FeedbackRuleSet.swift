import Foundation

// Coach-reviewed rule definitions for the pickleball feedback engine.
// All thresholds and observation text here were authored by a human coach.
// To revise coaching advice or adjust a threshold, edit this file.
// No AI generates or changes these judgments at runtime.
//
// Coverage:
//   Phase 1 — Ready Position      (stance_width_ratio)
//   Phase 3 — Weight Load         (right_knee_bend_degrees)
//   Phase 5 — Hip / Shoulder Turn (hip_shoulder_separation_degrees)
//   Phase 8 — Follow-Through      (right_wrist_height_rel_torso)
//
// Conditions within each phase are mutually exclusive, so order does not affect which fires.

enum FeedbackRuleSet {
    static let forehandDrive: [FeedbackRule] = [

        // MARK: Phase 1 — Ready Position: Stance Width
        // Ideal: ankle span is 100–130% of shoulder span. Narrower → limited lateral range.
        // Wider → slower first step.

        FeedbackRule(
            ruleId: "ph1.stance.good",
            phaseIndex: 1, phaseTitle: "Ready Position",
            metricName: "stance_width_ratio",
            scoreDimensionLabel: "Stance Width",
            requiredJoints: ["left_ankle", "right_ankle", "left_shoulder", "right_shoulder"],
            minFrames: 3,
            windowStart: 0.0, windowEnd: 0.25,
            conditionType: .insideRange, threshold: nil, okMin: 0.95, okMax: 1.35,
            higherIsBetter: false, severity: .strength,
            observationTemplate: "Stance is {value_pct}% of shoulder width — within tolerance of the 100–130% ideal range.",
            correction: "Maintain this base width throughout the rally.",
            drill: "Reinforce with shadow footwork: start each rep from this ready stance.",
            highlightJointNames: ["left_ankle", "right_ankle", "left_knee", "right_knee"]
        ),

        FeedbackRule(
            ruleId: "ph1.stance.narrow",
            phaseIndex: 1, phaseTitle: "Ready Position",
            metricName: "stance_width_ratio",
            scoreDimensionLabel: "Stance Width",
            requiredJoints: ["left_ankle", "right_ankle", "left_shoulder", "right_shoulder"],
            minFrames: 3,
            windowStart: 0.0, windowEnd: 0.25,
            conditionType: .below, threshold: 0.95, okMin: 0.95, okMax: 1.35,
            higherIsBetter: false, severity: .improvement,
            observationTemplate: "Stance is {value_pct}% of shoulder width — narrower than the 100–130% ideal.",
            correction: "Widen your base to shoulder width and soften your knees to 15–20° of bend.",
            drill: "Shadow drill: bounce on your toes ten times, freeze in ready position each bounce.",
            highlightJointNames: ["left_ankle", "right_ankle", "left_knee", "right_knee"]
        ),

        FeedbackRule(
            ruleId: "ph1.stance.wide",
            phaseIndex: 1, phaseTitle: "Ready Position",
            metricName: "stance_width_ratio",
            scoreDimensionLabel: "Stance Width",
            requiredJoints: ["left_ankle", "right_ankle", "left_shoulder", "right_shoulder"],
            minFrames: 3,
            windowStart: 0.0, windowEnd: 0.25,
            conditionType: .above, threshold: 1.35, okMin: 0.95, okMax: 1.35,
            higherIsBetter: false, severity: .improvement,
            observationTemplate: "Stance is {value_pct}% of shoulder width — wider than the 100–130% ideal, which limits lateral recovery.",
            correction: "Narrow your base slightly so you can step quickly in either direction.",
            drill: "Lateral shuffle drill: 3 steps left, 3 right, focusing on quick first step from a tighter base.",
            highlightJointNames: ["left_ankle", "right_ankle", "left_knee", "right_knee"]
        ),

        // MARK: Phase 3 — Weight Load: Knee Bend
        // Ideal: right knee angle 140–170° (soft bend; 180° = fully straight leg).
        // Below 140° → overly deep squat. Above 170° → too upright, poor power base.

        FeedbackRule(
            ruleId: "ph3.knee.good",
            phaseIndex: 3, phaseTitle: "Weight Load",
            metricName: "right_knee_bend_degrees",
            scoreDimensionLabel: "Knee Bend",
            requiredJoints: ["right_hip", "right_knee", "right_ankle"],
            minFrames: 3,
            windowStart: 0.1, windowEnd: 0.3,
            conditionType: .insideRange, threshold: nil, okMin: 138.0, okMax: 172.0,
            higherIsBetter: false, severity: .strength,
            observationTemplate: "Knee angle is {value_int}° — within tolerance of the 140–170° ideal loading range.",
            correction: "Maintain this knee bend through the weight-load phase.",
            drill: "Split-step + hold: land in split step, hold the loaded position for 2 seconds each rep.",
            highlightJointNames: ["right_hip", "right_knee", "right_ankle"]
        ),

        FeedbackRule(
            ruleId: "ph3.knee.upright",
            phaseIndex: 3, phaseTitle: "Weight Load",
            metricName: "right_knee_bend_degrees",
            scoreDimensionLabel: "Knee Bend",
            requiredJoints: ["right_hip", "right_knee", "right_ankle"],
            minFrames: 3,
            windowStart: 0.1, windowEnd: 0.3,
            conditionType: .above, threshold: 172.0, okMin: 138.0, okMax: 172.0,
            higherIsBetter: false, severity: .improvement,
            observationTemplate: "Knee angle is {value_int}° — nearly straight; soften into the shot for a stronger power base.",
            correction: "Load onto a bent knee (aim for 140–170°) before the paddle begins its backswing.",
            drill: "Lateral load drill: step and hold a bent-knee position for 2 seconds before each shadow swing.",
            highlightJointNames: ["right_hip", "right_knee", "right_ankle"]
        ),

        FeedbackRule(
            ruleId: "ph3.knee.deep",
            phaseIndex: 3, phaseTitle: "Weight Load",
            metricName: "right_knee_bend_degrees",
            scoreDimensionLabel: "Knee Bend",
            requiredJoints: ["right_hip", "right_knee", "right_ankle"],
            minFrames: 3,
            windowStart: 0.1, windowEnd: 0.3,
            conditionType: .below, threshold: 138.0, okMin: 138.0, okMax: 172.0,
            higherIsBetter: false, severity: .improvement,
            observationTemplate: "Knee angle is {value_int}° — a deep bend that may slow your recovery after contact.",
            correction: "Reduce knee bend to 140–170°; a shallower load keeps weight transfer fast.",
            drill: "Box-step drill: step into a 150° knee position using a floor marker to calibrate depth.",
            highlightJointNames: ["right_hip", "right_knee", "right_ankle"]
        ),

        // MARK: Phase 5 — Hip / Shoulder Turn: Kinetic Chain Separation
        // Measured at the frame with maximum separation in the mid-swing window.
        // Ideal: 20–50°. Below 20° → arms-only swing. Above 50° → over-rotation.

        FeedbackRule(
            ruleId: "ph5.hip_turn.good",
            phaseIndex: 5, phaseTitle: "Hip / Shoulder Turn",
            metricName: "hip_shoulder_separation_degrees",
            scoreDimensionLabel: "Kinetic Chain",
            requiredJoints: ["left_hip", "right_hip", "left_shoulder", "right_shoulder"],
            minFrames: 3,
            windowStart: 0.3, windowEnd: 0.7,
            conditionType: .insideRange, threshold: nil, okMin: 18.0, okMax: 50.0,
            higherIsBetter: true, severity: .strength,
            observationTemplate: "Peak hip–shoulder separation is {value_int}° — within tolerance of the 20–50° ideal range for kinetic chain transfer.",
            correction: "Keep hips leading shoulders through the swing.",
            drill: "Seated rotation drill: sit, rotate hips first, hold 2 seconds, then release shoulders.",
            highlightJointNames: ["left_hip", "right_hip", "left_shoulder", "right_shoulder"]
        ),

        FeedbackRule(
            ruleId: "ph5.hip_turn.low",
            phaseIndex: 5, phaseTitle: "Hip / Shoulder Turn",
            metricName: "hip_shoulder_separation_degrees",
            scoreDimensionLabel: "Kinetic Chain",
            requiredJoints: ["left_hip", "right_hip", "left_shoulder", "right_shoulder"],
            minFrames: 3,
            windowStart: 0.3, windowEnd: 0.7,
            conditionType: .below, threshold: 18.0, okMin: 18.0, okMax: 50.0,
            higherIsBetter: true, severity: .improvement,
            observationTemplate: "Peak hip–shoulder separation is {value_int}° — below the 20° minimum for effective kinetic chain.",
            correction: "Let hips initiate and drive the swing; shoulders follow, not lead.",
            drill: "Towel-across-shoulders drill: hold a towel across your shoulders, practice rotating hips first 10 times.",
            highlightJointNames: ["left_hip", "right_hip", "left_shoulder", "right_shoulder"]
        ),

        FeedbackRule(
            ruleId: "ph5.hip_turn.high",
            phaseIndex: 5, phaseTitle: "Hip / Shoulder Turn",
            metricName: "hip_shoulder_separation_degrees",
            scoreDimensionLabel: "Kinetic Chain",
            requiredJoints: ["left_hip", "right_hip", "left_shoulder", "right_shoulder"],
            minFrames: 3,
            windowStart: 0.3, windowEnd: 0.7,
            conditionType: .above, threshold: 50.0, okMin: 20.0, okMax: 50.0,
            higherIsBetter: true, severity: .neutral,
            observationTemplate: "Peak hip–shoulder separation is {value_int}° — on the higher end; verify this isn't over-rotation causing loss of control.",
            correction: "Control the degree of hip drive; a full but compact rotation is more consistent than an extreme one.",
            drill: "Controlled-rotation drill: swing at 70% speed focusing on stopping hip rotation cleanly at contact.",
            highlightJointNames: ["left_hip", "right_hip", "left_shoulder", "right_shoulder"]
        ),

        // MARK: Phase 8 — Follow-Through: Wrist Finish Height
        // right_wrist_height_rel_torso = (wrist.y - shoulder.y) / torsoLength.
        // Positive = wrist above shoulder. A complete drive follow-through should finish above shoulder.
        // Ideal: > 0.0 (above shoulder). Below 0.0 → truncated follow-through.

        FeedbackRule(
            ruleId: "ph8.follow_through.good",
            phaseIndex: 8, phaseTitle: "Follow-Through",
            metricName: "right_wrist_height_rel_torso",
            scoreDimensionLabel: "Follow-Through",
            requiredJoints: ["right_wrist", "right_shoulder", "left_shoulder", "right_hip", "left_hip"],
            minFrames: 3,
            windowStart: 0.7, windowEnd: 1.0,
            conditionType: .above, threshold: -0.1, okMin: 0.0, okMax: 1.5,
            higherIsBetter: true, severity: .strength,
            observationTemplate: "Paddle finished at or above shoulder height — follow-through is within tolerance.",
            correction: "Maintain this finish height on every drive.",
            drill: "Slow-finish drill: after each practice rep, consciously slow the follow-through and hold end position 2 seconds.",
            highlightJointNames: ["right_wrist", "right_shoulder", "right_elbow"]
        ),

        FeedbackRule(
            ruleId: "ph8.follow_through.low",
            phaseIndex: 8, phaseTitle: "Follow-Through",
            metricName: "right_wrist_height_rel_torso",
            scoreDimensionLabel: "Follow-Through",
            requiredJoints: ["right_wrist", "right_shoulder", "left_shoulder", "right_hip", "left_hip"],
            minFrames: 3,
            windowStart: 0.7, windowEnd: 1.0,
            conditionType: .below, threshold: -0.1, okMin: 0.0, okMax: 1.5,
            higherIsBetter: true, severity: .improvement,
            observationTemplate: "Paddle finished below shoulder height — drive follow-through is incomplete.",
            correction: "Finish the paddle across your body and above shoulder height on every full drive.",
            drill: "High-finish shadow drill: exaggerate the finish position — paddle above head, hold 1 second each rep.",
            highlightJointNames: ["right_wrist", "right_shoulder", "right_elbow"]
        ),
    ]
}
