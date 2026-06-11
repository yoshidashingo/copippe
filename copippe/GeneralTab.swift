import SwiftUI
import ServiceManagement

struct GeneralTab: View {
    let appState: AppState
    @State private var loginItemEnabled = true

    var body: some View {
        Form {
            Section("Clipboard") {
                Stepper(
                    "History limit: \(appState.maxHistoryCount)",
                    value: Binding(
                        get: { appState.maxHistoryCount },
                        set: { appState.maxHistoryCount = $0 }
                    ),
                    in: 5...100
                )
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $loginItemEnabled)
                    .onChange(of: loginItemEnabled) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // Revert on failure
                            loginItemEnabled = !newValue
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loginItemEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }
}
