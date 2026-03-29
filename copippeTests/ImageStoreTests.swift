import Testing
import AppKit
@testable import copippe

@Suite("ImageStore Tests")
struct ImageStoreTests {

    private func makeStore() -> ImageStore {
        let store = ImageStore()
        store.deleteAll()
        return store
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
    func saveAndLoad() {
        let store = makeStore()
        let image = makeTestImage()

        let id = store.save(image)
        #expect(id != nil)

        let loaded = store.load(id: id!)
        #expect(loaded != nil)
        #expect(loaded!.size.width > 0)

        // Cleanup
        store.delete(id: id!)
    }

    @Test("Delete image")
    func deleteImage() {
        let store = makeStore()
        let image = makeTestImage()

        let id = store.save(image)!
        store.delete(id: id)

        let loaded = store.load(id: id)
        #expect(loaded == nil)
    }

    @Test("Thumbnail generation")
    func thumbnail() {
        let store = makeStore()
        let image = makeTestImage()

        let id = store.save(image)!
        let thumb = store.thumbnail(id: id, maxSize: 40)

        #expect(thumb != nil)
        #expect(thumb!.size.width <= 40)
        #expect(thumb!.size.height <= 40)

        // Cleanup
        store.delete(id: id)
    }

    @Test("Load non-existent image returns nil")
    func loadNonExistent() {
        let store = makeStore()
        let loaded = store.load(id: UUID())
        #expect(loaded == nil)
    }

    @Test("Delete all clears images")
    func deleteAll() {
        let store = makeStore()
        let image = makeTestImage()

        let id1 = store.save(image)!
        let id2 = store.save(image)!

        store.deleteAll()

        #expect(store.load(id: id1) == nil)
        #expect(store.load(id: id2) == nil)
    }
}
