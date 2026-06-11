import Foundation
import AppKit
import Observation

@Observable
final class SnippetManager {
    static let defaultFolderName = "New Folder"
    private static let legacyDefaultFolderName = "New Name"

    private(set) var folders: [SnippetFolder] = []
    private let store: JSONFileStore<[SnippetFolder]>

    init(fileURL: URL? = nil) {
        self.store = JSONFileStore(
            fileURL: fileURL ?? AppDirectories.appSupport().appendingPathComponent("snippets.json")
        )
        load()
    }

    // MARK: - Folder Operations

    @discardableResult
    func addFolder(name: String = SnippetManager.defaultFolderName) -> SnippetFolder {
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

    // MARK: - Snippet Operations

    @discardableResult
    func addSnippet(folderID: UUID, title: String, content: String) -> Snippet? {
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderID }) else { return nil }
        let snippet = Snippet(title: title, content: content)
        folders[folderIndex].snippets.append(snippet)
        save()
        return snippet
    }

    func updateSnippet(id: UUID, title: String? = nil, content: String? = nil) {
        for folderIndex in folders.indices {
            if let snippetIndex = folders[folderIndex].snippets.firstIndex(where: { $0.id == id }) {
                if let title = title {
                    folders[folderIndex].snippets[snippetIndex].title = title
                }
                if let content = content {
                    folders[folderIndex].snippets[snippetIndex].content = content
                }
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

    // MARK: - Persistence

    func save() {
        store.save(folders)
    }

    func load() {
        folders = store.load() ?? []
        migrateLegacyDefaultFolderNames()
    }

    private func migrateLegacyDefaultFolderNames() {
        var didMigrate = false
        for index in folders.indices
        where folders[index].name == Self.legacyDefaultFolderName && folders[index].snippets.isEmpty {
            folders[index].name = Self.defaultFolderName
            didMigrate = true
        }
        if didMigrate {
            save()
        }
    }
}
