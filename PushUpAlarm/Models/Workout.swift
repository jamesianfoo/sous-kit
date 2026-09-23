import Foundation

enum WorkoutStatus: String, Codable, Hashable {
    /// Required push-ups were counted by the camera and the alarm was turned off.
    case completed
    /// The user pressed Stop on the alarm instead of doing push-ups.
    case dismissed
    /// The user gave up or ran out of time; the push-ups never happened.
    case skipped
    /// A voluntary session from the Practice button.
    case practice

    var title: String {
        switch self {
        case .completed: "Completed"
        case .dismissed: "Dismissed alarm"
        case .skipped: "Skipped"
        case .practice: "Practice"
        }
    }

    var symbol: String {
        switch self {
        case .completed: "checkmark.circle.fill"
        case .dismissed: "bell.slash.fill"
        case .skipped: "xmark.circle.fill"
        case .practice: "figure.strengthtraining.traditional"
        }
    }
}

/// A finished session, kept locally for history and streaks.
struct WorkoutRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var alarmID: UUID?
    var date = Date()
    var status: WorkoutStatus
    var reps: Int
    var requiredReps: Int
    var durationSeconds: Double
}

/// An alarm that has fired and whose push-ups are not done yet.
/// While one exists the app shows nothing but the push-up screen.
struct Challenge: Identifiable, Codable, Hashable {
    var wakeAlarmID: UUID
    var requiredReps: Int
    var startedAt: Date
    /// Follow-up ("nag") alarms scheduled so far.
    var nagCount = 0
    /// Times the user hit Stop instead of doing the push-ups.
    var dismissals = 0
    /// AlarmKit id of the follow-up alarm currently waiting to fire.
    var pendingNagAlarmID: UUID?

    var id: UUID { wakeAlarmID }
}

struct UserSettings: Codable, Hashable {
    var displayName = ""
    var defaultReps = 10
    var useFrontCamera = true
    /// Minutes between follow-up alarms after the user stops or abandons the alarm.
    var nagIntervalMinutes = 3
    /// How many follow-up alarms to fire before the day counts as skipped.
    var maxNags = 5
    var circleCode: String?
    var circleName: String?

    var resolvedDisplayName: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Someone" : trimmed
    }
}

/// A result shared with the accountability circle.
struct WorkoutPost: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var circleCode: String
    var userID: String
    var displayName: String
    var status: WorkoutStatus
    var reps: Int
    var requiredReps: Int
    var durationSeconds: Double
    var date = Date()

    var summary: String {
        ResultText.summary(status: status, reps: reps, requiredReps: requiredReps, duration: durationSeconds)
    }
}

enum ResultText {
    static func duration(_ seconds: Double) -> String {
        Duration.seconds(max(0, seconds)).formatted(.time(pattern: .minuteSecond))
    }

    static func summary(status: WorkoutStatus, reps: Int, requiredReps: Int, duration: Double) -> String {
        switch status {
        case .completed:
            return "did \(reps) push-ups in \(Self.duration(duration)) to turn the alarm off 💪"
        case .dismissed:
            return "hit Stop on the alarm without doing push-ups 😴"
        case .skipped:
            return "skipped today's \(requiredReps) push-ups ❌"
        case .practice:
            return "practised \(reps) push-ups"
        }
    }
}
