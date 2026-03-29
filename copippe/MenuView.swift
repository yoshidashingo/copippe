import SwiftUI

struct MenuView: View {
    let appState: AppState
    let historyManager: HistoryManager

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
                ForEach(Array(historyManager.entries.enumerated()), id: \.offset) { index, entry in
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

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }

    @ViewBuilder
    private func historyEntryLabel(_ entry: HistoryEntry) -> some View {
        switch entry {
        case .text(let string):
            Text(previewText(string))
                .lineLimit(1)
                .truncationMode(.tail)
        case .image(let imageID):
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
