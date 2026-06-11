import SwiftUI

struct PreferencesView: View {
    let appState: AppState
    let snippetManager: SnippetManager
    let hotkeyManager: HotkeyManager

    var body: some View {
        TabView {
            GeneralTab(appState: appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            HotkeyTab(hotkeyManager: hotkeyManager)
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }

            SnippetTab(snippetManager: snippetManager)
                .tabItem {
                    Label("Snippets", systemImage: "text.snippet")
                }
        }
        .frame(width: 500, height: 400)
    }
}
