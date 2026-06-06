import SwiftUI

// Skeleton connection pairs drawn as lines between joints.
// Both joint keys must be present in the sample for the bone to render.
private let skeletonBones: [(String, String)] = [
    ("neck", "nose"),
    ("neck", "left_shoulder"),
    ("neck", "right_shoulder"),
    ("left_shoulder", "right_shoulder"),
    ("left_shoulder", "left_elbow"),
    ("left_elbow", "left_wrist"),
    ("right_shoulder", "right_elbow"),
    ("right_elbow", "right_wrist"),
    ("left_shoulder", "left_hip"),
    ("right_shoulder", "right_hip"),
    ("left_hip", "right_hip"),
    ("left_hip", "left_knee"),
    ("left_knee", "left_ankle"),
    ("right_hip", "right_knee"),
    ("right_knee", "right_ankle"),
    ("root", "left_hip"),
    ("root", "right_hip"),
]

// Canvas-based skeleton overlay drawn from a single PoseFrame.
// Vision coordinates: (0,0) = bottom-left, (1,1) = top-right → Y is flipped for UIKit/SwiftUI.
struct PoseOverlayView: View {
    let frame: PoseFrame
    var reliableThreshold: Float = 0.70  // green above, orange below

    var body: some View {
        Canvas { ctx, size in
            func pt(_ key: String) -> CGPoint? {
                guard let j = frame.joints[key] else { return nil }
                return CGPoint(
                    x: Double(j.x) * size.width,
                    y: (1.0 - Double(j.y)) * size.height
                )
            }

            for (a, b) in skeletonBones {
                guard let pa = pt(a), let pb = pt(b) else { continue }
                var path = Path()
                path.move(to: pa)
                path.addLine(to: pb)
                ctx.stroke(path, with: .color(.yellow.opacity(0.75)), lineWidth: 2)
            }

            for (key, joint) in frame.joints {
                guard let p = pt(key) else { continue }
                let r: CGFloat = 5
                let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
                let color: Color = joint.confidence >= reliableThreshold ? .green : .orange
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}
