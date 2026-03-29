import Foundation
import Testing
@testable import copippe

@Suite("HistoryManager Tests")
struct HistoryManagerTests {

    private func makeManager() -> HistoryManager {
        let appState = AppState()
        let manager = HistoryManager(appState: appState)
        manager.clearAll()
        return manager
    }

    @Test("Add text entry inserts at beginning")
    func addTextEntry() {
        let manager = makeManager()

        manager.addEntry(.text(value: "first"))
        manager.addEntry(.text(value: "second"))

        #expect(manager.entries.count == 2)
        #expect(manager.entries[0] == .text(value: "second"))
        #expect(manager.entries[1] == .text(value: "first"))
    }

    @Test("Duplicate consecutive text entries are prevented")
    func duplicateConsecutive() {
        let manager = makeManager()

        manager.addEntry(.text(value: "hello"))
        manager.addEntry(.text(value: "hello"))

        #expect(manager.entries.count == 1)
    }

    @Test("Same text at different positions is deduplicated")
    func duplicateDedup() {
        let manager = makeManager()

        manager.addEntry(.text(value: "aaa"))
        manager.addEntry(.text(value: "bbb"))
        manager.addEntry(.text(value: "aaa"))

        #expect(manager.entries.count == 2)
        #expect(manager.entries[0] == .text(value: "aaa"))
        #expect(manager.entries[1] == .text(value: "bbb"))
    }

    @Test("Max entries enforced at configured limit")
    func maxEntries() {
        let appState = AppState()
        appState.maxHistoryCount = 20
        let manager = HistoryManager(appState: appState)
        manager.clearAll()

        for i in 0..<25 {
            manager.addEntry(.text(value: "entry \(i)"))
        }

        #expect(manager.entries.count == 20)
        #expect(manager.entries[0] == .text(value: "entry 24"))

        // Cleanup
        appState.maxHistoryCount = 30
    }

    @Test("Empty and whitespace text entries are ignored")
    func emptyEntries() {
        let manager = makeManager()

        manager.addEntry(.text(value: ""))
        manager.addEntry(.text(value: "   "))
        manager.addEntry(.text(value: "\n"))

        #expect(manager.entries.isEmpty)
    }

    @Test("Remove entry at index")
    func removeEntry() {
        let manager = makeManager()

        manager.addEntry(.text(value: "a"))
        manager.addEntry(.text(value: "b"))
        manager.addEntry(.text(value: "c"))

        manager.removeEntry(at: 1)

        #expect(manager.entries.count == 2)
        #expect(manager.entries[0] == .text(value: "c"))
        #expect(manager.entries[1] == .text(value: "a"))
    }

    @Test("Clear all removes everything")
    func clearAll() {
        let manager = makeManager()

        manager.addEntry(.text(value: "a"))
        manager.addEntry(.text(value: "b"))
        manager.clearAll()

        #expect(manager.entries.isEmpty)
    }

    @Test("Remove at invalid index does nothing")
    func removeInvalidIndex() {
        let manager = makeManager()

        manager.addEntry(.text(value: "a"))
        manager.removeEntry(at: 5)

        #expect(manager.entries.count == 1)
    }

    @Test("Search finds matching text entries")
    func searchText() {
        let manager = makeManager()

        manager.addEntry(.text(value: "Hello World"))
        manager.addEntry(.text(value: "Goodbye"))
        manager.addEntry(.text(value: "Hello Again"))

        let results = manager.search("hello")
        #expect(results.count == 2)
    }

    @Test("Search returns empty for no matches")
    func searchNoMatch() {
        let manager = makeManager()

        manager.addEntry(.text(value: "Hello"))
        let results = manager.search("xyz")
        #expect(results.isEmpty)
    }

    @Test("Image entries are added")
    func addImageEntry() {
        let manager = makeManager()

        let imageID = UUID()
        manager.addEntry(.image(imageID: imageID))

        #expect(manager.entries.count == 1)
        #expect(manager.entries[0] == .image(imageID: imageID))
    }
}
