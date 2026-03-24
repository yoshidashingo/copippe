import Foundation
import AppKit
import Observation

@Observable
final class HistoryManager {
    private(set) var entries: [String] = []
    static let maxEntries = 20

    private var fileURL: URL {
        let container = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = container.appendingPathComponent("copippe", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("history.json")
    }

    init() {
        load()
    }

    func addEntry(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Prevent duplicate consecutive entries
        if entries.first == trimmed {
            return
        }

        // Remove existing duplicate if present elsewhere
        entries.removeAll { $0 == trimmed }

        entries.insert(trimmed, at: 0)

        // Enforce max entries
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }

        save()
    }

    func removeEntry(at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    func copyToClipboard(at index: Int) {
        guard entries.indices.contains(index) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entries[index], forType: .string)
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Silently fail - history persistence is best-effort
        }
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([String].self, from: data)
        } catch {
            entries = []
        }
    }
}
