import Foundation

// SCA-1871 Gate 4 demo harness (board-authorized 2026-06-06: "It's a demo. ballpark
// generation is fine. Spin up an agent to act like a coach").
//
// Synthesizes ballpark forehand-drive clips, runs the REAL RuleBasedFeedbackEngine,
// and emits the top recommendation (first .improvement card by ascending phaseIndex)
// per clip as JSON. A coach agent then reviews these independently.
//
// Joints are placed in 4 disjoint time-windows so each phase metric is realized
// exactly from its own frames (no cross-coupling):
//   ph1 stance   window 0.00–0.25  -> frames t in [0.00, 0.18]
//   ph3 knee     window 0.10–0.30  -> frames t in [0.51, 0.60]   (ph1 ends 0.5)
//   ph5 hip-sep  window 0.30–0.70  -> frames t in [0.70, 1.30]
//   ph8 wrist    window 0.70–1.00  -> frames t in [1.50, 2.00]

let DURATION = 2.0
let FPS = 60.0

func jp(_ x: Double, _ y: Double, _ c: Double = 0.9) -> JointPosition {
    JointPosition(x: Float(x), y: Float(y), confidence: Float(c))
}

// Build the joint dictionary for a frame at time t, realizing the profile's targets
// only within the relevant window (other joints present but inert).
func joints(forT t: Double, stance: Double, kneeDeg: Double, sepDeg: Double, wristRel: Double) -> [String: JointPosition] {
    var j: [String: JointPosition] = [:]
    // Defaults (inert but present)
    j["left_shoulder"] = jp(0.40, 0.80); j["right_shoulder"] = jp(0.60, 0.80)
    j["left_hip"] = jp(0.45, 0.50);      j["right_hip"] = jp(0.55, 0.50)
    j["left_ankle"] = jp(0.45, 0.10);    j["right_ankle"] = jp(0.55, 0.10)
    j["right_knee"] = jp(0.55, 0.30);    j["left_knee"] = jp(0.45, 0.30)
    j["right_wrist"] = jp(0.60, 0.85);   j["right_elbow"] = jp(0.60, 0.70)

    if t <= 0.18 {
        // Stance: shoulder span 0.2; ankle span = stance * 0.2
        let span = stance * 0.2
        j["left_shoulder"] = jp(0.40, 0.80); j["right_shoulder"] = jp(0.60, 0.80)
        j["left_ankle"] = jp(0.50 - span / 2, 0.10)
        j["right_ankle"] = jp(0.50 + span / 2, 0.10)
    } else if t >= 0.51 && t < 0.60 {
        // Knee interior angle at right_knee between right_hip and right_ankle.
        // Strictly < 0.60 so these frames don't leak into the ph5 separation
        // window (timestamp >= duration*0.3 = 0.60).
        let knee = (0.50, 0.40)
        j["right_knee"] = jp(knee.0, knee.1)
        j["right_hip"] = jp(knee.0, knee.1 + 0.30)            // v1 = up
        let a = kneeDeg * Double.pi / 180.0
        j["right_ankle"] = jp(knee.0 + 0.30 * sin(a), knee.1 + 0.30 * cos(a))
    } else if t >= 0.70 && t <= 1.30 {
        // Hip–shoulder separation: hip line flat, shoulder line tilted by sepDeg.
        j["left_hip"] = jp(0.45, 0.50); j["right_hip"] = jp(0.55, 0.50)   // hipAngle = 0
        let th = sepDeg * Double.pi / 180.0
        j["left_shoulder"] = jp(0.50 - 0.10 * cos(th), 0.80 - 0.10 * sin(th))
        j["right_shoulder"] = jp(0.50 + 0.10 * cos(th), 0.80 + 0.10 * sin(th))
    } else if t >= 1.50 {
        // Wrist height rel torso: shoulderMidY 0.80, hipMidY 0.40, torso 0.40.
        j["left_hip"] = jp(0.45, 0.40); j["right_hip"] = jp(0.55, 0.40)
        j["left_shoulder"] = jp(0.45, 0.80); j["right_shoulder"] = jp(0.55, 0.80)
        j["right_wrist"] = jp(0.60, 0.80 + wristRel * 0.40)
    }
    return j
}

func makeAnalysis(stance: Double, kneeDeg: Double, sepDeg: Double, wristRel: Double) -> PoseAnalysisResult {
    var samples: [JointSample] = []
    let n = Int(DURATION * FPS)
    for i in 0...n {
        let t = Double(i) / FPS
        let inWindow = (t <= 0.18) || (t >= 0.51 && t < 0.60) || (t >= 0.70 && t <= 1.30) || (t >= 1.50)
        guard inWindow else { continue }
        samples.append(JointSample(
            timestamp: t, frameIndex: i,
            joints: joints(forT: t, stance: stance, kneeDeg: kneeDeg, sepDeg: sepDeg, wristRel: wristRel)
        ))
    }
    let report = ConfidenceReport(jointReliability: [:], contactZoneReliable: true, overallReliable: true, notes: [])
    return PoseAnalysisResult(
        sessionId: UUID(), shotType: "forehand_drive", analyzedAt: Date(),
        videoPath: "demo", videoDurationSeconds: DURATION,
        originalFrameCount: n, samplingInterval: 1, sampledFrameCount: samples.count,
        jointSamples: samples, confidenceReport: report
    )
}

// (id, stance, kneeDeg, sepDeg, wristRel, note)
let profiles: [(String, Double, Double, Double, Double, String)] = [
    ("demo-fh-01", 0.82, 155, 35,  0.30, "Feet clearly together; otherwise solid swing."),
    ("demo-fh-02", 0.90, 150, 30,  0.20, "Stance slightly narrow; rest looks fine."),
    ("demo-fh-03", 1.45, 160, 40,  0.40, "Very wide base, slow to recover."),
    ("demo-fh-04", 1.38, 158, 28,  0.25, "Base a touch wide."),
    ("demo-fh-05", 0.75, 152, 33,  0.35, "Narrow stance, feet nearly under hips."),
    ("demo-fh-06", 1.15, 178, 35,  0.30, "Legs almost straight at load."),
    ("demo-fh-07", 1.10, 172, 30,  0.20, "Knee just shy of a real load."),
    ("demo-fh-08", 1.20, 132, 38,  0.40, "Deep squat at load, slow recovery."),
    ("demo-fh-09", 1.05, 138, 25,  0.15, "Slightly deep knee bend."),
    ("demo-fh-10", 1.25, 175, 42,  0.50, "Upright load, little leg drive."),
    ("demo-fh-11", 1.12, 128, 31,  0.28, "Very deep load."),
    ("demo-fh-12", 1.15, 155, 12,  0.30, "Arms-only swing, minimal hip turn."),
    ("demo-fh-13", 1.08, 150, 18,  0.25, "A bit shoulder-dominant."),
    ("demo-fh-14", 1.20, 160,  8,  0.35, "Almost no hip-shoulder separation."),
    ("demo-fh-15", 1.10, 148, 15,  0.20, "Limited kinetic chain."),
    ("demo-fh-16", 1.18, 165, 19,  0.40, "Separation just under ideal."),
    ("demo-fh-17", 1.15, 155, 35, -0.25, "Paddle stops at waist, truncated finish."),
    ("demo-fh-18", 1.10, 150, 30, -0.05, "Finish just below shoulder."),
    ("demo-fh-19", 1.20, 160, 40, -0.40, "Very short follow-through."),
    ("demo-fh-20", 1.05, 145, 25, -0.15, "Follow-through a bit low."),
    ("demo-fh-21", 1.22, 168, 45, -0.30, "Finish below shoulder."),
    ("demo-fh-22", 0.88, 178, 35,  0.30, "Narrow stance AND straight legs."),
    ("demo-fh-23", 1.15, 175, 10,  0.30, "Upright load and tiny hip turn."),
    ("demo-fh-24", 1.15, 155, 12, -0.30, "Low hip turn and truncated finish."),
    ("demo-fh-25", 1.40, 155, 35, -0.30, "Wide base and short follow-through."),
    ("demo-fh-26", 1.10, 158, 35, -0.10, "Mostly good; finish a touch low."),
    ("demo-fh-27", 0.95, 155, 30,  0.30, "Stance a hair narrow."),
    ("demo-fh-28", 1.15, 171, 33,  0.25, "Knee a touch upright."),
    ("demo-fh-29", 1.18, 160, 17,  0.30, "Hip turn slightly under ideal."),
    ("demo-fh-30", 1.32, 150, 28,  0.40, "Base marginally wide."),
]

struct TopRec: Codable {
    let clipId: String
    let footageNote: String
    let hasImprovement: Bool
    let ruleId: String?
    let phaseIndex: Int?
    let phaseTitle: String?
    let observation: String?
    let citedMetricName: String?
    let citedMetricValue: Double?
    let allCards: [String]   // "phaseIndex:ruleId:severity" for context
}

let engine = RuleBasedFeedbackEngine(strokeType: "forehand_drive")
var out: [TopRec] = []

for p in profiles {
    let analysis = makeAnalysis(stance: p.1, kneeDeg: p.2, sepDeg: p.3, wristRel: p.4)
    let cards = engine.generateFeedback(from: analysis)   // sorted ascending by phaseIndex
    let top = cards.first { $0.primaryObservation?.severity == .improvement }
    let summary = cards.map { c -> String in
        let sev = c.primaryObservation?.severity.rawValue ?? (c.score == -1 ? "insufficient" : "n/a")
        let rid = c.primaryObservation?.ruleId ?? "-"
        return "\(c.phaseIndex):\(rid):\(sev)"
    }
    if let t = top, let obs = t.primaryObservation {
        out.append(TopRec(clipId: p.0, footageNote: p.5, hasImprovement: true,
                          ruleId: obs.ruleId, phaseIndex: t.phaseIndex, phaseTitle: t.phaseTitle,
                          observation: obs.observation, citedMetricName: obs.citedMetricName,
                          citedMetricValue: obs.citedMetricValue, allCards: summary))
    } else {
        out.append(TopRec(clipId: p.0, footageNote: p.5, hasImprovement: false,
                          ruleId: nil, phaseIndex: nil, phaseTitle: nil, observation: nil,
                          citedMetricName: nil, citedMetricValue: nil, allCards: summary))
    }
}

let enc = JSONEncoder()
enc.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try enc.encode(out)
FileHandle.standardOutput.write(data)
