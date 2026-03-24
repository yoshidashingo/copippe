import Testing
@testable import copippe

@Suite("HistoryManager Tests")
struct HistoryManagerTests {

    private func makeManager() -> HistoryManager {
        let manager = HistoryManager()
        manager.clearAll()
        return manager
    }

    @Test("Add entry inserts at beginning")
    func addEntry() {
        let manager = makeManager()

        manager.addEntry("first")
        manager.addEntry("second")

        #expect(manager.entries.count == 2)
        #expect(manager.entries[0] == "second")
        #expect(manager.entries[1] == "first")
    }

    @Test("Duplicate consecutive entries are prevented")
    func duplicateConsecutive() {
        let manager = makeManager()

        manager.addEntry("hello")
        manager.addEntry("hello")

        #expect(manager.entries.count == 1)
    }

    @Test("Same text at different positions is deduplicated")
    func duplicateDedup() {
        let manager = makeManager()

        manager.addEntry("aaa")
        manager.addEntry("bbb")
        manager.addEntry("aaa")

        #expect(manager.entries.count == 2)
        #expect(manager.entries[0] == "aaa")
        #expect(manager.entries[1] == "bbb")
    }

    @Test("Max entries enforced at 20")
    func maxEntries() {
        let manager = makeManager()

        for i in 0..<25 {
            manager.addEntry("entry \(i)")
        }

        #expect(manager.entries.count == HistoryManager.maxEntries)
        #expect(manager.entries[0] == "entry 24")
    }

    @Test("Empty and whitespace entries are ignored")
    func emptyEntries() {
        let manager = makeManager()

        manager.addEntry("")
        manager.addEntry("   ")
        manager.addEntry("\n")

        #expect(manager.entries.isEmpty)
    }

    @Test("Remove entry at index")
    func removeEntry() {
        let manager = makeManager()

        manager.addEntry("a")
        manager.addEntry("b")
        manager.addEntry("c")

        manager.removeEntry(at: 1)

        #expect(manager.entries.count == 2)
        #expect(manager.entries[0] == "c")
        #expect(manager.entries[1] == "a")
    }

    @Test("Clear all removes everything")
    func clearAll() {
        let manager = makeManager()

        manager.addEntry("a")
        manager.addEntry("b")
        manager.clearAll()

        #expect(manager.entries.isEmpty)
    }

    @Test("Remove at invalid index does nothing")
    func removeInvalidIndex() {
        let manager = makeManager()

        manager.addEntry("a")
        manager.removeEntry(at: 5)

        #expect(manager.entries.count == 1)
    }
}
