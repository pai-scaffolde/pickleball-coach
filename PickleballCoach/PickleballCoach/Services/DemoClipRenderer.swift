import Foundation
import AVFoundation
import CoreGraphics
import CoreVideo
import CoreMedia

// MARK: - SCA-1907 — Runtime-rendered demo video clip
//
// Renders an animated skeleton video from a [PoseFrame] array.  The clip shows
// the idealized forehand stroke phases as a smooth skeletal animation, written
// to an .mp4 using AVAssetWriter + CoreGraphics pixel buffer rendering.
//
// Rights: the source frames originate from the bundled generic pose exemplar
// (usage_scope=bundled-app/cleared-public).  No third-party footage.  The
// rendered file is derived from synthetic data only.
enum DemoClipRenderer {

    enum RenderError: LocalizedError {
        case writerInitFailed(String)
        case sessionStartFailed
        case writingFailed(String)

        var errorDescription: String? {
            switch self {
            case .writerInitFailed(let msg):  return "DemoClipRenderer: writer init failed — \(msg)"
            case .sessionStartFailed:          return "DemoClipRenderer: AVAssetWriter session start failed"
            case .writingFailed(let msg):      return "DemoClipRenderer: write failed — \(msg)"
            }
        }
    }

    // Skeleton bone pairs — same list as PoseOverlayView.swift (keep in sync).
    private static let bones: [(String, String)] = [
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

    /// Renders a skeleton animation video from `frames` to `outputURL`.
    ///
    /// - Parameters:
    ///   - frames: Pose frames to animate.  Each consecutive pair is interpolated
    ///     to produce `framesPerSegment` rendered frames.
    ///   - outputURL: Destination .mp4 file path.  Must not exist — caller is
    ///     responsible for idempotency / deletion.
    ///   - size: Width and height in pixels (square output).
    ///   - fps: Frames per second of the output video.
    ///   - secondsPerPhase: How long (wall time) each phase-to-phase transition
    ///     takes.  Higher values = slower animation.
    static func render(
        frames: [PoseFrame],
        to outputURL: URL,
        size: Int = 480,
        fps: Int = 30,
        secondsPerPhase: Double = 0.5
    ) throws {
        guard !frames.isEmpty else { return }

        // AVAssetWriter setup
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw RenderError.writerInitFailed(error.localizedDescription)
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size,
            AVVideoHeightKey: size,
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: size,
            kCVPixelBufferHeightKey as String: size,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: attributes
        )

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let timescale: Int32 = Int32(fps * 100)
        let ticksPerFrame = Int32(fps * 100) / Int32(fps)  // = 100 ticks per frame
        let framesPerSegment = max(1, Int(secondsPerPhase * Double(fps)))
        let holdFrames = fps  // ~1 second hold at the last frame

        // Build the sequence of (interpolation-alpha, frameA, frameB) tuples
        var renderFrames: [(Double, PoseFrame, PoseFrame)] = []
        for segIdx in 0..<(frames.count - 1) {
            let a = frames[segIdx]
            let b = frames[segIdx + 1]
            for f in 0..<framesPerSegment {
                let alpha = Double(f) / Double(framesPerSegment)
                renderFrames.append((alpha, a, b))
            }
        }
        // Hold the final frame
        if let last = frames.last {
            for _ in 0..<holdFrames {
                renderFrames.append((1.0, last, last))
            }
        }

        // Render each frame into a pixel buffer
        let sema = DispatchSemaphore(value: 0)
        var renderError: Error?

        let queue = DispatchQueue(label: "DemoClipRenderer.write")
        writerInput.requestMediaDataWhenReady(on: queue) {
            var frameIdx = 0
            while frameIdx < renderFrames.count {
                guard writerInput.isReadyForMoreMediaData else { continue }

                let (alpha, frameA, frameB) = renderFrames[frameIdx]
                let pts = CMTime(
                    value: CMTimeValue(frameIdx) * CMTimeValue(ticksPerFrame),
                    timescale: timescale
                )

                guard let buffer = try? makePixelBuffer(
                    alpha: alpha, frameA: frameA, frameB: frameB,
                    size: size, attributes: attributes
                ) else {
                    frameIdx += 1
                    continue
                }

                adaptor.append(buffer, withPresentationTime: pts)
                frameIdx += 1
            }

            writerInput.markAsFinished()
            writer.finishWriting {
                if writer.status != .completed {
                    renderError = writer.error
                        ?? RenderError.writingFailed("status \(writer.status.rawValue)")
                }
                sema.signal()
            }
        }

        sema.wait()

        if let err = renderError {
            throw err
        }
        if writer.status != .completed {
            throw RenderError.writingFailed("writer ended with status \(writer.status.rawValue)")
        }
    }

    // MARK: - Pixel buffer rendering

    private static func makePixelBuffer(
        alpha: Double,
        frameA: PoseFrame,
        frameB: PoseFrame,
        size: Int,
        attributes: [String: Any]
    ) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            size, size,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard let pb = pixelBuffer else {
            throw RenderError.writingFailed("CVPixelBufferCreate returned nil")
        }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pb) else {
            throw RenderError.writingFailed("nil base address")
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: baseAddress,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw RenderError.writingFailed("CGContext creation failed")
        }

        drawFrame(ctx: ctx, alpha: alpha, frameA: frameA, frameB: frameB, size: CGFloat(size))

        return pb
    }

    private static func drawFrame(
        ctx: CGContext,
        alpha: Double,
        frameA: PoseFrame,
        frameB: PoseFrame,
        size: CGFloat
    ) {
        // Dark background
        ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0))
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

        // Helper: interpolated joint position in screen coords.
        // Vision coords: origin bottom-left → CGContext with (0,0) at bottom-left
        // requires no Y-flip (CGContext default origin is bottom-left for CoreGraphics).
        func screenPt(_ key: String) -> CGPoint? {
            guard let jA = frameA.joints[key],
                  let jB = frameB.joints[key] else {
                // Fall back to whichever side has the joint
                if let jA = frameA.joints[key] {
                    return CGPoint(x: CGFloat(jA.x) * size, y: CGFloat(jA.y) * size)
                }
                if let jB = frameB.joints[key] {
                    return CGPoint(x: CGFloat(jB.x) * size, y: CGFloat(jB.y) * size)
                }
                return nil
            }
            let x = CGFloat(jA.x) + CGFloat(alpha) * CGFloat(jB.x - jA.x)
            let y = CGFloat(jA.y) + CGFloat(alpha) * CGFloat(jB.y - jA.y)
            // Vision bottom-left → CGContext bottom-left: y stays as-is
            return CGPoint(x: x * size, y: y * size)
        }

        // Draw bones
        ctx.setStrokeColor(CGColor(red: 0.9, green: 0.85, blue: 0.2, alpha: 0.85))
        ctx.setLineWidth(3.0)
        ctx.setLineCap(.round)
        for (a, b) in bones {
            guard let pa = screenPt(a), let pb = screenPt(b) else { continue }
            ctx.move(to: pa)
            ctx.addLine(to: pb)
            ctx.strokePath()
        }

        // Draw joints (accent color dots)
        let allKeys = Set(frameA.joints.keys).union(frameB.joints.keys)
        ctx.setFillColor(CGColor(red: 0.3, green: 1.0, blue: 0.6, alpha: 1.0))
        for key in allKeys {
            guard let p = screenPt(key) else { continue }
            let r: CGFloat = 5
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
    }
}
