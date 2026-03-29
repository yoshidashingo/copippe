import Foundation
import AppKit
import Observation

@Observable
final class SnippetManager {
    private(set) var folders: [SnippetFolder] = []

    private var fileURL: URL {
        let container = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = container.appendingPathComponent("copippe", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("snippets.json")
    }

    init() {
        load()
    }

    // MARK: - Folder Operations

    @discardableResult
    func addFolder(name: String) -> SnippetFolder {
        let folder = SnippetFolder(name: name)
        folders.append(folder)
        save()
        return folder
    }

    func renameFolder(id: UUID, name: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = name
        save()
    }

    func deleteFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        save()
    }

    func moveFolder(from sourceIndex: Int, to destinationIndex: Int) {
        guard folders.indices.contains(sourceIndex),
              destinationIndex >= 0, destinationIndex <= folders.count else { return }
        let folder = folders.remove(at: sourceIndex)
        let adjustedIndex = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        folders.insert(folder, at: min(adjustedIndex, folders.count))
        save()
    }

    // MARK: - Snippet Operations

    @discardableResult
    func addSnippet(folderID: UUID, title: String, content: String) -> Snippet? {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }) else { return nil }
        let snippet = Snippet(title: title, content: content)
        folders[folderIndex].snippets.append(snippet)
        save()
        return snippet
    }

    func updateSnippet(id: UUID, title: String? = nil, content: String? = nil, hotkey: HotkeyBinding? = nil) {
        for folderIndex in folders.indices {
            if let snippetIndex = folders[folderIndex].snippets.firstIndex(where: { $0.id == id }) {
                if let title = title {
                    folders[folderIndex].snippets[snippetIndex].title = title
                }
                if let content = content {
                    folders[folderIndex].snippets[snippetIndex].content = content
                }
                // hotkey can be set to nil to clear, so we handle it separately
                folders[folderIndex].snippets[snippetIndex].hotkey = hotkey
                save()
                return
            }
        }
    }

    func setSnippetHotkey(id: UUID, hotkey: HotkeyBinding?) {
        for folderIndex in folders.indices {
            if let snippetIndex = folders[folderIndex].snippets.firstIndex(where: { $0.id == id }) {
                folders[folderIndex].snippets[snippetIndex].hotkey = hotkey
                save()
                return
            }
        }
    }

    func deleteSnippet(id: UUID) {
        for folderIndex in folders.indices {
            folders[folderIndex].snippets.removeAll { $0.id == id }
        }
        save()
    }

    func moveSnippet(id: UUID, toFolderID: UUID) {
        var snippet: Snippet?
        for folderIndex in folders.indices {
            if let snippetIndex = folders[folderIndex].snippets.firstIndex(where: { $0.id == id }) {
                snippet = folders[folderIndex].snippets.remove(at: snippetIndex)
                break
            }
        }
        guard let snippet = snippet,
              let targetIndex = folders.firstIndex(where: { $0.id == toFolderID }) else { return }
        folders[targetIndex].snippets.append(snippet)
        save()
    }

    func reorderSnippet(folderID: UUID, from sourceIndex: Int, to destinationIndex: Int) {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }) else { return }
        let snippets = folders[folderIndex].snippets
        guard snippets.indices.contains(sourceIndex),
              destinationIndex >= 0, destinationIndex <= snippets.count else { return }
        let snippet = folders[folderIndex].snippets.remove(at: sourceIndex)
        let adjustedIndex = destinationIndex > sourceIndex ? destinationIndex - 1 : destinationIndex
        folders[folderIndex].snippets.insert(snippet, at: min(adjustedIndex, folders[folderIndex].snippets.count))
        save()
    }

    // MARK: - Search

    func search(_ query: String) -> [Snippet] {
        guard !query.isEmpty else {
            return folders.flatMap { $0.snippets }
        }
        let lowercased = query.lowercased()
        return folders.flatMap { $0.snippets }.filter { snippet in
            snippet.title.lowercased().contains(lowercased) ||
            snippet.content.lowercased().contains(lowercased)
        }
    }

    // MARK: - Lookup

    func snippet(for id: UUID) -> Snippet? {
        for folder in folders {
            if let snippet = folder.snippets.first(where: { $0.id == id }) {
                return snippet
            }
        }
        return nil
    }

    func allSnippetsWithHotkeys() -> [(Snippet, HotkeyBinding)] {
        folders.flatMap { $0.snippets }.compactMap { snippet in
            guard let hotkey = snippet.hotkey else { return nil }
            return (snippet, hotkey)
        }
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder().encode(folders)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best-effort persistence
        }
    }

    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            folders = try JSONDecoder().decode([SnippetFolder].self, from: data)
        } catch {
            folders = []
        }
    }
}
