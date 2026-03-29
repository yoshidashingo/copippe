import SwiftUI
import ServiceManagement

@main
struct CopippeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(
                appState: appDelegate.appState,
                historyManager: appDelegate.historyManager,
                snippetManager: appDelegate.snippetManager,
                onOpenPreferences: { [weak appDelegate] in
                    appDelegate?.openPreferences()
                }
            )
        } label: {
            Image(systemName: appDelegate.appState.isActive ? "doc.on.clipboard.fill" : "doc.on.clipboard")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private(set) lazy var historyManager = HistoryManager(appState: appState)
    let snippetManager = SnippetManager()
    let hotkeyManager = HotkeyManager()
    private var clipboardMonitor: ClipboardMonitor?
    private var popupController: PopupWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let monitor = ClipboardMonitor(appState: appState, historyManager: historyManager)
        monitor.startMonitoring()
        clipboardMonitor = monitor

        // Setup popup window
        let popup = PopupWindowController(historyManager: historyManager, snippetManager: snippetManager)
        popupController = popup

        // Connect hotkey actions
        hotkeyManager.onAction = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .showHistory:
                self.popupController?.toggle(tab: .history)
            case .showSnippets:
                self.popupController?.toggle(tab: .snippets)
            case .snippet(let id):
                if let snippet = self.snippetManager.snippet(for: id) {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(snippet.content, forType: .string)
                }
            }
        }
        hotkeyManager.start()

        // Register login item
        do {
            try SMAppService.mainApp.register()
        } catch {
            // Not critical
        }
    }

    // MARK: - Preferences Window

    private var preferencesWindow: NSWindow?

    func openPreferences() {
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let preferencesView = PreferencesView(
            appState: appState,
            snippetManager: snippetManager,
            hotkeyManager: hotkeyManager
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "copippe Preferences"
        window.contentView = NSHostingView(rootView: preferencesView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        preferencesWindow = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
        hotkeyManager.stop()
        historyManager.save()
        snippetManager.save()
    }
}
