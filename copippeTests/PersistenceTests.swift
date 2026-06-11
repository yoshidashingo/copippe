import Foundation
import Testing
@testable import copippe

@Suite("JSONFileStore Tests")
struct PersistenceTests {

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("copippe-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("store.json")
    }

    @Test("Save and load round-trips a Codable value")
    func saveAndLoad() {
        let store = JSONFileStore<[String]>(fileURL: temporaryFileURL())

        store.save(["a", "b"])

        #expect(store.load() == ["a", "b"])
    }

    @Test("Load returns nil when file does not exist")
    func loadMissingFile() {
        let store = JSONFileStore<[String]>(fileURL: temporaryFileURL())
        #expect(store.load() == nil)
    }

    @Test("Save creates intermediate directories")
    func saveCreatesDirectories() {
        let url = temporaryFileURL() // 親ディレクトリは未作成
        let store = JSONFileStore<Int>(fileURL: url)

        store.save(42)

        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("loadData returns raw bytes for migration fallbacks")
    func loadDataRaw() throws {
        let url = temporaryFileURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("[\"legacy\"]".utf8).write(to: url)

        let store = JSONFileStore<[String]>(fileURL: url)

        #expect(store.loadData() != nil)
    }

    @Test("appSupportDirectory points into copippe folder")
    func appSupportDirectory() {
        let dir = AppDirectories.appSupport()
        #expect(dir.lastPathComponent == "copippe")
    }
}
