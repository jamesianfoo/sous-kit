import SwiftUI

struct CircleView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.isInCircle {
                    CircleFeedView()
                } else {
                    JoinCircleView()
                }
            }
            .navigationTitle(store.settings.circleName ?? "Circle")
        }
    }
}

private struct JoinCircleView: View {
    @Environment(AppStore.self) private var store
    @State private var circleName = ""
    @State private var inviteCode = ""

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Text("Friends in your circle see whether you did your push-ups, and get a notification the moment you hit Stop instead.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Your name") {
                TextField("How friends will see you", text: $store.settings.displayName)
            }
            Section("Start a circle") {
                TextField("Circle name", text: $circleName)
                Button("Create circle") {
                    Task { await store.createCircle(named: circleName.isEmpty ? "Morning crew" : circleName) }
                }
                .disabled(store.circleBusy)
            }
            Section("Join a circle") {
                TextField("Invite code", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Join") {
                    Task { await store.joinCircle(code: inviteCode) }
                }
                .disabled(store.circleBusy || inviteCode.isEmpty)
            }
            if store.circleBusy {
                Section { ProgressView("Talking to iCloud…") }
            }
        }
    }
}

private struct CircleFeedView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmLeave = false

    private var inviteText: String {
        "Join my push-up alarm circle \"\(store.settings.circleName ?? "")\" with code \(store.settings.circleCode ?? "")"
    }

    var body: some View {
        List {
            Section("Invite code") {
                HStack {
                    Text(store.settings.circleCode ?? "")
                        .font(.system(.title, design: .monospaced).bold())
                    Spacer()
                    ShareLink(item: inviteText) {
                        Label("Invite", systemImage: "square.and.arrow.up")
                    }
                }
                if !store.members.isEmpty {
                    Text(store.members.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Latest") {
                if store.feed.isEmpty {
                    Text("Nothing yet. Results appear here as soon as an alarm goes off.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.feed) { post in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: post.status.symbol)
                            .foregroundStyle(color(for: post.status))
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.displayName).font(.headline)
                            Text(post.summary)
                            Text(post.date, format: .relative(presentation: .named))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            if !store.outbox.isEmpty {
                Section {
                    Label("\(store.outbox.count) result\(store.outbox.count == 1 ? "" : "s") waiting to upload", systemImage: "arrow.up.circle")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Leave circle", role: .destructive) { confirmLeave = true }
            }
        }
        .refreshable {
            await store.flushOutbox()
            await store.refreshFeed()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await store.flushOutbox()
                        await store.refreshFeed()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .confirmationDialog("Leave this circle?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { Task { await store.leaveCircle() } }
        }
    }

    private func color(for status: WorkoutStatus) -> Color {
        switch status {
        case .completed: .green
        case .dismissed: .orange
        case .skipped: .red
        case .practice: .blue
        }
    }
}
