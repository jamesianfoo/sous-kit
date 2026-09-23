import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let camera: CameraManager

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        camera.attach(previewLayer: view.previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Draws the detected skeleton over the camera preview.
struct PoseOverlayView: View {
    let pose: BodyPose?
    /// Pixel size of the analysed frame, used to reproduce the preview's aspect-fill crop.
    let frameSize: CGSize
    let tint: Color

    var body: some View {
        Canvas { context, size in
            guard let pose, frameSize.width > 0, frameSize.height > 0 else { return }
            let scale = max(size.width / frameSize.width, size.height / frameSize.height)
            let drawn = CGSize(width: frameSize.width * scale, height: frameSize.height * scale)
            let offset = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)

            func point(_ joint: BodyJoint) -> CGPoint? {
                guard let p = pose[joint], p.confidence >= 0.3 else { return nil }
                return CGPoint(x: offset.x + p.location.x * drawn.width, y: offset.y + p.location.y * drawn.height)
            }

            for (a, b) in BodyPose.bones {
                guard let pa = point(a), let pb = point(b) else { continue }
                var path = Path()
                path.move(to: pa)
                path.addLine(to: pb)
                context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            for joint in BodyJoint.allCases {
                guard let p = point(joint) else { continue }
                context.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }
}
