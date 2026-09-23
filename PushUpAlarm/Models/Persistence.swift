import Foundation

struct AppData: Codable {
    var alarms: [WakeAlarm] = []
    var history: [WorkoutRecord] = []
    var challenge: Challenge?
    var settings = UserSettings()
    /// Circle posts that have not reached CloudKit yet.
    var outbox: [WorkoutPost] = []
}

/// Single JSON file in the app's Documents folder. Small enough that whole-file writes are fine.
struct Persistence {
    private let url: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appending(path: "pushupalarm.json")
    }()

    func load() -> AppData {
        guard let data = try? Data(contentsOf: url) else { return AppData() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(AppData.self, from: data)) ?? AppData()
    }

    func save(_ data: AppData) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let encoded = try? encoder.encode(data) else { return }
        try? encoded.write(to: url, options: .atomic)
    }
}
