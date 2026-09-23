import AlarmKit
import AppIntents
import Foundation

/// Runs when the user taps **Stop** on the system alarm UI.
///
/// Stopping is allowed (iOS requires a stop button) but it is not free:
/// the dismissal is reported to the circle and a follow-up alarm is armed.
struct StopAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop alarm"
    static let description = IntentDescription("Stops the alarm. Skipping the push-ups is reported to your circle.")
    static let isDiscoverable = false

    @Parameter(title: "Alarm")
    var wakeAlarmID: String

    @Parameter(title: "System alarm")
    var alarmKitID: String

    init() {}

    init(wakeAlarmID: UUID, alarmKitID: UUID) {
        self.wakeAlarmID = wakeAlarmID.uuidString
        self.alarmKitID = alarmKitID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let alarmKitID = UUID(uuidString: alarmKitID) {
            try? AlarmManager.shared.stop(id: alarmKitID)
        }
        if let wakeAlarmID = UUID(uuidString: wakeAlarmID), let alarmKitID = UUID(uuidString: alarmKitID) {
            await AppStore.shared.handleAlarmStopped(wakeAlarmID: wakeAlarmID, alarmKitID: alarmKitID)
        }
        return .result()
    }
}

/// Runs when the user taps **Push-ups** on the system alarm UI: opens the app
/// straight into the camera challenge.
struct StartPushUpsIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Do push-ups"
    static let description = IntentDescription("Opens the camera so you can do your push-ups.")
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Alarm")
    var wakeAlarmID: String

    @Parameter(title: "System alarm")
    var alarmKitID: String

    init() {}

    init(wakeAlarmID: UUID, alarmKitID: UUID) {
        self.wakeAlarmID = wakeAlarmID.uuidString
        self.alarmKitID = alarmKitID.uuidString
    }

    func perform() async throws -> some IntentResult {
        if let wakeAlarmID = UUID(uuidString: wakeAlarmID) {
            await AppStore.shared.beginChallenge(wakeAlarmID: wakeAlarmID, alarmKitID: UUID(uuidString: alarmKitID))
        }
        return .result()
    }
}
