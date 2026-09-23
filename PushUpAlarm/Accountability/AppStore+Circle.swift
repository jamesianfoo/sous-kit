import Foundation
import UIKit
import UserNotifications

/// Accountability circle: a group of friends who see each other's morning results
/// and get a push notification when someone finishes, stops the alarm, or skips.
extension AppStore {
    var isInCircle: Bool { settings.circleCode != nil }

    func createCircle(named name: String) async {
        circleBusy = true
        defer { circleBusy = false }
        do {
            try await ensureCloudAccount()
            let code = InviteCode.generate()
            let userID = try await circleService.userID()
            try await circleService.createCircle(name: name, code: code)
            try await circleService.join(code: code, userID: userID, displayName: settings.resolvedDisplayName)
            try await circleService.subscribe(code: code)
            settings.circleCode = code
            settings.circleName = name
            await requestPushPermission()
            await refreshFeed()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func joinCircle(code rawCode: String) async {
        circleBusy = true
        defer { circleBusy = false }
        let code = InviteCode.normalize(rawCode)
        guard code.count == InviteCode.length else {
            errorMessage = "Invite codes are \(InviteCode.length) letters and digits."
            return
        }
        do {
            try await ensureCloudAccount()
            guard let circle = try await circleService.fetchCircle(code: code) else {
                errorMessage = "No circle found for code \(code)."
                return
            }
            let userID = try await circleService.userID()
            try await circleService.join(code: code, userID: userID, displayName: settings.resolvedDisplayName)
            try await circleService.subscribe(code: code)
            settings.circleCode = code
            settings.circleName = circle.name
            await requestPushPermission()
            await refreshFeed()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func leaveCircle() async {
        guard let code = settings.circleCode else { return }
        circleBusy = true
        defer { circleBusy = false }
        if let userID = try? await circleService.userID() {
            try? await circleService.leave(code: code, userID: userID)
        }
        try? await circleService.unsubscribe(code: code)
        settings.circleCode = nil
        settings.circleName = nil
        feed = []
        members = []
        outbox.removeAll()
        save()
    }

    func refreshFeed() async {
        guard let code = settings.circleCode else { return }
        do {
            async let posts = circleService.feed(code: code)
            async let names = circleService.members(code: code)
            feed = try await posts
            members = try await names
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    /// Queues a result for the circle. Delivery happens in `flushOutbox`, which retries until it succeeds.
    func enqueuePost(status: WorkoutStatus, reps: Int, requiredReps: Int, duration: TimeInterval) {
        guard let code = settings.circleCode else { return }
        outbox.append(WorkoutPost(
            circleCode: code,
            userID: "",
            displayName: settings.resolvedDisplayName,
            status: status,
            reps: reps,
            requiredReps: requiredReps,
            durationSeconds: duration
        ))
    }

    func flushOutbox() async {
        guard !outbox.isEmpty, settings.circleCode != nil else { return }
        guard let userID = try? await circleService.userID() else { return }
        var remaining: [WorkoutPost] = []
        for var post in outbox {
            post.userID = userID
            do {
                try await circleService.post(post)
            } catch {
                remaining.append(post)
            }
        }
        outbox = remaining
        save()
        if remaining.isEmpty { await refreshFeed() }
    }

    private func ensureCloudAccount() async throws {
        let status = try await circleService.accountStatus()
        guard status == .available else { throw CircleError.noICloudAccount }
    }

    private func requestPushPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func friendlyMessage(for error: Error) -> String {
        if let circleError = error as? CircleError { return circleError.localizedDescription }
        return "Circle sync failed: \(error.localizedDescription)"
    }
}

enum CircleError: LocalizedError {
    case noICloudAccount

    var errorDescription: String? {
        switch self {
        case .noICloudAccount:
            "Sign in to iCloud on this device to use a circle."
        }
    }
}

enum InviteCode {
    static let length = 6
    /// No 0/O or 1/I so codes are easy to read out loud.
    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { alphabet.contains($0) })
    }
}
