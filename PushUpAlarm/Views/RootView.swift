import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    /// Snapshot of the challenge being shown, so the result card can stay up after the store clears it.
    @State private var presentedChallenge: Challenge?

    var body: some View {
        @Bindable var store = store
        TabView {
            Tab("Alarms", systemImage: "alarm") { AlarmListView() }
            Tab("Circle", systemImage: "person.3") { CircleView() }
            Tab("History", systemImage: "chart.bar") { HistoryView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
        .onChange(of: store.challenge?.id, initial: true) { _, id in
            if id != nil, presentedChallenge == nil {
                presentedChallenge = store.challenge
            }
        }
        .fullScreenCover(item: $presentedChallenge) { challenge in
            PushUpSessionView(mode: .challenge(challenge))
                .environment(store)
        }
        .fullScreenCover(isPresented: $store.practicePresented) {
            PushUpSessionView(mode: .practice)
                .environment(store)
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
