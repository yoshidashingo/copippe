import Foundation
import Testing
@testable import copippe

@Suite("SnippetManager Tests")
struct SnippetManagerTests {

    private func makeManager() -> SnippetManager {
        SnippetManager(fileURL: temporarySnippetsURL())
    }

    private func temporarySnippetsURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("copippe-tests-\(UUID().uuidString).json")
    }

    @Test("Add folder")
    func addFolder() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Test Folder")
        #expect(manager.folders.count == 1)
        #expect(manager.folders[0].name == "Test Folder")
        #expect(manager.folders[0].id == folder.id)
    }

    @Test("Add folder uses shared default name")
    func addFolderUsesDefaultName() {
        let manager = makeManager()

        let folder = manager.addFolder()

        #expect(folder.name == SnippetManager.defaultFolderName)
        #expect(folder.name == "New Folder")
        #expect(manager.folders[0].name == SnippetManager.defaultFolderName)
    }

    @Test("Rename folder")
    func renameFolder() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Old Name")
        manager.renameFolder(id: folder.id, name: "New Name")

        #expect(manager.folders[0].name == "New Name")
    }

    @Test("Managers can use isolated storage files")
    func managersCanUseIsolatedStorageFiles() {
        let firstURL = temporarySnippetsURL()
        let secondURL = temporarySnippetsURL()
        let firstManager = SnippetManager(fileURL: firstURL)
        let secondManager = SnippetManager(fileURL: secondURL)

        firstManager.addFolder(name: "First")
        secondManager.addFolder(name: "Second")

        #expect(SnippetManager(fileURL: firstURL).folders.map(\.name) == ["First"])
        #expect(SnippetManager(fileURL: secondURL).folders.map(\.name) == ["Second"])
    }

    @Test("Load migrates empty legacy default folder name")
    func loadMigratesEmptyLegacyDefaultFolderName() throws {
        let fileURL = temporarySnippetsURL()
        let legacyFolders = [SnippetFolder(name: "New Name")]
        let data = try JSONEncoder().encode(legacyFolders)
        try data.write(to: fileURL)

        let manager = SnippetManager(fileURL: fileURL)

        #expect(manager.folders.map(\.name) == [SnippetManager.defaultFolderName])

        let persistedData = try Data(contentsOf: fileURL)
        let persistedFolders = try JSONDecoder().decode([SnippetFolder].self, from: persistedData)
        #expect(persistedFolders.map(\.name) == [SnippetManager.defaultFolderName])
    }

    @Test("Load preserves non-empty legacy-named folders")
    func loadPreservesNonEmptyLegacyNamedFolders() throws {
        let fileURL = temporarySnippetsURL()
        let legacyFolders = [
            SnippetFolder(
                name: "New Name",
                snippets: [Snippet(title: "Saved Snippet", content: "Keep this folder name")]
            )
        ]
        let data = try JSONEncoder().encode(legacyFolders)
        try data.write(to: fileURL)

        let manager = SnippetManager(fileURL: fileURL)

        #expect(manager.folders.map(\.name) == ["New Name"])
    }

    @Test("Delete folder")
    func deleteFolder() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "To Delete")
        manager.deleteFolder(id: folder.id)

        #expect(manager.folders.isEmpty)
    }

    @Test("Add snippet to folder")
    func addSnippet() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Folder")
        let snippet = manager.addSnippet(folderID: folder.id, title: "Title", content: "Content")

        #expect(snippet != nil)
        #expect(manager.folders[0].snippets.count == 1)
        #expect(manager.folders[0].snippets[0].title == "Title")
        #expect(manager.folders[0].snippets[0].content == "Content")
    }

    @Test("Update snippet")
    func updateSnippet() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Folder")
        let snippet = manager.addSnippet(folderID: folder.id, title: "Old", content: "Old Content")!

        manager.updateSnippet(id: snippet.id, title: "New", content: "New Content")

        #expect(manager.folders[0].snippets[0].title == "New")
        #expect(manager.folders[0].snippets[0].content == "New Content")
    }

    @Test("Update snippet preserves existing hotkey")
    func updateSnippetPreservesHotkey() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Folder")
        let snippet = manager.addSnippet(folderID: folder.id, title: "Title", content: "Content")!
        let binding = HotkeyBinding(keyCode: 9, modifiers: 0)
        manager.setSnippetHotkey(id: snippet.id, hotkey: binding)

        manager.updateSnippet(id: snippet.id, title: "New Title", content: "New Content")

        #expect(manager.folders[0].snippets[0].hotkey == binding)
    }

    @Test("Delete snippet")
    func deleteSnippet() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Folder")
        let snippet = manager.addSnippet(folderID: folder.id, title: "Title", content: "Content")!

        manager.deleteSnippet(id: snippet.id)

        #expect(manager.folders[0].snippets.isEmpty)
    }

    @Test("Search snippets by title and content")
    func searchSnippets() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Folder")
        manager.addSnippet(folderID: folder.id, title: "Email Template", content: "Dear Sir/Madam")
        manager.addSnippet(folderID: folder.id, title: "Code", content: "import Foundation")
        manager.addSnippet(folderID: folder.id, title: "Greeting", content: "Dear friend")

        let results = manager.search("dear")
        #expect(results.count == 2)
    }

}
