import SwiftUI
import ServiceManagement

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

// MARK: - General Tab

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

                Toggle(
                    "Plain text mode by default",
                    isOn: Binding(
                        get: { appState.defaultPlainTextMode },
                        set: { appState.defaultPlainTextMode = $0 }
                    )
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

// MARK: - Hotkey Tab

struct HotkeyTab: View {
    let hotkeyManager: HotkeyManager
    @State private var historyHotkeyDisplay = ""
    @State private var isRecordingHistory = false

    var body: some View {
        Form {
            Section("Global Hotkeys") {
                HStack {
                    Text("Show History Popup")
                    Spacer()
                    KeyRecorderButton(
                        displayString: hotkeyDisplay(for: .showHistory),
                        isRecording: $isRecordingHistory,
                        onRecord: { keyCode, modifiers in
                            let binding = HotkeyBinding(keyCode: keyCode, modifiers: modifiers)
                            if let conflict = hotkeyManager.checkConflict(binding: binding, excluding: .showHistory) {
                                // Show conflict warning
                                _ = conflict
                            } else {
                                hotkeyManager.updateHotkey(action: .showHistory, binding: binding)
                            }
                        }
                    )
                }
            }

            Section {
                Text("Press the recorder button, then press your desired key combination.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func hotkeyDisplay(for action: HotkeyAction) -> String {
        hotkeyManager.binding(for: action)?.displayString ?? "Not set"
    }
}

// MARK: - Key Recorder Button

struct KeyRecorderButton: View {
    let displayString: String
    @Binding var isRecording: Bool
    let onRecord: (UInt16, UInt) -> Void

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(isRecording ? "Press keys..." : displayString)
                .frame(minWidth: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Snippet Tab

struct SnippetTab: View {
    let snippetManager: SnippetManager
    @State private var selectedFolderID: UUID?
    @State private var selectedSnippetID: UUID?
    @State private var isEditingSnippet = false
    @State private var editTitle = ""
    @State private var editContent = ""

    var body: some View {
        HSplitView {
            // Left pane: Folders
            VStack(alignment: .leading, spacing: 0) {
                List(snippetManager.folders, selection: $selectedFolderID) { folder in
                    Text(folder.name)
                        .tag(folder.id)
                }
                .listStyle(.sidebar)

                Divider()

                HStack(spacing: 4) {
                    Button {
                        snippetManager.addFolder(name: "New Folder")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)

                    Button {
                        if let id = selectedFolderID {
                            snippetManager.deleteFolder(id: id)
                            selectedFolderID = nil
                        }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedFolderID == nil)

                    Spacer()
                }
                .padding(6)
            }
            .frame(minWidth: 150, maxWidth: 200)

            // Right pane: Snippets
            VStack(alignment: .leading, spacing: 0) {
                if let folderID = selectedFolderID,
                   let folder = snippetManager.folders.first(where: { $0.id == folderID }) {
                    List(folder.snippets, selection: $selectedSnippetID) { snippet in
                        VStack(alignment: .leading) {
                            Text(snippet.title)
                                .font(.system(size: 13, weight: .medium))
                            Text(snippet.content)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .tag(snippet.id)
                    }
                    .listStyle(.plain)

                    Divider()

                    // Snippet editor
                    if isEditingSnippet {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Title", text: $editTitle)
                                .textFieldStyle(.roundedBorder)
                            TextEditor(text: $editContent)
                                .font(.system(size: 12))
                                .frame(height: 80)
                                .border(Color.secondary.opacity(0.3))
                            HStack {
                                Spacer()
                                Button("Cancel") {
                                    isEditingSnippet = false
                                }
                                Button("Save") {
                                    if let snippetID = selectedSnippetID {
                                        snippetManager.updateSnippet(id: snippetID, title: editTitle, content: editContent)
                                    } else {
                                        snippetManager.addSnippet(folderID: folderID, title: editTitle, content: editContent)
                                    }
                                    isEditingSnippet = false
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(8)
                    }

                    HStack(spacing: 4) {
                        Button {
                            selectedSnippetID = nil
                            editTitle = ""
                            editContent = ""
                            isEditingSnippet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)

                        Button {
                            if let id = selectedSnippetID {
                                snippetManager.deleteSnippet(id: id)
                                selectedSnippetID = nil
                            }
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedSnippetID == nil)

                        Button {
                            if let id = selectedSnippetID,
                               let snippet = snippetManager.snippet(for: id) {
                                editTitle = snippet.title
                                editContent = snippet.content
                                isEditingSnippet = true
                            }
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedSnippetID == nil)

                        Spacer()
                    }
                    .padding(6)
                } else {
                    VStack {
                        Spacer()
                        Text("Select a folder")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(minWidth: 250)
        }
    }
}
