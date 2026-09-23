import Foundation

/// A user-configured alarm. Its `id` doubles as the AlarmKit alarm identifier.
struct WakeAlarm: Identifiable, Codable, Hashable {
    var id = UUID()
    var label = "Wake up"
    var hour = 7
    var minute = 0
    /// Empty means the alarm fires once at the next occurrence of the time.
    var weekdays: Set<Weekday> = Weekday.weekdays
    var requiredReps = 10
    var isEnabled = true

    var timeText: String {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    var repeatText: String {
        if weekdays.isEmpty { return "Once" }
        if weekdays == Weekday.everyDay { return "Every day" }
        if weekdays == Weekday.weekdays { return "Weekdays" }
        if weekdays == Weekday.weekend { return "Weekends" }
        return weekdays.sorted().map(\.shortName).joined(separator: " ")
    }
}
