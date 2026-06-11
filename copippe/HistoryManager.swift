import Foundation
import AppKit
import Observation

@Observable
final class HistoryManager {
    private(set) var entries: [HistoryEntry] = []
    let imageStore: ImageStore
    private let appState: AppState
    private let store: JSONFileStore<[HistoryEntry]>

    init(appState: AppState, fileURL: URL? = nil, imageStore: ImageStore = ImageStore()) {
        self.appState = appState
        self.imageStore = imageStore
        self.store = JSONFileStore(
            fileURL: fileURL ?? AppDirectories.appSupport().appendingPathComponent("history.json")
        )
        load()
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
        let maxCount = max(1, appState.maxHistoryCount)
        while entries.count > maxCount {
            let removed = entries.removeLast()
            if case .image(_, let imageID) = removed {
                imageStore.delete(id: imageID)
            }
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

    func copy(_ entry: HistoryEntry) {
        switch entry {
        case .text(_, let string):
            Pasteboard.copy(string)
        case .image(_, let imageID):
            if let image = imageStore.load(id: imageID) {
                Pasteboard.copy(image)
            }
        }
    }

    func search(_ query: String) -> [HistoryEntry] {
        guard !query.isEmpty else { return entries }
        let lowercased = query.lowercased()
        return entries.filter { entry in
            entry.textValue?.lowercased().contains(lowercased) == true
        }
    }

    func save() {
        store.save(entries)
    }

    func load() {
        // Try v2 format first
        if let decoded = store.load() {
            entries = decoded
            return
        }

        // Fallback: migrate from v1 format ([String])
        if let data = store.loadData(),
           let legacyEntries = try? JSONDecoder().decode([String].self, from: data) {
            entries = legacyEntries.compactMap { text in
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : .text(value: trimmed)
            }
            save() // Re-save in v2 format
            return
        }

        entries = []
    }
}
