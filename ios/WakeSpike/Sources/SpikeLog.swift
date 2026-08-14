import Foundation

/// Timestamped on-device event log for the spike session.
///
/// The Mac/iPhone session produces findings that have to be written down
/// accurately — "the alarm fired around 8-ish and I think the second one still
/// went off" is not a result. Every scheduling call, intent launch, scan and
/// cancellation lands here with a second-precision timestamp, and the whole log
/// exports as text to paste straight into docs/alarmkit-findings.md.
@MainActor
@Observable
final class SpikeLog {

    static let shared = SpikeLog()

    private(set) var entries: [Entry] = []

    struct Entry: Identifiable {
        let id = UUID()
        let at: Date
        let message: String
    }

    private let storageKey = "wakespike.log"
    private let maxEntries = 500

    private init() {
        if let raw = UserDefaults.standard.array(forKey: storageKey) as? [[String: Any]] {
            entries = raw.compactMap { dict in
                guard
                    let interval = dict["at"] as? TimeInterval,
                    let message = dict["message"] as? String
                else { return nil }
                return Entry(at: Date(timeIntervalSince1970: interval), message: message)
            }
        }
    }

    func log(_ message: String) {
        let entry = Entry(at: Date(), message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        persist()
        print("[SpikeLog] \(Self.timestamp(entry.at)) \(message)")
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    private func persist() {
        let raw = entries.map { ["at": $0.at.timeIntervalSince1970, "message": $0.message] }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }

    /// Second precision, matching the product requirement that wake times are
    /// stored to the second rather than the minute.
    static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    /// Full log as plain text for sharing off the device.
    var exportText: String {
        let header = """
        WakeSpike Phase 0 log
        exported: \(Self.timestamp(Date()))
        timezone: \(TimeZone.current.identifier)
        entries: \(entries.count)

        """
        let body = entries
            .map { "\(Self.timestamp($0.at))  \($0.message)" }
            .joined(separator: "\n")
        return header + body
    }
}
