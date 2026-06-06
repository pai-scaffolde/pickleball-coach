import Foundation

// MARK: - Protocol

protocol FeedbackEngineProtocol {
    /// Produces one ClipFeedback per covered phase from a pose analysis result.
    /// Rules are evaluated deterministically; no AI judgment is applied.
    func generateFeedback(from analysis: PoseAnalysisResult) -> [ClipFeedback]
}

// MARK: - Rule-based engine

/// Applies coach-reviewed FeedbackRules to computed mechanics metrics.
/// The engine computes numeric values from pose data, checks rule conditions,
/// and populates coach-authored observation text. It never invents coaching judgments.
final class RuleBasedFeedbackEngine: FeedbackEngineProtocol {

    private let rules: [FeedbackRule]

    /// Creates an engine loaded with the rules for a given stroke type.
    /// Unknown stroke types fall through to an empty rule set (returns no feedback).
    init(strokeType: String = "forehand_drive") {
        switch strokeType {
        case "forehand_drive": rules = FeedbackRuleSet.forehandDrive
        default: rules = []
        }
    }

    func generateFeedback(from analysis: PoseAnalysisResult) -> [ClipFeedback] {
        let rulesByPhase = Dictionary(grouping: rules, by: \.phaseIndex)

        return rulesByPhase.keys.sorted().compactMap { phaseIndex in
            let phaseRules = rulesByPhase[phaseIndex]!
            return buildClipFeedback(phaseRules: phaseRules, analysis: analysis)
        }
    }

    // MARK: - Per-phase build

    private func buildClipFeedback(phaseRules: [FeedbackRule], analysis: PoseAnalysisResult) -> ClipFeedback {
        guard let firstRule = phaseRules.first else { fatalError("Empty phase rule set") }

        // Compute the metric for every rule in this phase.
        // All rules for a phase share the same metricName and window, so we compute once.
        let metric = computeMetric(
            named: firstRule.metricName,
            from: analysis.jointSamples,
            windowStart: firstRule.windowStart,
            windowEnd: firstRule.windowEnd,
            videoDuration: analysis.videoDurationSeconds
        )

        let clipStart = analysis.videoDurationSeconds * firstRule.windowStart
        let clipEnd = analysis.videoDurationSeconds * firstRule.windowEnd

        // Insufficient confidence → return a "not enough evidence" card.
        if metric.confidence == .noData || metric.confidence == .insufficient {
            let note = insufficientNote(metric: metric, rule: firstRule)
            return ClipFeedback(
                id: UUID(),
                sessionId: analysis.sessionId,
                phaseIndex: firstRule.phaseIndex,
                phaseTitle: firstRule.phaseTitle,
                strokeType: analysis.shotType,
                clipStartSeconds: clipStart,
                clipEndSeconds: clipEnd,
                score: -1,
                scoreDimensionLabel: firstRule.scoreDimensionLabel,
                primaryObservation: nil,
                additionalObservations: [],
                metrics: [metric],
                overallConfidence: metric.confidence,
                insufficientDataNote: note,
                highlightJointNames: firstRule.highlightJointNames
            )
        }

        // Find the first rule whose condition fires for the computed value.
        let firingRule = phaseRules.first { $0.fires(for: metric.value) } ?? firstRule

        let obs = FeedbackObservation(
            ruleId: firingRule.ruleId,
            severity: firingRule.severity,
            observation: firingRule.formatObservation(metric.value),
            correction: firingRule.correction,
            drill: firingRule.drill,
            citedMetricName: metric.name,
            citedMetricValue: metric.value,
            citedFrameIndices: metric.citedFrameIndices,
            metricConfidence: metric.confidence
        )

        return ClipFeedback(
            id: UUID(),
            sessionId: analysis.sessionId,
            phaseIndex: firingRule.phaseIndex,
            phaseTitle: firingRule.phaseTitle,
            strokeType: analysis.shotType,
            clipStartSeconds: clipStart,
            clipEndSeconds: clipEnd,
            score: firingRule.score(for: metric.value),
            scoreDimensionLabel: firingRule.scoreDimensionLabel,
            primaryObservation: obs,
            additionalObservations: [],
            metrics: [metric],
            overallConfidence: metric.confidence,
            insufficientDataNote: nil,
            highlightJointNames: firingRule.highlightJointNames
        )
    }

    // MARK: - Metric dispatch

    private func computeMetric(
        named name: String,
        from samples: [JointSample],
        windowStart: Double,
        windowEnd: Double,
        videoDuration: Double
    ) -> MechanicsMetric {
        let windowed = windowedSamples(samples,
                                       startFraction: windowStart,
                                       endFraction: windowEnd,
                                       videoDuration: videoDuration)
        switch name {
        case "stance_width_ratio":
            return stanceWidthRatio(windowed)
        case "right_knee_bend_degrees":
            return rightKneeBendDegrees(windowed)
        case "hip_shoulder_separation_degrees":
            return hipShoulderSeparationDegrees(windowed)
        case "right_wrist_height_rel_torso":
            return rightWristHeightRelTorso(windowed)
        default:
            return MechanicsMetric(name: name, value: 0, unit: "unknown",
                                   confidence: .noData, citedFrameIndices: [], citedTimestamps: [])
        }
    }

    // MARK: - Metric computations

    /// Ankle span / shoulder span. Ideal ≈ 1.0–1.3 for pickleball ready position.
    private func stanceWidthRatio(_ samples: [JointSample]) -> MechanicsMetric {
        let required = ["left_ankle", "right_ankle", "left_shoulder", "right_shoulder"]
        let qualifying = samples.filter { s in required.allSatisfy { s.joints[$0] != nil } }
        guard !qualifying.isEmpty else {
            return .noData(name: "stance_width_ratio", unit: "ratio")
        }

        let ratios = qualifying.map { s -> Double in
            let la = s.joints["left_ankle"]!, ra = s.joints["right_ankle"]!
            let ls = s.joints["left_shoulder"]!, rs = s.joints["right_shoulder"]!
            let ankleSpan = abs(Double(ra.x - la.x))
            let shoulderSpan = abs(Double(rs.x - ls.x))
            return shoulderSpan > 1e-6 ? ankleSpan / shoulderSpan : 0
        }

        let mean = ratios.reduce(0, +) / Double(ratios.count)
        let meanConf = meanConfidence(samples: qualifying, joints: required)

        return MechanicsMetric(
            name: "stance_width_ratio",
            value: (mean * 100).rounded() / 100,
            unit: "ratio",
            confidence: MetricConfidence(frameCount: qualifying.count, meanConfidence: meanConf),
            citedFrameIndices: qualifying.map(\.frameIndex),
            citedTimestamps: qualifying.map(\.timestamp)
        )
    }

    /// Interior angle (degrees) at right_knee between rays to right_hip and right_ankle.
    /// Full extension ≈ 180°. Ready-position bend ≈ 140–170°.
    private func rightKneeBendDegrees(_ samples: [JointSample]) -> MechanicsMetric {
        let required = ["right_hip", "right_knee", "right_ankle"]
        let qualifying = samples.filter { s in required.allSatisfy { s.joints[$0] != nil } }
        guard !qualifying.isEmpty else {
            return .noData(name: "right_knee_bend_degrees", unit: "degrees")
        }

        let angles = qualifying.compactMap { s -> Double? in
            let hip = s.joints["right_hip"]!, knee = s.joints["right_knee"]!, ankle = s.joints["right_ankle"]!
            return interiorAngleDeg(
                a: (Double(hip.x), Double(hip.y)),
                vertex: (Double(knee.x), Double(knee.y)),
                b: (Double(ankle.x), Double(ankle.y))
            )
        }
        guard !angles.isEmpty else {
            return .noData(name: "right_knee_bend_degrees", unit: "degrees")
        }

        let mean = angles.reduce(0, +) / Double(angles.count)
        let meanConf = meanConfidence(samples: qualifying, joints: required)

        return MechanicsMetric(
            name: "right_knee_bend_degrees",
            value: mean.rounded(),
            unit: "degrees",
            confidence: MetricConfidence(frameCount: qualifying.count, meanConfidence: meanConf),
            citedFrameIndices: qualifying.map(\.frameIndex),
            citedTimestamps: qualifying.map(\.timestamp)
        )
    }

    /// Angular difference between hip line and shoulder line.
    /// Reports the peak value across the window (kinetic chain peak moment).
    private func hipShoulderSeparationDegrees(_ samples: [JointSample]) -> MechanicsMetric {
        let required = ["left_hip", "right_hip", "left_shoulder", "right_shoulder"]
        let qualifying = samples.filter { s in required.allSatisfy { s.joints[$0] != nil } }
        guard !qualifying.isEmpty else {
            return .noData(name: "hip_shoulder_separation_degrees", unit: "degrees")
        }

        var bestValue = 0.0
        var bestSample: JointSample? = nil

        for s in qualifying {
            let lh = s.joints["left_hip"]!, rh = s.joints["right_hip"]!
            let ls = s.joints["left_shoulder"]!, rs = s.joints["right_shoulder"]!
            let hipAngle = atan2(Double(rh.y - lh.y), Double(rh.x - lh.x))
            let shoulderAngle = atan2(Double(rs.y - ls.y), Double(rs.x - ls.x))
            var diff = abs(hipAngle - shoulderAngle) * 180.0 / .pi
            if diff > 180 { diff = 360 - diff }
            if diff > bestValue {
                bestValue = diff
                bestSample = s
            }
        }

        let meanConf = meanConfidence(samples: qualifying, joints: required)

        return MechanicsMetric(
            name: "hip_shoulder_separation_degrees",
            value: bestValue.rounded(),
            unit: "degrees",
            confidence: MetricConfidence(frameCount: qualifying.count, meanConfidence: meanConf),
            citedFrameIndices: bestSample.map { [$0.frameIndex] } ?? [],
            citedTimestamps: bestSample.map { [$0.timestamp] } ?? []
        )
    }

    /// (right_wrist.y − right_shoulder.y) / torsoLength.
    /// Positive = wrist above shoulder. Reports the peak value across the follow-through window.
    private func rightWristHeightRelTorso(_ samples: [JointSample]) -> MechanicsMetric {
        let required = ["right_wrist", "right_shoulder", "left_shoulder", "right_hip", "left_hip"]
        let qualifying = samples.filter { s in required.allSatisfy { s.joints[$0] != nil } }
        guard !qualifying.isEmpty else {
            return .noData(name: "right_wrist_height_rel_torso", unit: "normalized")
        }

        var bestValue = -Double.infinity
        var bestSample: JointSample? = nil

        for s in qualifying {
            let wrist = s.joints["right_wrist"]!, rShoulder = s.joints["right_shoulder"]!
            let lShoulder = s.joints["left_shoulder"]!, rHip = s.joints["right_hip"]!
            let lHip = s.joints["left_hip"]!

            let shoulderMidY = Double(rShoulder.y + lShoulder.y) / 2.0
            let hipMidY = Double(rHip.y + lHip.y) / 2.0
            let torso = shoulderMidY - hipMidY
            guard abs(torso) > 1e-4 else { continue }

            let heightRelShoulder = (Double(wrist.y) - shoulderMidY) / torso
            if heightRelShoulder > bestValue {
                bestValue = heightRelShoulder
                bestSample = s
            }
        }

        guard bestValue > -Double.infinity else {
            return .noData(name: "right_wrist_height_rel_torso", unit: "normalized")
        }

        let meanConf = meanConfidence(samples: qualifying, joints: required)

        return MechanicsMetric(
            name: "right_wrist_height_rel_torso",
            value: (bestValue * 100).rounded() / 100,
            unit: "normalized",
            confidence: MetricConfidence(frameCount: qualifying.count, meanConfidence: meanConf),
            citedFrameIndices: bestSample.map { [$0.frameIndex] } ?? [],
            citedTimestamps: bestSample.map { [$0.timestamp] } ?? []
        )
    }

    // MARK: - Geometry helpers

    private func interiorAngleDeg(
        a: (Double, Double),
        vertex: (Double, Double),
        b: (Double, Double)
    ) -> Double? {
        let v1 = (a.0 - vertex.0, a.1 - vertex.1)
        let v2 = (b.0 - vertex.0, b.1 - vertex.1)
        let dot = v1.0 * v2.0 + v1.1 * v2.1
        let m1 = (v1.0 * v1.0 + v1.1 * v1.1).squareRoot()
        let m2 = (v2.0 * v2.0 + v2.1 * v2.1).squareRoot()
        guard m1 > 1e-6, m2 > 1e-6 else { return nil }
        let cosv = max(-1, min(1, dot / (m1 * m2)))
        return acos(cosv) * 180.0 / .pi
    }

    // MARK: - Utilities

    private func windowedSamples(
        _ samples: [JointSample],
        startFraction: Double,
        endFraction: Double,
        videoDuration: Double
    ) -> [JointSample] {
        let lo = videoDuration * startFraction
        let hi = videoDuration * endFraction
        return samples.filter { $0.timestamp >= lo && $0.timestamp <= hi }
    }

    private func meanConfidence(samples: [JointSample], joints: [String]) -> Double {
        var total = 0.0
        var count = 0
        for s in samples {
            for j in joints {
                if let p = s.joints[j] {
                    total += Double(p.confidence)
                    count += 1
                }
            }
        }
        return count > 0 ? total / Double(count) : 0
    }

    private func insufficientNote(metric: MechanicsMetric, rule: FeedbackRule) -> String {
        switch metric.confidence {
        case .noData:
            return "Required joints (\(rule.requiredJoints.joined(separator: ", "))) were not detected in the \(rule.phaseTitle.lowercased()) window. Ensure the full body is visible."
        case .insufficient:
            return "Only \(metric.citedFrameIndices.count) frame(s) detected in the \(rule.phaseTitle.lowercased()) window — need at least \(rule.minFrames) for a reliable measurement."
        default:
            return ""
        }
    }
}

// MARK: - Mock engine

/// Returns deterministic demo feedback without requiring real pose data.
/// Intended for UI development and simulator testing.
final class MockFeedbackEngine: FeedbackEngineProtocol {

    func generateFeedback(from analysis: PoseAnalysisResult) -> [ClipFeedback] {
        let sessionId = analysis.sessionId
        let duration = max(analysis.videoDurationSeconds, 4.0)

        return [
            mockCard(
                sessionId: sessionId, phaseIndex: 1, phaseTitle: "Ready Position",
                score: 72, dimension: "Stance Width",
                ruleId: "ph1.stance.narrow",
                observation: "Stance is 87% of shoulder width — narrower than the 100–130% ideal.",
                correction: "Widen your base to shoulder width and soften your knees.",
                drill: "Shadow drill: bounce on your toes ten times, freeze in ready position.",
                metric: MechanicsMetric(name: "stance_width_ratio", value: 0.87, unit: "ratio",
                                        confidence: .medium, citedFrameIndices: [0, 4, 8], citedTimestamps: [0.0, 0.5, 1.0]),
                clipStart: 0, clipEnd: duration * 0.25, severity: .improvement,
                highlightJoints: ["left_ankle", "right_ankle", "left_knee", "right_knee"],
                duration: duration
            ),
            mockCard(
                sessionId: sessionId, phaseIndex: 3, phaseTitle: "Weight Load",
                score: 88, dimension: "Knee Bend",
                ruleId: "ph3.knee.good",
                observation: "Knee angle is 155° — within the 140–170° ideal loading range.",
                correction: "Maintain this knee bend through the weight-load phase.",
                drill: "Split-step + hold: land in split step, hold loaded position 2 seconds each rep.",
                metric: MechanicsMetric(name: "right_knee_bend_degrees", value: 155, unit: "degrees",
                                        confidence: .high, citedFrameIndices: [12, 16, 20], citedTimestamps: [1.5, 2.0, 2.5]),
                clipStart: duration * 0.1, clipEnd: duration * 0.3, severity: .strength,
                highlightJoints: ["right_hip", "right_knee", "right_ankle"],
                duration: duration
            ),
            mockCard(
                sessionId: sessionId, phaseIndex: 5, phaseTitle: "Hip / Shoulder Turn",
                score: 45, dimension: "Kinetic Chain",
                ruleId: "ph5.hip_turn.low",
                observation: "Peak hip–shoulder separation is 12° — below the 20° minimum for effective kinetic chain.",
                correction: "Let hips initiate and drive the swing; shoulders follow, not lead.",
                drill: "Towel-across-shoulders drill: rotate hips first, then release shoulders — 10 reps.",
                metric: MechanicsMetric(name: "hip_shoulder_separation_degrees", value: 12, unit: "degrees",
                                        confidence: .medium, citedFrameIndices: [28], citedTimestamps: [3.5]),
                clipStart: duration * 0.3, clipEnd: duration * 0.7, severity: .improvement,
                highlightJoints: ["left_hip", "right_hip", "left_shoulder", "right_shoulder"],
                duration: duration
            ),
            mockCard(
                sessionId: sessionId, phaseIndex: 8, phaseTitle: "Follow-Through",
                score: 65, dimension: "Follow-Through",
                ruleId: "ph8.follow_through.low",
                observation: "Paddle finished below shoulder height — drive follow-through is incomplete.",
                correction: "Finish the paddle across your body and above shoulder height on every full drive.",
                drill: "High-finish shadow drill: exaggerate the finish — paddle above head, hold 1 second.",
                metric: MechanicsMetric(name: "right_wrist_height_rel_torso", value: -0.15, unit: "normalized",
                                        confidence: .medium, citedFrameIndices: [44], citedTimestamps: [5.5]),
                clipStart: duration * 0.7, clipEnd: duration, severity: .improvement,
                highlightJoints: ["right_wrist", "right_shoulder", "right_elbow"],
                duration: duration
            ),
        ]
    }

    private func mockCard(
        sessionId: UUID,
        phaseIndex: Int,
        phaseTitle: String,
        score: Int,
        dimension: String,
        ruleId: String,
        observation: String,
        correction: String,
        drill: String,
        metric: MechanicsMetric,
        clipStart: Double,
        clipEnd: Double,
        severity: FeedbackSeverity,
        highlightJoints: [String],
        duration: Double
    ) -> ClipFeedback {
        let obs = FeedbackObservation(
            ruleId: ruleId,
            severity: severity,
            observation: observation,
            correction: correction,
            drill: drill,
            citedMetricName: metric.name,
            citedMetricValue: metric.value,
            citedFrameIndices: metric.citedFrameIndices,
            metricConfidence: metric.confidence
        )
        return ClipFeedback(
            id: UUID(),
            sessionId: sessionId,
            phaseIndex: phaseIndex,
            phaseTitle: phaseTitle,
            strokeType: "forehand_drive",
            clipStartSeconds: clipStart,
            clipEndSeconds: clipEnd,
            score: score,
            scoreDimensionLabel: dimension,
            primaryObservation: obs,
            additionalObservations: [],
            metrics: [metric],
            overallConfidence: metric.confidence,
            insufficientDataNote: nil,
            highlightJointNames: highlightJoints
        )
    }
}

// MARK: - MechanicsMetric convenience

extension MechanicsMetric {
    static func noData(name: String, unit: String) -> MechanicsMetric {
        MechanicsMetric(name: name, value: 0, unit: unit,
                        confidence: .noData, citedFrameIndices: [], citedTimestamps: [])
    }
}
