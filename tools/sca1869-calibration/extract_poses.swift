// SCA-1869 — Apple Vision pose extractor (calibration input).
//
// Headless CLI mirror of PoseExtractionService.swift: time-based sampling of a
// video, VNDetectHumanBodyPoseRequest per frame, emitting the durable
// `jointSamples` artifact the comparison/calibration harness consumes
// (joints in Vision normalized space, origin bottom-left — parity with the
// reference exemplars and ComparisonEngine).
//
// Usage: swift extract_poses.swift <in.mp4> <out.json> [sampleRateHz] [startS] [endS]
//
// Parity note: same joint set and snake_case keys as PoseExtractionService.

import Foundation
import Vision
import AVFoundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: extract_poses.swift <in.mp4> <out.json> [rateHz] [startS] [endS]\n".data(using: .utf8)!)
    exit(2)
}
let inURL = URL(fileURLWithPath: args[1])
let outPath = args[2]
let rate = args.count > 3 ? (Double(args[3]) ?? 10.0) : 10.0
let startS = args.count > 4 ? (Double(args[4]) ?? 0.0) : 0.0

let jointNames: [VNHumanBodyPoseObservation.JointName: String] = [
    .nose: "nose", .neck: "neck",
    .leftShoulder: "left_shoulder", .rightShoulder: "right_shoulder",
    .leftElbow: "left_elbow", .rightElbow: "right_elbow",
    .leftWrist: "left_wrist", .rightWrist: "right_wrist",
    .leftHip: "left_hip", .rightHip: "right_hip",
    .leftKnee: "left_knee", .rightKnee: "right_knee",
    .leftAnkle: "left_ankle", .rightAnkle: "right_ankle",
    .root: "root",
]

let asset = AVURLAsset(url: inURL)
let durTime = asset.duration
let duration = CMTimeGetSeconds(durTime)
let endS = args.count > 5 ? min((Double(args[5]) ?? duration), duration) : duration

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero

let interval = 1.0 / rate
var samples: [[String: Any]] = []
var t = startS
var idx = 0
var detected = 0
while t <= endS {
    let cmt = CMTime(seconds: t, preferredTimescale: 600)
    autoreleasepool {
        guard let cg = try? gen.copyCGImage(at: cmt, actualTime: nil) else { return }
        let req = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([req])
        guard let obs = req.results?.first,
              let pts = try? obs.recognizedPoints(.all) else { return }
        var joints: [String: Any] = [:]
        for (vnName, key) in jointNames {
            if let p = pts[vnName], p.confidence > 0.01 {
                joints[key] = ["x": Double(p.location.x), "y": Double(p.location.y),
                               "confidence": Double(p.confidence)]
            }
        }
        if joints.count >= 6 {
            samples.append(["frameIndex": idx, "timestamp": round(t * 1000) / 1000,
                            "phase": "", "joints": joints])
            detected += 1
        }
    }
    idx += 1
    t += interval
}

let meta: [String: Any] = [
    "artifact_type": "pose_analysis_result",
    "issue": "SCA-1869",
    "generated_by": "tools/sca1869-calibration/extract_poses.swift (Apple Vision VNDetectHumanBodyPoseRequest)",
    "note": "Time-based Vision pose extraction for v0 calibration. Vision normalized space, origin bottom-left. internal-dev source footage.",
]
let doc: [String: Any] = [
    "_meta": meta,
    "videoPath": inURL.lastPathComponent,
    "videoDurationSeconds": round(duration * 1000) / 1000,
    "sampleRateHz": rate,
    "sampledFrameCount": detected,
    "jointSamples": samples,
]
let data = try JSONSerialization.data(withJSONObject: doc, options: [.prettyPrinted, .sortedKeys])
try data.write(to: URL(fileURLWithPath: outPath))
print("extracted \(detected) pose frames (\(idx) sampled) from \(inURL.lastPathComponent) [\(String(format: "%.1f", startS))-\(String(format: "%.1f", endS))s @ \(rate)Hz] -> \(outPath)")
