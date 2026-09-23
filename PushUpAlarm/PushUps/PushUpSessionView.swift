import SwiftUI

/// Full-screen camera view that counts push-ups. In challenge mode it cannot be dismissed
/// until the reps are done or the user explicitly gives up.
struct PushUpSessionView: View {
    enum Mode {
        case challenge(Challenge)
        case practice
    }

    let mode: Mode
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var model = PushUpSessionModel()
    @State private var showGiveUp = false
    @State private var result: (reps: Int, duration: TimeInterval)?

    private var isChallenge: Bool {
        if case .challenge = mode { return true }
        return false
    }

    private var target: Int {
        if case .challenge(let challenge) = mode { return challenge.requiredReps }
        return store.settings.defaultReps
    }

    private var tint: Color {
        switch model.feedback {
        case .repCounted: .green
        case .goDown, .pushUp: .orange
        case .notVisible, .getIntoPlank, .handsOnFloor: .red
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if model.cameraAuthorized == false {
                cameraDenied
            } else {
                CameraPreviewView(camera: model.camera)
                    .ignoresSafeArea()
                PoseOverlayView(pose: model.pose, frameSize: model.frameSize, tint: tint)
                    .ignoresSafeArea()
                hud
            }
            if let result {
                resultCard(reps: result.reps, duration: result.duration)
            }
        }
        .statusBarHidden()
        .interactiveDismissDisabled(isChallenge)
        .task {
            await model.start(useFrontCamera: store.settings.useFrontCamera, playAlarmSound: isChallenge)
        }
        .onDisappear { model.stop() }
        .onChange(of: model.reps) { _, reps in
            if reps >= target, result == nil {
                Task { await finish(reps: reps) }
            }
        }
        .confirmationDialog("Give up on today's push-ups?", isPresented: $showGiveUp, titleVisibility: .visible) {
            Button("Skip push-ups (your circle will know)", role: .destructive) {
                Task {
                    model.stop()
                    await store.abandonChallenge()
                    dismiss()
                }
            }
            Button("Keep going", role: .cancel) {}
        }
    }

    // MARK: Pieces

    private var hud: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(isChallenge ? "Wake up!" : "Practice")
                    .font(.title2.bold())
                Text(isChallenge
                     ? "\(target) push-ups turn the alarm off"
                     : "Lie side-on to the camera with your whole body in frame")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Spacer()

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(model.reps)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.reps)
                Text("/ \(target)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .shadow(radius: 8)

            Text(model.feedback.message)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(tint.opacity(0.85), in: Capsule())
                .animation(.easeInOut(duration: 0.2), value: model.feedback)

            Spacer()

            footer
        }
        .foregroundStyle(.white)
        .padding()
    }

    @ViewBuilder
    private var footer: some View {
        if isChallenge {
            Button("Give up") { showGiveUp = true }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
        } else {
            Button("End practice") {
                let reps = model.reps
                let duration = model.elapsed
                model.stop()
                store.recordPractice(reps: reps, duration: duration)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var cameraDenied: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
            Text("Camera access is needed to count push-ups.")
                .multilineTextAlignment(.center)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .buttonStyle(.borderedProminent)
            }
            if !isChallenge {
                Button("Close") { dismiss() }
            }
        }
        .foregroundStyle(.white)
        .padding()
    }

    private func resultCard(reps: Int, duration: TimeInterval) -> some View {
        let text = "\(store.settings.resolvedDisplayName) " + ResultText.summary(
            status: isChallenge ? .completed : .practice, reps: reps, requiredReps: target, duration: duration
        )
        return VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text(isChallenge ? "Alarm off!" : "Nice work!")
                .font(.largeTitle.bold())
            Text("\(reps) push-ups in \(ResultText.duration(duration))")
                .foregroundStyle(.secondary)
            ShareLink(item: text) {
                Label("Share with friends", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding()
    }

    private func finish(reps: Int) async {
        let duration = model.elapsed
        model.stop()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        result = (reps, duration)
        switch mode {
        case .challenge:
            await store.completeChallenge(reps: reps, duration: duration)
        case .practice:
            store.recordPractice(reps: reps, duration: duration)
        }
    }
}
