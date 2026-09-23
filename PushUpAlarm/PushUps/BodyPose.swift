import CoreGraphics

/// Body joints the counter cares about. Independent of Vision so the counter can be unit-tested.
enum BodyJoint: String, CaseIterable, Hashable {
    case nose, neck
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip, root
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
}

struct PosePoint: Hashable {
    /// Normalised to the frame, origin top-left, y grows downwards (screen convention).
    var location: CGPoint
    var confidence: Float
}

struct BodyPose: Hashable {
    var joints: [BodyJoint: PosePoint]

    subscript(joint: BodyJoint) -> PosePoint? { joints[joint] }

    /// Bones to draw on the overlay.
    static let bones: [(BodyJoint, BodyJoint)] = [
        (.nose, .neck),
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]
}
