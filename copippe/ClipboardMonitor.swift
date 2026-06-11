import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0

    private let appState: AppState
    private let historyManager: HistoryManager

    init(appState: AppState, historyManager: HistoryManager) {
        self.appState = appState
        self.historyManager = historyManager
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        stopMonitoring()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkClipboard()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        handleClipboardChange()
    }

    private func handleClipboardChange() {
        let pasteboard = NSPasteboard.general

        // Check for image first (higher priority when both exist)
        if let image = extractImage(from: pasteboard) {
            if let imageID = historyManager.imageStore.save(image) {
                historyManager.addEntry(.image(imageID: imageID))
            }
            return
        }

        // Handle text
        guard let plainText = convertToPlainText(from: pasteboard) else { return }

        historyManager.addEntry(.text(value: plainText))

        // Write plain text back to clipboard only when active
        if appState.isActive {
            Pasteboard.copy(plainText)
            lastChangeCount = NSPasteboard.general.changeCount
        }
    }

    private func extractImage(from pasteboard: NSPasteboard) -> NSImage? {
        // Check for image types
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        for type in imageTypes {
            if let data = pasteboard.data(forType: type),
               let image = NSImage(data: data),
               image.size.width > 0, image.size.height > 0 {
                return image
            }
        }
        return nil
    }

    private func convertToPlainText(from pasteboard: NSPasteboard) -> String? {
        if let string = pasteboard.string(forType: .string) {
            return string
        }

        if let rtfData = pasteboard.data(forType: .rtf) {
            let attributed = NSAttributedString(rtf: rtfData, documentAttributes: nil)
            return attributed?.string
        }

        if let htmlData = pasteboard.data(forType: .html) {
            let attributed = NSAttributedString(html: htmlData, documentAttributes: nil)
            return attributed?.string
        }

        return nil
    }
}
