import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) private var store

    private var completed: Int { store.history.filter { $0.status == .completed }.count }
    private var skipped: Int { store.history.filter { $0.status == .skipped }.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        stat("Streak", value: "\(store.currentStreak)", symbol: "flame.fill", color: .orange)
                        stat("Done", value: "\(completed)", symbol: "checkmark.circle.fill", color: .green)
                        stat("Skipped", value: "\(skipped)", symbol: "xmark.circle.fill", color: .red)
                    }
                    .padding(.vertical, 4)
                }
                Section("Sessions") {
                    if store.history.isEmpty {
                        Text("No sessions yet.").foregroundStyle(.secondary)
                    }
                    ForEach(store.history) { record in
                        HStack(spacing: 12) {
                            Image(systemName: record.status.symbol)
                                .foregroundStyle(color(for: record.status))
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.status.title).font(.headline)
                                Text(detail(for: record))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(record.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func stat(_ title: String, value: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value).font(.title.bold().monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func detail(for record: WorkoutRecord) -> String {
        switch record.status {
        case .completed, .practice:
            "\(record.reps) push-ups in \(ResultText.duration(record.durationSeconds))"
        case .dismissed:
            "Stopped the alarm without push-ups"
        case .skipped:
            "\(record.requiredReps) push-ups were due"
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
