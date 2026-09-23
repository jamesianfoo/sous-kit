import CoreGraphics
import Testing
@testable import PushUpAlarm

struct PushUpCounterTests {
    /// Builds a side-on pose. The wrist sits on the "floor" at y = 0.8 and the shoulder directly above it;
    /// the elbow is placed so the elbow angle is exactly `elbowAngle`.
    private func pose(elbowAngle: Double, shoulderY: Double, torsoTilt: Double = 0, confidence: Float = 0.9) -> BodyPose {
        let floorY = 0.8
        let shoulder = CGPoint(x: 0.5, y: shoulderY)
        let wrist = CGPoint(x: 0.5, y: floorY)
        let half = (floorY - shoulderY) / 2
        let offset = elbowAngle >= 179.9 ? 0 : half / tan(elbowAngle / 2 * .pi / 180)
        let elbow = CGPoint(x: 0.5 + offset, y: (shoulderY + floorY) / 2)
        let tilt = torsoTilt * .pi / 180
        let hip = CGPoint(x: shoulder.x + 0.3 * cos(tilt), y: shoulder.y + 0.3 * sin(tilt))
        func p(_ point: CGPoint) -> PosePoint { PosePoint(location: point, confidence: confidence) }
        return BodyPose(joints: [
            .leftShoulder: p(shoulder), .leftElbow: p(elbow), .leftWrist: p(wrist), .leftHip: p(hip),
            .rightShoulder: p(shoulder), .rightElbow: p(elbow), .rightWrist: p(wrist), .rightHip: p(hip),
        ])
    }

    /// Feeds the same pose for `frames` frames, 0.1 s apart, and returns the advanced clock.
    private func feed(_ counter: inout PushUpCounter, _ pose: BodyPose?, from time: Double, frames: Int = 5) -> Double {
        var t = time
        for _ in 0..<frames {
            t += 0.1
            counter.process(pose, at: t)
        }
        return t
    }

    @Test func countsAFullRep() {
        var counter = PushUpCounter()
        var t = feed(&counter, pose(elbowAngle: 175, shoulderY: 0.5), from: 0)
        #expect(counter.phase == .up)
        t = feed(&counter, pose(elbowAngle: 80, shoulderY: 0.7), from: t)
        #expect(counter.phase == .down)
        t = feed(&counter, pose(elbowAngle: 175, shoulderY: 0.5), from: t)
        #expect(counter.reps == 1)
        #expect(counter.feedback == .repCounted || counter.feedback == .goDown)
        t = feed(&counter, pose(elbowAngle: 80, shoulderY: 0.7), from: t)
        _ = feed(&counter, pose(elbowAngle: 175, shoulderY: 0.5), from: t)
        #expect(counter.reps == 2)
    }

    @Test func standingUpDoesNotCount() {
        var counter = PushUpCounter()
        var t = feed(&counter, pose(elbowAngle: 175, shoulderY: 0.5, torsoTilt: 85), from: 0)
        t = feed(&counter, pose(elbowAngle: 80, shoulderY: 0.7, torsoTilt: 85), from: t)
        _ = feed(&counter, pose(elbowAngle: 175, shoulderY: 0.5, torsoTilt: 85), from: t)
        #expect(counter.reps == 0)
        #expect(counter.feedback == .getIntoPlank)
    }

    @Test func bendingArmsWithoutLoweringBodyDoesNotCount() {
        var counter = PushUpCounter()
        var t = feed(&counter, pose(elbowAngle: 175, shoulderY: 0.5), from: 0)
        t = feed(&counter, pose(elbowAngle: 80, shoulderY: 0.5), from: t)
        #expect(counter.phase == .up)
        _ = feed(&counter, pose(elbowAngle: 175, shoulderY: 0.5), from: t)
        #expect(counter.reps == 0)
    }

    @Test func jitterFasterThanMinimumPhaseDurationDoesNotCount() {
        var counter = PushUpCounter(config: .init(smoothing: 1))
        counter.process(pose(elbowAngle: 175, shoulderY: 0.5), at: 0.0)
        counter.process(pose(elbowAngle: 80, shoulderY: 0.7), at: 0.05)
        counter.process(pose(elbowAngle: 175, shoulderY: 0.5), at: 0.10)
        #expect(counter.reps == 0)
    }

    @Test func lowConfidencePoseIsNotVisible() {
        var counter = PushUpCounter()
        let feedback = counter.process(pose(elbowAngle: 175, shoulderY: 0.5, confidence: 0.1), at: 1)
        #expect(feedback == .notVisible)
        #expect(counter.process(nil, at: 2) == .notVisible)
    }

    @Test func handsAboveShouldersAreRejected() {
        var counter = PushUpCounter()
        // Flip the geometry so the wrist is above the shoulder on screen.
        var upsideDown = pose(elbowAngle: 175, shoulderY: 0.5)
        for (joint, point) in upsideDown.joints {
            upsideDown.joints[joint] = PosePoint(location: CGPoint(x: point.location.x, y: 1 - point.location.y), confidence: point.confidence)
        }
        #expect(counter.process(upsideDown, at: 1) == .handsOnFloor)
    }

    @Test func geometryHelpers() {
        let angle = PushUpCounter.angle(at: .zero, from: CGPoint(x: 1, y: 0), to: CGPoint(x: 0, y: 1))
        #expect(abs(angle - 90) < 0.001)
        #expect(abs(PushUpCounter.torsoTilt(shoulder: .zero, hip: CGPoint(x: 1, y: 0))) < 0.001)
        #expect(abs(PushUpCounter.torsoTilt(shoulder: .zero, hip: CGPoint(x: -1, y: 0))) < 0.001)
        #expect(abs(PushUpCounter.torsoTilt(shoulder: .zero, hip: CGPoint(x: 0, y: 1)) - 90) < 0.001)
    }
}
