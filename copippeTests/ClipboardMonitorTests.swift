import AppKit
import Testing
@testable import copippe

@Suite("ClipboardMonitor Tests")
@MainActor
struct ClipboardMonitorTests {

    private let testDefaults = TestDefaults()
    private let testPasteboard = TestPasteboard()

    private func makeMonitor() -> ClipboardMonitor {
        let appState = AppState(defaults: testDefaults.defaults)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("copippe-tests-\(UUID().uuidString)", isDirectory: true)
        let historyManager = HistoryManager(
            appState: appState,
            fileURL: tempDir.appendingPathComponent("history.json"),
            imageStore: ImageStore(directory: tempDir.appendingPathComponent("images", isDirectory: true))
        )
        return ClipboardMonitor(appState: appState, historyManager: historyManager)
    }

    @Test("Plain string is extracted as-is")
    func plainString() {
        let monitor = makeMonitor()
        let pasteboard = testPasteboard.pasteboard
        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)

        #expect(monitor.convertToPlainText(from: pasteboard) == "hello")
    }

    @Test("RTF data is converted to plain text")
    func rtfToPlainText() throws {
        let monitor = makeMonitor()
        let pasteboard = testPasteboard.pasteboard
        let attributed = NSAttributedString(string: "styled", attributes: [.font: NSFont.boldSystemFont(ofSize: 14)])
        let rtfData = try #require(attributed.rtf(from: NSRange(location: 0, length: attributed.length)))
        pasteboard.clearContents()
        pasteboard.setData(rtfData, forType: .rtf)

        #expect(monitor.convertToPlainText(from: pasteboard) == "styled")
    }

    @Test("Empty pasteboard yields nil")
    func emptyPasteboard() {
        let monitor = makeMonitor()
        let pasteboard = testPasteboard.pasteboard
        pasteboard.clearContents()

        #expect(monitor.convertToPlainText(from: pasteboard) == nil)
    }

    @Test("Image data is extracted as NSImage")
    func imageExtraction() throws {
        let monitor = makeMonitor()
        let pasteboard = testPasteboard.pasteboard
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.green.setFill()
        NSRect(x: 0, y: 0, width: 10, height: 10).fill()
        image.unlockFocus()
        let tiff = try #require(image.tiffRepresentation)
        pasteboard.clearContents()
        pasteboard.setData(tiff, forType: .tiff)

        #expect(monitor.extractImage(from: pasteboard) != nil)
    }
}
