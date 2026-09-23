import AlarmKit
import Foundation
import SwiftUI

/// Metadata attached to every AlarmKit alarm so the system UI and intents can
/// identify which `WakeAlarm` it belongs to.
struct PushUpAlarmMetadata: AlarmMetadata {
    var wakeAlarmID: UUID
    var requiredReps: Int
    /// 0 for the main alarm, 1... for follow-up alarms.
    var nagCount: Int
}

/// A snapshot of an alarm known to the system, stripped of AlarmKit types.
struct SystemAlarm: Hashable {
    var id: UUID
    var isAlerting: Bool
}

enum AlarmAuthorization {
    case notDetermined, authorized, denied
}

/// Thin wrapper around `AlarmManager`. Everything AlarmKit-specific lives here.
@MainActor
final class AlarmScheduler {
    private let manager = AlarmManager.shared

    var authorization: AlarmAuthorization {
        switch manager.authorizationState {
        case .authorized: .authorized
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    /// Asks for permission the first time; afterwards just reports the stored answer.
    func ensureAuthorized() async throws -> Bool {
        switch manager.authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await manager.requestAuthorization() == .authorized
        @unknown default:
            return false
        }
    }

    /// Schedules (or replaces) the system alarm for a `WakeAlarm`.
    func schedule(_ alarm: WakeAlarm) async throws {
        let time = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
        let recurrence: Alarm.Schedule.Relative.Recurrence = alarm.weekdays.isEmpty
            ? .never
            : .weekly(alarm.weekdays.sorted().map(\.localeWeekday))
        let schedule = Alarm.Schedule.relative(.init(time: time, repeats: recurrence))
        try await scheduleSystemAlarm(
            id: alarm.id,
            schedule: schedule,
            title: alarm.label,
            metadata: PushUpAlarmMetadata(wakeAlarmID: alarm.id, requiredReps: alarm.requiredReps, nagCount: 0)
        )
    }

    /// Schedules a one-off follow-up alarm that fires at `date`. Returns its AlarmKit id.
    func scheduleNag(wakeAlarmID: UUID, requiredReps: Int, nagCount: Int, at date: Date, title: String) async throws -> UUID {
        let id = UUID()
        try await scheduleSystemAlarm(
            id: id,
            schedule: .fixed(date),
            title: "\(title) – push-ups still due",
            metadata: PushUpAlarmMetadata(wakeAlarmID: wakeAlarmID, requiredReps: requiredReps, nagCount: nagCount)
        )
        return id
    }

    private func scheduleSystemAlarm(id: UUID, schedule: Alarm.Schedule, title: String, metadata: PushUpAlarmMetadata) async throws {
        let stopButton = AlarmButton(text: "Stop", textColor: .white, systemImageName: "xmark")
        let pushUpButton = AlarmButton(text: "Push-ups", textColor: .white, systemImageName: "figure.strengthtraining.traditional")
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource("\(title)"),
            stopButton: stopButton,
            secondaryButton: pushUpButton,
            secondaryButtonBehavior: .custom
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: metadata,
            tintColor: Color.orange
        )
        let configuration = AlarmManager.AlarmConfiguration(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(wakeAlarmID: metadata.wakeAlarmID, alarmKitID: id),
            secondaryIntent: StartPushUpsIntent(wakeAlarmID: metadata.wakeAlarmID, alarmKitID: id),
            sound: .default
        )
        _ = try await manager.schedule(id: id, configuration: configuration)
    }

    func cancel(id: UUID) {
        try? manager.cancel(id: id)
    }

    /// Silences an alarm that is currently ringing. Harmless for alarms that are not.
    func stop(id: UUID) {
        try? manager.stop(id: id)
    }

    func currentAlarms() -> [SystemAlarm] {
        ((try? manager.alarms) ?? []).map { SystemAlarm(id: $0.id, isAlerting: $0.state == .alerting) }
    }

    /// Emits the full alarm list whenever the system reports a change.
    var updates: AsyncStream<[SystemAlarm]> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    for try await alarms in AlarmManager.shared.alarmUpdates {
                        continuation.yield(alarms.map { SystemAlarm(id: $0.id, isAlerting: $0.state == .alerting) })
                    }
                } catch {
                    // The sequence ended; the app re-reads `currentAlarms()` on the next activation anyway.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
