import AppKit
import Testing
@testable import copippe

@Suite("Pasteboard Tests")
@MainActor
struct PasteboardTests {

    private let testPasteboard = TestPasteboard()

    @Test("Copy string replaces pasteboard contents")
    func copyString() {
        let staleImage = makeImage()
        testPasteboard.pasteboard.clearContents()
        testPasteboard.pasteboard.setData(staleImage.tiffRepresentation!, forType: .tiff)

        Pasteboard.copy("hello", to: testPasteboard.pasteboard)

        #expect(testPasteboard.pasteboard.string(forType: .string) == "hello")
        #expect(testPasteboard.pasteboard.data(forType: .tiff) == nil)
    }

    @Test("Copy image writes TIFF data")
    func copyImage() {
        let image = makeImage()
        testPasteboard.pasteboard.clearContents()
        testPasteboard.pasteboard.setString("stale", forType: .string)

        Pasteboard.copy(image, to: testPasteboard.pasteboard)

        #expect(testPasteboard.pasteboard.data(forType: .tiff) != nil)
        #expect(testPasteboard.pasteboard.string(forType: .string) == nil)
    }

    private func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        return image
    }
}
