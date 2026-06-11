import Foundation
import Testing
@testable import copippe

@Suite("HistoryManager Tests")
struct HistoryManagerTests {

    private let testDefaults = TestDefaults()

    private func makeManager(maxHistoryCount: Int = 30) -> HistoryManager {
        let appState = AppState(defaults: testDefaults.defaults)
        appState.maxHistoryCount = maxHistoryCount
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("copippe-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return HistoryManager(
            appState: appState,
            fileURL: tempDir.appendingPathComponent("history.json"),
            imageStore: ImageStore(directory: tempDir.appendingPathComponent("images", isDirectory: true))
        )
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
        let manager = makeManager(maxHistoryCount: 20)

        for i in 0..<25 {
            manager.addEntry(.text(value: "entry \(i)"))
        }

        #expect(manager.entries.count == 20)
        #expect(manager.entries[0] == .text(value: "entry 24"))
    }

    @Test("Empty and whitespace text entries are ignored")
    func emptyEntries() {
        let manager = makeManager()

        manager.addEntry(.text(value: ""))
        manager.addEntry(.text(value: "   "))
        manager.addEntry(.text(value: "\n"))

        #expect(manager.entries.isEmpty)
    }

    @Test("Clear all removes everything")
    func clearAll() {
        let manager = makeManager()

        manager.addEntry(.text(value: "a"))
        manager.addEntry(.text(value: "b"))
        manager.clearAll()

        #expect(manager.entries.isEmpty)
    }

    @Test("Search finds matching text entries")
    func searchText() {
        let manager = makeManager()

        manager.addEntry(.text(value: "Hello World"))
        manager.addEntry(.text(value: "Goodbye"))
        manager.addEntry(.text(value: "Hello Again"))

        let results = manager.search("hello")
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.textValue?.lowercased().contains("hello") == true })
    }

    @Test("Search returns empty for no matches")
    func searchNoMatch() {
        let manager = makeManager()

        manager.addEntry(.text(value: "Hello"))
        let results = manager.search("xyz")
        #expect(results.isEmpty)
    }

    @Test("Search returns all entries for empty query")
    func searchEmptyQuery() {
        let manager = makeManager()

        manager.addEntry(.text(value: "Hello"))
        manager.addEntry(.image(imageID: UUID()))

        let results = manager.search("")
        #expect(results == manager.entries)
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
