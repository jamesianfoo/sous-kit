import SwiftUI

struct AlarmListView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: WakeAlarm?

    var body: some View {
        NavigationStack {
            Group {
                if store.alarms.isEmpty {
                    ContentUnavailableView {
                        Label("No alarms", systemImage: "alarm")
                    } description: {
                        Text("Add an alarm. The only way to turn it off is to do your push-ups on camera.")
                    } actions: {
                        Button("Add alarm") { editing = newAlarm() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if store.alarmPermissionDenied {
                            Section {
                                Label("Alarm permission is off. Enable it in Settings so alarms can ring.", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        Section {
                            ForEach(store.alarms) { alarm in
                                AlarmRow(alarm: alarm) { editing = alarm }
                            }
                            .onDelete { offsets in
                                let doomed = offsets.map { store.alarms[$0] }
                                doomed.forEach { store.delete($0) }
                            }
                        } footer: {
                            Text("Streak: \(store.currentStreak) day\(store.currentStreak == 1 ? "" : "s")")
                        }
                    }
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.practicePresented = true
                    } label: {
                        Label("Practice", systemImage: "camera.viewfinder")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = newAlarm()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editing) { alarm in
                AlarmEditorView(alarm: alarm, isNew: !store.alarms.contains(where: { $0.id == alarm.id }))
            }
        }
    }

    private func newAlarm() -> WakeAlarm {
        WakeAlarm(requiredReps: store.settings.defaultReps)
    }
}

private struct AlarmRow: View {
    @Environment(AppStore.self) private var store
    let alarm: WakeAlarm
    let onTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.timeText)
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .foregroundStyle(alarm.isEnabled ? .primary : .secondary)
                Text("\(alarm.label) · \(alarm.repeatText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label("\(alarm.requiredReps) push-ups to stop", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Enabled", isOn: Binding(
                get: { alarm.isEnabled },
                set: { enabled in Task { await store.setEnabled(enabled, for: alarm.id) } }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
