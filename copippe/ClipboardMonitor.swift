import Foundation
import AppKit
import Observation

@Observable
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var isUpdatingClipboard = false

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
            self?.checkClipboard()
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

        // Skip if we caused this clipboard change
        guard !isUpdatingClipboard else { return }

        guard appState.isActive else { return }

        handleClipboardChange()
    }

    private func handleClipboardChange() {
        guard let plainText = convertToPlainText() else { return }

        historyManager.addEntry(plainText)

        // Write plain text back to clipboard
        isUpdatingClipboard = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(plainText, forType: .string)
        lastChangeCount = pasteboard.changeCount
        isUpdatingClipboard = false
    }

    private func convertToPlainText() -> String? {
        let pasteboard = NSPasteboard.general

        // Try to get string content from any available type
        if let string = pasteboard.string(forType: .string) {
            return string
        }

        // Try RTF
        if let rtfData = pasteboard.data(forType: .rtf) {
            let attributed = NSAttributedString(rtf: rtfData, documentAttributes: nil)
            return attributed?.string
        }

        // Try HTML
        if let htmlData = pasteboard.data(forType: .html) {
            let attributed = NSAttributedString(html: htmlData, documentAttributes: nil)
            return attributed?.string
        }

        return nil
    }
}
