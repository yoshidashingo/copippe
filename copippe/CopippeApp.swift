import SwiftUI
import ServiceManagement

@main
struct CopippeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(
                appState: appDelegate.appState,
                historyManager: appDelegate.historyManager
            )
        } label: {
            Image(systemName: appDelegate.appState.isActive ? "doc.on.clipboard.fill" : "doc.on.clipboard")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let historyManager = HistoryManager()
    private var clipboardMonitor: ClipboardMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let monitor = ClipboardMonitor(appState: appState, historyManager: historyManager)
        monitor.startMonitoring()
        clipboardMonitor = monitor

        // Register login item
        do {
            try SMAppService.mainApp.register()
        } catch {
            // Not critical
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
        historyManager.save()
    }
}
