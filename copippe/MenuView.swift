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
                        Text(previewText(entry))
                            .lineLimit(1)
                            .truncationMode(.tail)
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

    private func previewText(_ text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count > 50 {
            return String(singleLine.prefix(50)) + "..."
        }
        return singleLine
    }
}
