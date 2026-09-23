import AVFoundation
import Foundation
import Observation
import QuartzCore
import UIKit

/// Drives one camera session: frames in, rep count and feedback out.
@MainActor
@Observable
final class PushUpSessionModel {
    private(set) var reps = 0
    private(set) var feedback: PushUpCounter.Feedback = .notVisible
    private(set) var pose: BodyPose?
    private(set) var frameSize: CGSize = .zero
    /// nil until the permission check finishes.
    private(set) var cameraAuthorized: Bool?

    let camera = CameraManager()
    private let detector = PoseDetector()
    private let sound = AlarmSoundPlayer()
    private var counter = PushUpCounter()
    private let startedAt = Date()

    var elapsed: TimeInterval { Date.now.timeIntervalSince(startedAt) }

    func start(useFrontCamera: Bool, playAlarmSound: Bool) async {
        UIApplication.shared.isIdleTimerDisabled = true
        if playAlarmSound { sound.play() }

        let authorized = await CameraManager.requestAccess()
        cameraAuthorized = authorized
        guard authorized else { return }

        camera.frameHandler = { [weak self] buffer in
            guard let self else { return }
            // Runs on the capture queue; Vision is synchronous and fast enough for every frame.
            let pose = self.detector.detect(in: buffer)
            let size = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
            let time = CACurrentMediaTime()
            Task { @MainActor in self.ingest(pose: pose, frameSize: size, at: time) }
        }
        camera.configure(position: useFrontCamera ? .front : .back)
        camera.start()
    }

    private func ingest(pose: BodyPose?, frameSize: CGSize, at time: TimeInterval) {
        self.pose = pose
        self.frameSize = frameSize
        feedback = counter.process(pose, at: time)
        reps = counter.reps
    }

    func stop() {
        camera.stop()
        sound.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
