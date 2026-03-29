import Testing
@testable import copippe

@Suite("SnippetManager Tests")
struct SnippetManagerTests {

    private func makeManager() -> SnippetManager {
        let manager = SnippetManager()
        // Clear all folders
        while !manager.folders.isEmpty {
            manager.deleteFolder(id: manager.folders[0].id)
        }
        return manager
    }

    @Test("Add folder")
    func addFolder() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Test Folder")
        #expect(manager.folders.count == 1)
        #expect(manager.folders[0].name == "Test Folder")
        #expect(manager.folders[0].id == folder.id)
    }

    @Test("Rename folder")
    func renameFolder() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Old Name")
        manager.renameFolder(id: folder.id, name: "New Name")

        #expect(manager.folders[0].name == "New Name")
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

    @Test("Delete snippet")
    func deleteSnippet() {
        let manager = makeManager()

        let folder = manager.addFolder(name: "Folder")
        let snippet = manager.addSnippet(folderID: folder.id, title: "Title", content: "Content")!

        manager.deleteSnippet(id: snippet.id)

        #expect(manager.folders[0].snippets.isEmpty)
    }

    @Test("Move snippet between folders")
    func moveSnippet() {
        let manager = makeManager()

        let folder1 = manager.addFolder(name: "Source")
        let folder2 = manager.addFolder(name: "Destination")
        let snippet = manager.addSnippet(folderID: folder1.id, title: "Moving", content: "Content")!

        manager.moveSnippet(id: snippet.id, toFolderID: folder2.id)

        let srcFolder = manager.folders.first { $0.id == folder1.id }!
        let dstFolder = manager.folders.first { $0.id == folder2.id }!
        #expect(srcFolder.snippets.isEmpty)
        #expect(dstFolder.snippets.count == 1)
        #expect(dstFolder.snippets[0].title == "Moving")
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

    @Test("Move folder reorders list")
    func moveFolder() {
        let manager = makeManager()

        manager.addFolder(name: "A")
        manager.addFolder(name: "B")
        manager.addFolder(name: "C")

        manager.moveFolder(from: 2, to: 0)

        #expect(manager.folders[0].name == "C")
        #expect(manager.folders[1].name == "A")
        #expect(manager.folders[2].name == "B")
    }
}
