import Foundation
import Observation
import UIKit

/// Single source of truth for the app. Lives on the main actor; the AlarmKit intents
/// run inside the app process, so they talk to the same instance.
@MainActor
@Observable
final class AppStore {
    static let shared = AppStore()

    var alarms: [WakeAlarm]
    var history: [WorkoutRecord]
    /// Non-nil while an alarm has fired and its push-ups are still owed.
    var challenge: Challenge?
    var settings: UserSettings { didSet { save() } }
    var outbox: [WorkoutPost]

    var practicePresented = false
    var errorMessage: String?
    var alarmPermissionDenied = false

    // Accountability circle
    var feed: [WorkoutPost] = []
    var members: [String] = []
    var circleBusy = false

    let scheduler = AlarmScheduler()
    let circleService = CloudKitCircleService()
    private let persistence = Persistence()
    private var observingSystemAlarms = false

    private init() {
        let data = persistence.load()
        alarms = data.alarms
        history = data.history
        challenge = data.challenge
        settings = data.settings
        outbox = data.outbox
    }

    func save() {
        persistence.save(AppData(alarms: alarms, history: history, challenge: challenge, settings: settings, outbox: outbox))
    }

    // MARK: - Lifecycle

    /// Called once when the UI appears.
    func start() async {
        alarmPermissionDenied = scheduler.authorization == .denied
        await refreshFromSystem()
        observeSystemAlarms()
        await flushOutbox()
        if settings.circleCode != nil { await refreshFeed() }
    }

    /// Called whenever the app becomes active.
    func refreshFromSystem() async {
        reconcile(with: scheduler.currentAlarms())
        await finalizeExpiredChallenge()
    }

    private func observeSystemAlarms() {
        guard !observingSystemAlarms else { return }
        observingSystemAlarms = true
        Task { [weak self] in
            guard let updates = self?.scheduler.updates else { return }
            for await alarms in updates {
                self?.reconcile(with: alarms)
            }
        }
    }

    private func reconcile(with systemAlarms: [SystemAlarm]) {
        let systemIDs = Set(systemAlarms.map(\.id))

        // A one-shot alarm disappears from the system after it has rung; mirror that in the UI.
        for index in alarms.indices
        where alarms[index].isEnabled
            && alarms[index].weekdays.isEmpty
            && !systemIDs.contains(alarms[index].id)
            && challenge?.wakeAlarmID != alarms[index].id {
            alarms[index].isEnabled = false
        }

        // If an alarm rings while the app is on screen, jump straight into the challenge.
        // Never do this in the background: stopping the alarm there would silence it for good.
        if UIApplication.shared.applicationState == .active {
            for system in systemAlarms where system.isAlerting {
                if alarms.contains(where: { $0.id == system.id }) {
                    Task { await beginChallenge(wakeAlarmID: system.id, alarmKitID: system.id) }
                } else if let challenge, challenge.pendingNagAlarmID == system.id {
                    Task { await beginChallenge(wakeAlarmID: challenge.wakeAlarmID, alarmKitID: system.id) }
                }
            }
        }
        save()
    }

    // MARK: - Alarms

    func upsert(_ alarm: WakeAlarm) async {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
        alarms.sort { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        await syncSystemAlarm(alarm)
        save()
    }

    func setEnabled(_ enabled: Bool, for id: UUID) async {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].isEnabled = enabled
        if !enabled, let challenge, challenge.wakeAlarmID == id {
            // Switching the alarm off mid-challenge is giving up.
            await abandonChallenge()
        }
        await syncSystemAlarm(alarms[index])
        save()
    }

    func delete(_ alarm: WakeAlarm) {
        alarms.removeAll { $0.id == alarm.id }
        scheduler.cancel(id: alarm.id)
        save()
    }

    private func syncSystemAlarm(_ alarm: WakeAlarm) async {
        guard alarm.isEnabled else {
            scheduler.cancel(id: alarm.id)
            return
        }
        do {
            guard try await scheduler.ensureAuthorized() else {
                alarmPermissionDenied = true
                errorMessage = "Alarm permission is off. Turn it on in Settings so the alarm can ring."
                if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
                    alarms[index].isEnabled = false
                }
                return
            }
            alarmPermissionDenied = false
            try await scheduler.schedule(alarm)
        } catch {
            errorMessage = "Couldn't schedule the alarm: \(error.localizedDescription)"
        }
    }

    // MARK: - Challenge (alarm fired, push-ups owed)

    private func challengeOrNew(for alarm: WakeAlarm) -> Challenge {
        if let challenge, challenge.wakeAlarmID == alarm.id { return challenge }
        return Challenge(wakeAlarmID: alarm.id, requiredReps: alarm.requiredReps, startedAt: .now)
    }

    /// The user tapped "Push-ups" on the alarm, or the alarm rang with the app open.
    func beginChallenge(wakeAlarmID: UUID, alarmKitID: UUID?) async {
        guard let alarm = alarms.first(where: { $0.id == wakeAlarmID }) else { return }
        if let alarmKitID { scheduler.stop(id: alarmKitID) }
        var current = challengeOrNew(for: alarm)
        if let alarmKitID, current.pendingNagAlarmID == alarmKitID {
            current.pendingNagAlarmID = nil
        }
        challenge = current
        // Backstop: if they close the app without finishing, a follow-up alarm rings.
        await armFollowUpAlarm()
        save()
    }

    /// The user tapped "Stop" on the alarm without doing the push-ups.
    func handleAlarmStopped(wakeAlarmID: UUID, alarmKitID: UUID) async {
        guard let alarm = alarms.first(where: { $0.id == wakeAlarmID }) else { return }
        var current = challengeOrNew(for: alarm)
        if current.pendingNagAlarmID == alarmKitID {
            current.pendingNagAlarmID = nil
        }
        current.dismissals += 1
        challenge = current

        if current.dismissals == 1 {
            enqueuePost(status: .dismissed, reps: 0, requiredReps: current.requiredReps, duration: 0)
        }
        await armFollowUpAlarm()
        if challenge?.pendingNagAlarmID == nil {
            // No follow-ups left: the push-ups are not going to happen.
            finish(status: .skipped, reps: 0, duration: Date.now.timeIntervalSince(current.startedAt))
        }
        save()
        await flushOutbox()
    }

    private func armFollowUpAlarm() async {
        guard var current = challenge else { return }
        if let pending = current.pendingNagAlarmID {
            scheduler.cancel(id: pending)
            current.pendingNagAlarmID = nil
        }
        guard current.nagCount < settings.maxNags else {
            challenge = current
            return
        }
        let fireDate = Date.now.addingTimeInterval(TimeInterval(max(1, settings.nagIntervalMinutes) * 60))
        let label = alarms.first(where: { $0.id == current.wakeAlarmID })?.label ?? "Wake up"
        do {
            let id = try await scheduler.scheduleNag(
                wakeAlarmID: current.wakeAlarmID,
                requiredReps: current.requiredReps,
                nagCount: current.nagCount + 1,
                at: fireDate,
                title: label
            )
            current.pendingNagAlarmID = id
            current.nagCount += 1
        } catch {
            errorMessage = "Couldn't schedule the follow-up alarm: \(error.localizedDescription)"
        }
        challenge = current
    }

    /// The camera counted every required rep.
    func completeChallenge(reps: Int, duration: TimeInterval) async {
        finish(status: .completed, reps: reps, duration: duration)
        save()
        await flushOutbox()
    }

    /// The user explicitly gave up.
    func abandonChallenge() async {
        guard let current = challenge else { return }
        finish(status: .skipped, reps: 0, duration: Date.now.timeIntervalSince(current.startedAt))
        save()
        await flushOutbox()
    }

    private func finish(status: WorkoutStatus, reps: Int, duration: TimeInterval) {
        guard let current = challenge else { return }
        if let pending = current.pendingNagAlarmID { scheduler.cancel(id: pending) }
        scheduler.stop(id: current.wakeAlarmID)
        history.insert(
            WorkoutRecord(alarmID: current.wakeAlarmID, status: status, reps: reps,
                          requiredReps: current.requiredReps, durationSeconds: duration),
            at: 0
        )
        enqueuePost(status: status, reps: reps, requiredReps: current.requiredReps, duration: duration)
        if let index = alarms.firstIndex(where: { $0.id == current.wakeAlarmID }), alarms[index].weekdays.isEmpty {
            alarms[index].isEnabled = false
        }
        challenge = nil
    }

    /// A challenge that outlived every follow-up alarm (plus some slack) counts as skipped.
    private func finalizeExpiredChallenge() async {
        guard let current = challenge else { return }
        let followUps = TimeInterval((settings.maxNags + 1) * max(1, settings.nagIntervalMinutes) * 60)
        let grace = followUps + 15 * 60
        if Date.now.timeIntervalSince(current.startedAt) > grace {
            finish(status: .skipped, reps: 0, duration: Date.now.timeIntervalSince(current.startedAt))
            save()
            await flushOutbox()
        }
    }

    func recordPractice(reps: Int, duration: TimeInterval) {
        guard reps > 0 else { return }
        history.insert(WorkoutRecord(status: .practice, reps: reps, requiredReps: reps, durationSeconds: duration), at: 0)
        save()
    }

    // MARK: - Stats

    /// Consecutive days (ending today or yesterday) with a completed alarm challenge.
    var currentStreak: Int {
        let calendar = Calendar.current
        let days = Set(history.filter { $0.status == .completed }.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
