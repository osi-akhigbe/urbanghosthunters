//
//  ErrorLogger.swift
//  urbanghosthunters
//

import Foundation

@MainActor
final class ErrorLogger {
    static let shared = ErrorLogger()

    private let storageKey = "cached_error_logs"

    private init() {}

    func log(_ error: Error, context: String) {
        let entry: [String: Any] = [
            "context": context,
            "message": error.localizedDescription,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        var logs = loadLogs()
        logs.append(entry)
        // Keep max 100 entries locally
        if logs.count > 100 { logs.removeFirst(logs.count - 100) }
        saveLogs(logs)
        print("⚠️ [\(context)] \(error.localizedDescription)")
    }

    func loadLogs() -> [[String: Any]] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let logs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return logs
    }

    private func saveLogs(_ logs: [[String: Any]]) {
        if let data = try? JSONSerialization.data(withJSONObject: logs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func clearLogs() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}