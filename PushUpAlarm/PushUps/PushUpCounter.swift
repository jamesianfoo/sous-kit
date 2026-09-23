import Foundation

/// Counts push-ups from a stream of body poses.
///
/// Anti-cheat rules, all of which must hold for a rep to count:
/// 1. Shoulder, elbow, wrist and hip on one side are visible with decent confidence.
/// 2. The torso (shoulder→hip) is roughly horizontal, i.e. the user is in a plank filmed side-on.
/// 3. The wrist is below the shoulder on screen: hands are on the floor.
/// 4. The elbow angle goes fully bent (down) → fully straight (up), with a minimum
///    time in each phase so jitter does not count.
/// 5. The shoulder actually drops towards the floor in the down phase, so bending
///    the arms without lowering the body does not count.
struct PushUpCounter {
    struct Config {
        /// Elbow angle (degrees) at or above which the arms count as straight.
        var upAngle: Double = 150
        /// Elbow angle (degrees) at or below which the arms count as bent.
        var downAngle: Double = 100
        var minConfidence: Float = 0.3
        /// Maximum torso angle from horizontal (degrees) to still count as a plank.
        var maxTorsoTilt: Double = 40
        /// Required shoulder drop in the down phase, as a fraction of upper-arm length.
        var minShoulderDropRatio: Double = 0.3
        /// Minimum time (seconds) between phase changes.
        var minPhaseDuration: TimeInterval = 0.25
        /// After this long without a usable pose the counter forgets the current phase.
        var poseTimeout: TimeInterval = 1.5
        /// Exponential smoothing factor for the elbow angle (1 = no smoothing).
        var smoothing: Double = 0.5
    }

    enum Phase: Equatable { case searching, up, down }

    enum Feedback: Equatable {
        case notVisible, getIntoPlank, handsOnFloor, goDown, pushUp, repCounted

        var message: String {
            switch self {
            case .notVisible: "Move back so your whole body is in view"
            case .getIntoPlank: "Get into a plank, side-on to the camera"
            case .handsOnFloor: "Hands on the floor"
            case .goDown: "Lower your chest"
            case .pushUp: "Push up!"
            case .repCounted: "Nice, keep going"
            }
        }
    }

    var config: Config
    private(set) var reps = 0
    private(set) var phase: Phase = .searching
    private(set) var feedback: Feedback = .notVisible
    private(set) var elbowAngle: Double?

    private var smoothedAngle: Double?
    private var upShoulderY: Double = 0
    private var upperArmLength: Double = 0
    private var lastPhaseChange: TimeInterval = 0
    private var lastValidPose: TimeInterval = 0

    init(config: Config = Config()) {
        self.config = config
    }

    mutating func reset() {
        reps = 0
        phase = .searching
        feedback = .notVisible
        elbowAngle = nil
        smoothedAngle = nil
    }

    /// Feed one frame's pose (or nil when nobody was detected). `time` is any monotonic clock in seconds.
    @discardableResult
    mutating func process(_ pose: BodyPose?, at time: TimeInterval) -> Feedback {
        guard let pose, let side = bestSide(in: pose) else {
            return poseLost(at: time)
        }
        lastValidPose = time

        let shoulder = side.shoulder.location
        let elbow = side.elbow.location
        let wrist = side.wrist.location
        let hip = side.hip.location

        // Rule 2: plank, filmed from the side.
        guard Self.torsoTilt(shoulder: shoulder, hip: hip) <= config.maxTorsoTilt else {
            phase = .searching
            smoothedAngle = nil
            return set(.getIntoPlank)
        }
        // Rule 3: hands on the floor.
        guard wrist.y > shoulder.y else {
            phase = .searching
            return set(.handsOnFloor)
        }

        let rawAngle = Self.angle(at: elbow, from: shoulder, to: wrist)
        let angle = smoothedAngle.map { $0 + config.smoothing * (rawAngle - $0) } ?? rawAngle
        smoothedAngle = angle
        elbowAngle = angle

        switch phase {
        case .searching:
            if angle >= config.upAngle {
                enterUp(shoulder: shoulder, elbow: elbow, at: time)
                return set(.goDown)
            }
            return set(.pushUp)

        case .up:
            if angle >= config.upAngle {
                // Track the latest fully-extended position as the reference for the drop check.
                upShoulderY = shoulder.y
                upperArmLength = Self.distance(shoulder, elbow)
                return set(.goDown)
            }
            let drop = shoulder.y - upShoulderY
            let deepEnough = drop >= config.minShoulderDropRatio * upperArmLength
            if angle <= config.downAngle, time - lastPhaseChange >= config.minPhaseDuration, deepEnough {
                phase = .down
                lastPhaseChange = time
                return set(.pushUp)
            }
            return set(.goDown)

        case .down:
            if angle >= config.upAngle, time - lastPhaseChange >= config.minPhaseDuration {
                reps += 1
                enterUp(shoulder: shoulder, elbow: elbow, at: time)
                return set(.repCounted)
            }
            return set(.pushUp)
        }
    }

    // MARK: - Helpers

    private struct Side {
        var shoulder: PosePoint
        var elbow: PosePoint
        var wrist: PosePoint
        var hip: PosePoint

        var score: Float { shoulder.confidence + elbow.confidence + wrist.confidence + hip.confidence }
    }

    private func side(_ pose: BodyPose, shoulder: BodyJoint, elbow: BodyJoint, wrist: BodyJoint, hip: BodyJoint) -> Side? {
        guard let s = pose[shoulder], let e = pose[elbow], let w = pose[wrist], let h = pose[hip],
              min(s.confidence, e.confidence, w.confidence, h.confidence) >= config.minConfidence
        else { return nil }
        return Side(shoulder: s, elbow: e, wrist: w, hip: h)
    }

    private func bestSide(in pose: BodyPose) -> Side? {
        let left = side(pose, shoulder: .leftShoulder, elbow: .leftElbow, wrist: .leftWrist, hip: .leftHip)
        let right = side(pose, shoulder: .rightShoulder, elbow: .rightElbow, wrist: .rightWrist, hip: .rightHip)
        switch (left, right) {
        case let (l?, r?): return l.score >= r.score ? l : r
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    private mutating func poseLost(at time: TimeInterval) -> Feedback {
        if time - lastValidPose > config.poseTimeout {
            phase = .searching
            smoothedAngle = nil
            elbowAngle = nil
        }
        return set(.notVisible)
    }

    private mutating func enterUp(shoulder: CGPoint, elbow: CGPoint, at time: TimeInterval) {
        phase = .up
        upShoulderY = shoulder.y
        upperArmLength = Self.distance(shoulder, elbow)
        lastPhaseChange = time
    }

    private mutating func set(_ feedback: Feedback) -> Feedback {
        self.feedback = feedback
        return feedback
    }

    /// Angle in degrees at `vertex` between the rays towards `a` and `b`.
    static func angle(at vertex: CGPoint, from a: CGPoint, to b: CGPoint) -> Double {
        let v1 = (x: a.x - vertex.x, y: a.y - vertex.y)
        let v2 = (x: b.x - vertex.x, y: b.y - vertex.y)
        let dot = v1.x * v2.x + v1.y * v2.y
        let magnitude = hypot(v1.x, v1.y) * hypot(v2.x, v2.y)
        guard magnitude > 0 else { return 180 }
        return acos(max(-1, min(1, dot / magnitude))) * 180 / .pi
    }

    /// Angle of the shoulder→hip line from horizontal, in degrees, 0...90.
    static func torsoTilt(shoulder: CGPoint, hip: CGPoint) -> Double {
        let degrees = abs(atan2(hip.y - shoulder.y, hip.x - shoulder.x)) * 180 / .pi
        return min(degrees, 180 - degrees)
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }
}
