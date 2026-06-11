import Testing
import AppKit
@testable import copippe

@Suite("ImageStore Tests")
@MainActor
struct ImageStoreTests {

    private func makeStore() -> ImageStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("copippe-tests-\(UUID().uuidString)", isDirectory: true)
        return ImageStore(directory: tempDir)
    }

    private func makeTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()
        return image
    }

    @Test("Save and load image")
    func saveAndLoad() throws {
        let store = makeStore()
        let image = makeTestImage()

        let id = try #require(store.save(image))
        let loaded = try #require(store.load(id: id))
        #expect(loaded.size.width > 0)

        store.delete(id: id)
    }

    @Test("Delete image")
    func deleteImage() throws {
        let store = makeStore()
        let image = makeTestImage()

        let id = try #require(store.save(image))
        store.delete(id: id)

        #expect(store.load(id: id) == nil)
    }

    @Test("Thumbnail generation")
    func thumbnail() throws {
        let store = makeStore()
        let image = makeTestImage()

        let id = try #require(store.save(image))
        let thumb = try #require(store.thumbnail(id: id, maxSize: 40))

        #expect(thumb.size.width <= 40)
        #expect(thumb.size.height <= 40)

        store.delete(id: id)
    }

    @Test("Thumbnails at different sizes are cached independently")
    func thumbnailDifferentSizes() throws {
        let store = makeStore()
        let image = makeTestImage()

        let id = try #require(store.save(image))
        let large = try #require(store.thumbnail(id: id, maxSize: 80))
        let small = try #require(store.thumbnail(id: id, maxSize: 20))

        #expect(large.size.width > small.size.width)

        store.delete(id: id)
    }

    @Test("Load non-existent image returns nil")
    func loadNonExistent() {
        let store = makeStore()
        #expect(store.load(id: UUID()) == nil)
    }

    @Test("Delete all clears images")
    func deleteAll() throws {
        let store = makeStore()
        let image = makeTestImage()

        let id1 = try #require(store.save(image))
        let id2 = try #require(store.save(image))

        store.deleteAll()

        #expect(store.load(id: id1) == nil)
        #expect(store.load(id: id2) == nil)
    }
}
