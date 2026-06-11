import SwiftUI

struct MenuView: View {
    let appState: AppState
    let historyManager: HistoryManager
    let snippetManager: SnippetManager
    var onOpenPreferences: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Activate/Deactivate toggle
            Button {
                appState.toggleActivation()
            } label: {
                HStack {
                    Image(systemName: appState.isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(appState.isActive ? .green : .secondary)
                    Text(appState.isActive ? "Active" : "Inactive")
                }
            }
            .keyboardShortcut("a", modifiers: [.command])

            Divider()

            // History section
            if historyManager.entries.isEmpty {
                Text("No history")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(historyManager.entries.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        historyManager.copyToClipboard(at: index)
                    } label: {
                        historyEntryLabel(entry)
                    }
                }

                Divider()

                Button("Clear History") {
                    historyManager.clearAll()
                }
            }

            Divider()

            // Snippet section
            if !snippetManager.folders.isEmpty {
                ForEach(snippetManager.folders) { folder in
                    Menu(folder.name) {
                        if folder.snippets.isEmpty {
                            Text("No snippets")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(folder.snippets) { snippet in
                                Button {
                                    Pasteboard.copy(snippet.content)
                                } label: {
                                    HStack {
                                        Text(snippet.title)
                                        if let hotkey = snippet.hotkey {
                                            Spacer()
                                            Text(hotkey.displayString)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()
            }

            // Preferences
            Button("Preferences...") {
                onOpenPreferences?()
            }
            .keyboardShortcut(",", modifiers: [.command])

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }

    @ViewBuilder
    private func historyEntryLabel(_ entry: HistoryEntry) -> some View {
        switch entry {
        case .text(_, let string):
            Text(previewText(string))
                .lineLimit(1)
                .truncationMode(.tail)
        case .image(_, let imageID):
            HStack(spacing: 4) {
                if let thumbnail = historyManager.imageStore.thumbnail(id: imageID) {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "photo")
                }
                Text("Image")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func previewText(_ text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count > 50 {
            return String(singleLine.prefix(50)) + "..."
        }
        return singleLine
    }
}
