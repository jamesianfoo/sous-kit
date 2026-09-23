import CloudKit
import Foundation

struct CircleInfo: Hashable {
    var code: String
    var name: String
}

/// Stores circles, members and posts in the app's public CloudKit database.
/// No server to run: every device talks to CloudKit directly and gets pushes via a query subscription.
final class CloudKitCircleService: Sendable {
    private enum RecordType {
        static let circle = "Circle"
        static let member = "Member"
        static let post = "WorkoutPost"
    }

    private var container: CKContainer { CKContainer.default() }
    private var database: CKDatabase { container.publicCloudDatabase }

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    /// Stable, anonymous identifier for the signed-in iCloud user.
    func userID() async throws -> String {
        try await container.userRecordID().recordName
    }

    // MARK: Circles

    private func circleRecordID(_ code: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "circle-\(code)")
    }

    func createCircle(name: String, code: String) async throws {
        let record = CKRecord(recordType: RecordType.circle, recordID: circleRecordID(code))
        record["name"] = name
        record["code"] = code
        _ = try await database.save(record)
    }

    func fetchCircle(code: String) async throws -> CircleInfo? {
        do {
            let record = try await database.record(for: circleRecordID(code))
            return CircleInfo(code: code, name: record["name"] as? String ?? "Circle")
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    // MARK: Members

    private func memberRecordID(code: String, userID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "member-\(code)-\(userID)")
    }

    func join(code: String, userID: String, displayName: String) async throws {
        let record = CKRecord(recordType: RecordType.member, recordID: memberRecordID(code: code, userID: userID))
        record["circleCode"] = code
        record["userID"] = userID
        record["displayName"] = displayName
        _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }

    func leave(code: String, userID: String) async throws {
        _ = try await database.deleteRecord(withID: memberRecordID(code: code, userID: userID))
    }

    func members(code: String) async throws -> [String] {
        let query = CKQuery(recordType: RecordType.member, predicate: NSPredicate(format: "circleCode == %@", code))
        let (results, _) = try await database.records(matching: query, resultsLimit: 100)
        return results
            .compactMap { _, result in try? result.get() }
            .compactMap { $0["displayName"] as? String }
            .sorted()
    }

    // MARK: Posts

    func post(_ post: WorkoutPost) async throws {
        let record = CKRecord(recordType: RecordType.post, recordID: CKRecord.ID(recordName: post.id))
        record["circleCode"] = post.circleCode
        record["userID"] = post.userID
        record["displayName"] = post.displayName
        record["status"] = post.status.rawValue
        record["reps"] = post.reps
        record["requiredReps"] = post.requiredReps
        record["durationSeconds"] = post.durationSeconds
        record["date"] = post.date
        // Denormalised so the push notification can quote it without a round trip.
        record["summary"] = post.summary
        _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }

    func feed(code: String) async throws -> [WorkoutPost] {
        let query = CKQuery(recordType: RecordType.post, predicate: NSPredicate(format: "circleCode == %@", code))
        let (results, _) = try await database.records(matching: query, resultsLimit: 200)
        return results
            .compactMap { _, result in try? result.get() }
            .compactMap(WorkoutPost.init(record:))
            .sorted { $0.date > $1.date }
    }

    // MARK: Push notifications

    private func subscriptionID(_ code: String) -> String { "circle-posts-\(code)" }

    /// One alert per new post in the circle, rendered by the system even when the app is closed.
    func subscribe(code: String) async throws {
        let subscription = CKQuerySubscription(
            recordType: RecordType.post,
            predicate: NSPredicate(format: "circleCode == %@", code),
            subscriptionID: subscriptionID(code),
            options: [.firesOnRecordCreation]
        )
        let info = CKSubscription.NotificationInfo()
        info.alertLocalizationKey = "CIRCLE_POST_ALERT"
        info.alertLocalizationArgs = ["displayName", "summary"]
        info.soundName = "default"
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        _ = try await database.save(subscription)
    }

    func unsubscribe(code: String) async throws {
        _ = try await database.deleteSubscription(withID: subscriptionID(code))
    }
}

extension WorkoutPost {
    init?(record: CKRecord) {
        guard let circleCode = record["circleCode"] as? String,
              let statusRaw = record["status"] as? String,
              let status = WorkoutStatus(rawValue: statusRaw)
        else { return nil }
        self.init(
            id: record.recordID.recordName,
            circleCode: circleCode,
            userID: record["userID"] as? String ?? "",
            displayName: record["displayName"] as? String ?? "Someone",
            status: status,
            reps: record["reps"] as? Int ?? 0,
            requiredReps: record["requiredReps"] as? Int ?? 0,
            durationSeconds: record["durationSeconds"] as? Double ?? 0,
            date: record["date"] as? Date ?? record.creationDate ?? .now
        )
    }
}
