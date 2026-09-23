import AVFoundation
import UIKit

/// Owns the capture session and hands every frame to `frameHandler` on a background queue.
/// Frames are rotated to the interface orientation and mirrored for the front camera so that
/// Vision coordinates line up with the preview layer.
final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    /// Called on the video queue for every frame.
    var frameHandler: ((CVPixelBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "PushUpAlarm.camera.session")
    private let videoQueue = DispatchQueue(label: "PushUpAlarm.camera.video")
    private let output = AVCaptureVideoDataOutput()
    private var device: AVCaptureDevice?
    private var isConfigured = false

    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    /// Called from the preview view once its layer exists (main thread).
    func attach(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        if let device { setUpRotation(for: device) }
    }

    func configure(position: AVCaptureDevice.Position) {
        sessionQueue.async { [self] in
            guard !isConfigured else { return }
            session.beginConfiguration()
            defer { session.commitConfiguration() }

            // Audio is handled by the alarm sound player; keep the capture session out of it.
            session.automaticallyConfiguresApplicationAudioSession = false
            if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
            } else if session.canSetSessionPreset(.vga640x480) {
                session.sessionPreset = .vga640x480
            }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                    ?? AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input)
            else { return }
            session.addInput(input)

            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: videoQueue)
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)

            if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = device.position == .front
            }

            self.device = device
            isConfigured = true
            DispatchQueue.main.async { self.setUpRotation(for: device) }
        }
    }

    /// Keeps both the preview and the analysed frames level with the interface orientation.
    private func setUpRotation(for device: AVCaptureDevice) {
        guard let previewLayer, rotationCoordinator == nil else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] coordinator, _ in
            self?.apply(rotationAngle: coordinator.videoRotationAngleForHorizonLevelPreview)
        }
    }

    private func apply(rotationAngle angle: CGFloat) {
        if let connection = previewLayer?.connection, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        sessionQueue.async { [self] in
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }

    func start() {
        sessionQueue.async { [self] in
            if isConfigured, !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        frameHandler?(buffer)
    }
}
