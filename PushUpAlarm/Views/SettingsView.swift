import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Display name", text: $store.settings.displayName)
                }
                Section("Push-ups") {
                    Stepper("Default reps: \(store.settings.defaultReps)", value: $store.settings.defaultReps, in: 1...100)
                    Picker("Camera", selection: $store.settings.useFrontCamera) {
                        Text("Front").tag(true)
                        Text("Back").tag(false)
                    }
                    Button {
                        store.practicePresented = true
                    } label: {
                        Label("Practice with the camera", systemImage: "camera.viewfinder")
                    }
                }
                Section {
                    Stepper("Ring again after \(store.settings.nagIntervalMinutes) min", value: $store.settings.nagIntervalMinutes, in: 1...15)
                    Stepper("Up to \(store.settings.maxNags) times", value: $store.settings.maxNags, in: 0...10)
                } header: {
                    Text("If you hit Stop")
                } footer: {
                    Text("Stopping the alarm without push-ups tells your circle and makes the alarm ring again. After the last follow-up the day counts as skipped.")
                }
                Section("Permissions") {
                    LabeledContent("Alarms", value: alarmStatus)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open system Settings", destination: url)
                    }
                }
                Section("How it works") {
                    Text("Put the phone on the floor a couple of metres to your side, so the camera sees your whole body from the side. A rep counts only when your torso is horizontal, your hands are on the floor, your elbows bend past 100° and your shoulders actually drop.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var alarmStatus: String {
        switch store.scheduler.authorization {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .notDetermined: "Not asked yet"
        }
    }
}
