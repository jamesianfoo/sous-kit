import SwiftUI

struct AlarmEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WakeAlarm
    @State private var time: Date
    let isNew: Bool

    init(alarm: WakeAlarm, isNew: Bool) {
        _draft = State(initialValue: alarm)
        _time = State(initialValue: Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: .now) ?? .now)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }
                Section("Repeat") {
                    HStack {
                        ForEach(Weekday.allCases) { day in
                            let selected = draft.weekdays.contains(day)
                            Button {
                                if selected { draft.weekdays.remove(day) } else { draft.weekdays.insert(day) }
                            } label: {
                                Text(day.letter)
                                    .font(.subheadline.bold())
                                    .frame(width: 36, height: 36)
                                    .background(selected ? Color.accentColor : Color(.tertiarySystemFill))
                                    .foregroundStyle(selected ? Color.white : Color.primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(day.shortName)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Text(draft.repeatText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Push-ups to turn it off") {
                    Stepper("\(draft.requiredReps) push-ups", value: $draft.requiredReps, in: 1...100)
                }
                Section("Label") {
                    TextField("Label", text: $draft.label)
                }
                if !isNew {
                    Section {
                        Button("Delete alarm", role: .destructive) {
                            store.delete(draft)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New alarm" : "Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
                        draft.hour = components.hour ?? draft.hour
                        draft.minute = components.minute ?? draft.minute
                        draft.isEnabled = true
                        if draft.label.trimmingCharacters(in: .whitespaces).isEmpty { draft.label = "Wake up" }
                        let alarm = draft
                        Task { await store.upsert(alarm) }
                        dismiss()
                    }
                }
            }
        }
    }
}
