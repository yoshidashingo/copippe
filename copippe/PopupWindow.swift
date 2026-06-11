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

// MARK: - PopupContentView

struct PopupContentView: View {
    let historyManager: HistoryManager
    let snippetManager: SnippetManager
    @Bindable var popupState: PopupState
    @State private var searchText = ""
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.bar)

            // Tab picker
            Picker("", selection: $popupState.selectedTab) {
                Text("History").tag(PopupTab.history)
                Text("Snippets").tag(PopupTab.snippets)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            // Content
            switch popupState.selectedTab {
            case .history:
                historyListView
            case .snippets:
                snippetListView
            }
        }
        .frame(minWidth: 350, minHeight: 400)
        .onExitCommand {
            onDismiss()
        }
    }

    // MARK: - History List

    private var filteredHistoryIndices: [Int] {
        if searchText.isEmpty {
            return Array(historyManager.entries.indices)
        }
        return historyManager.search(searchText)
    }

    private var historyListView: some View {
        Group {
            if filteredHistoryIndices.isEmpty {
                emptyView("No history items")
            } else {
                List(filteredHistoryIndices, id: \.self) { index in
                    historyRowView(index: index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            historyManager.copyToClipboard(at: index)
                            onDismiss()
                        }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func historyRowView(index: Int) -> some View {
        let entry = historyManager.entries[index]
        HStack(spacing: 8) {
            switch entry {
            case .text(_, let string):
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(string.singleLinePreview(maxLength: 80))
                    .lineLimit(2)
                    .font(.system(size: 13))

            case .image(_, let imageID):
                if let thumbnail = historyManager.imageStore.thumbnail(id: imageID) {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                } else {
                    Image(systemName: "photo")
                        .frame(width: 40, height: 40)
                }
                Text("Image")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Snippet List

    private var filteredSnippets: [Snippet] {
        if searchText.isEmpty {
            return snippetManager.folders.flatMap { $0.snippets }
        }
        return snippetManager.search(searchText)
    }

    private var snippetListView: some View {
        Group {
            if searchText.isEmpty {
                // Show folder structure
                if snippetManager.folders.isEmpty {
                    emptyView("No snippets")
                } else {
                    List {
                        ForEach(snippetManager.folders) { folder in
                            DisclosureGroup(folder.name) {
                                ForEach(folder.snippets) { snippet in
                                    snippetRowView(snippet: snippet)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            copySnippet(snippet)
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            } else {
                // Show flat search results
                if filteredSnippets.isEmpty {
                    emptyView("No matching snippets")
                } else {
                    List(filteredSnippets) { snippet in
                        snippetRowView(snippet: snippet)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                copySnippet(snippet)
                            }
                    }
                    .listStyle(.plain)
                }
            }
        }
    }

    private func snippetRowView(snippet: Snippet) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(snippet.title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                if let hotkey = snippet.hotkey {
                    Text(hotkey.displayString)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(.quaternary)
                        .cornerRadius(3)
                }
            }
            Text(snippet.content)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func copySnippet(_ snippet: Snippet) {
        Pasteboard.copy(snippet.content)
        onDismiss()
    }

    // MARK: - Helpers

    private func emptyView(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
