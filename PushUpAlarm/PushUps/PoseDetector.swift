import CoreVideo
import Vision

/// Runs Apple's on-device body pose model on camera frames.
/// Used from a single serial capture queue, so no locking is needed.
final class PoseDetector: @unchecked Sendable {
    private let request = VNDetectHumanBodyPoseRequest()

    private static let jointMap: [(VNHumanBodyPoseObservation.JointName, BodyJoint)] = [
        (.nose, .nose), (.neck, .neck),
        (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
        (.leftElbow, .leftElbow), (.rightElbow, .rightElbow),
        (.leftWrist, .leftWrist), (.rightWrist, .rightWrist),
        (.leftHip, .leftHip), (.rightHip, .rightHip), (.root, .root),
        (.leftKnee, .leftKnee), (.rightKnee, .rightKnee),
        (.leftAnkle, .leftAnkle), (.rightAnkle, .rightAnkle),
    ]

    /// The frame is expected to already be rotated and mirrored to match what the user sees on screen.
    func detect(in pixelBuffer: CVPixelBuffer) -> BodyPose? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first,
              let points = try? observation.recognizedPoints(.all)
        else { return nil }

        var joints: [BodyJoint: PosePoint] = [:]
        for (visionName, joint) in Self.jointMap {
            guard let point = points[visionName], point.confidence > 0 else { continue }
            // Vision uses a bottom-left origin; flip to the screen convention.
            let location = CGPoint(x: point.location.x, y: 1 - point.location.y)
            joints[joint] = PosePoint(location: location, confidence: point.confidence)
        }
        return joints.isEmpty ? nil : BodyPose(joints: joints)
    }
}
