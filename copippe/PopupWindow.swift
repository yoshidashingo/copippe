import SwiftUI
import AppKit

// MARK: - PopupState

@MainActor
@Observable
final class PopupState {
    var selectedTab: PopupTab = .history
}

// MARK: - PopupWindowController

@MainActor
final class PopupWindowController {
    private var panel: NSPanel?
    private let historyManager: HistoryManager
    private let snippetManager: SnippetManager
    private let popupState = PopupState()

    init(historyManager: HistoryManager, snippetManager: SnippetManager) {
        self.historyManager = historyManager
        self.snippetManager = snippetManager
    }

    func show(tab: PopupTab) {
        popupState.selectedTab = tab

        if let panel = panel {
            panel.orderFront(nil)
            panel.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = PopupContentView(
            historyManager: historyManager,
            snippetManager: snippetManager,
            popupState: popupState,
            onDismiss: { [weak self] in self?.hide() }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    func toggle(tab: PopupTab) {
        if panel != nil, popupState.selectedTab == tab {
            // Same tab requested while visible: dismiss
            hide()
        } else {
            show(tab: tab)
        }
    }
}
