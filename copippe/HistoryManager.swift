import Foundation
import AppKit
import Observation

@Observable
final class HistoryManager {
    private(set) var entries: [HistoryEntry] = []
    let imageStore = ImageStore()
    private let appState: AppState

    private var fileURL: URL {
        let container = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = container.appendingPathComponent("copippe", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("history.json")
    }

    init(appState: AppState) {
        self.appState = appState
        load()
    }

    // Test-only initializer
    init(appState: AppState, fileURL: URL) {
        self.appState = appState
        self._testFileURL = fileURL
        load()
    }

    private var _testFileURL: URL?
    private var resolvedFileURL: URL {
        _testFileURL ?? fileURL
    }

    func addEntry(_ entry: HistoryEntry) {
        switch entry {
        case .text(_, let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            let normalizedEntry = HistoryEntry.text(value: trimmed)

            // Prevent duplicate consecutive entries
            if entries.first == normalizedEntry { return }

            // Remove existing duplicate text
            entries.removeAll { $0 == normalizedEntry }

            entries.insert(normalizedEntry, at: 0)

        case .image:
            entries.insert(entry, at: 0)
        }

        // Enforce max entries
        let maxCount = appState.maxHistoryCount
        while entries.count > maxCount {
            let removed = entries.removeLast()
            if case .image(_, let imageID) = removed {
                imageStore.delete(id: imageID)
            }
        }

        save()
    }

    func removeEntry(at index: Int) {
        guard entries.indices.contains(index) else { return }
        let removed = entries.remove(at: index)
        if case .image(_, let imageID) = removed {
            imageStore.delete(id: imageID)
        }
        save()
    }

    func clearAll() {
        // Delete all image files
        for entry in entries {
            if case .image(_, let imageID) = entry {
                imageStore.delete(id: imageID)
            }
        }
        entries.removeAll()
        save()
    }

    func copyToClipboard(at index: Int) {
        guard entries.indices.contains(index) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch entries[index] {
        case .text(_, let string):
            pasteboard.setString(string, forType: .string)
        case .image(_, let imageID):
            if let image = imageStore.load(id: imageID),
               let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
            }
        }
    }

    func search(_ query: String) -> [Int] {
        guard !query.isEmpty else { return Array(entries.indices) }
        let lowercased = query.lowercased()
        return entries.indices.filter { index in
            if case .text(_, let string) = entries[index] {
                return string.lowercased().contains(lowercased)
            }
            return false
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: resolvedFileURL, options: .atomic)
        } catch {
            // Best-effort persistence
        }
    }

    func load() {
        let url = resolvedFileURL
        guard let data = try? Data(contentsOf: url) else {
            entries = []
            return
        }

        // Try v2 format first
        if let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            entries = decoded
            return
        }

        // Fallback: migrate from v1 format ([String])
        if let legacyEntries = try? JSONDecoder().decode([String].self, from: data) {
            entries = legacyEntries.map { .text(value: $0) }
            save() // Re-save in v2 format
            return
        }

        entries = []
    }
}
