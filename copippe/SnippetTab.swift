import SwiftUI

struct SnippetTab: View {
    let snippetManager: SnippetManager
    @State private var selectedFolderID: UUID?
    @State private var selectedSnippetID: UUID?
    @State private var renamingFolderID: UUID?
    @State private var folderNameDraft = ""
    @State private var isEditingSnippet = false
    @State private var editTitle = ""
    @State private var editContent = ""
    @FocusState private var isFolderNameFieldFocused: Bool

    var body: some View {
        HSplitView {
            // Left pane: Folders
            VStack(alignment: .leading, spacing: 0) {
                List(snippetManager.folders, selection: $selectedFolderID) { folder in
                    folderRow(folder)
                        .tag(folder.id)
                        .contextMenu {
                            Button("Rename") {
                                startRenamingFolder(folder)
                            }
                        }
                }
                .listStyle(.sidebar)

                Divider()

                HStack(spacing: 4) {
                    Button {
                        let folder = snippetManager.addFolder()
                        startRenamingFolder(folder)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Add Folder")

                    Button {
                        if let id = selectedFolderID {
                            snippetManager.deleteFolder(id: id)
                            if renamingFolderID == id {
                                cancelFolderRename()
                            }
                            selectedFolderID = nil
                        }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedFolderID == nil)
                    .help("Delete Folder")

                    Button {
                        guard let id = selectedFolderID,
                              let folder = snippetManager.folders.first(where: { $0.id == id }) else { return }
                        startRenamingFolder(folder)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedFolderID == nil)
                    .help("Rename Folder")

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

    @ViewBuilder
    private func folderRow(_ folder: SnippetFolder) -> some View {
        if renamingFolderID == folder.id {
            HStack(spacing: 4) {
                TextField("Folder name", text: $folderNameDraft)
                    .textFieldStyle(.plain)
                    .focused($isFolderNameFieldFocused)
                    .onSubmit {
                        commitFolderRename()
                    }
                    .onExitCommand {
                        cancelFolderRename()
                    }

                Button {
                    commitFolderRename()
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.borderless)
                .help("Save Folder Name")

                Button {
                    cancelFolderRename()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Cancel Rename")
            }
        } else {
            Text(folder.name)
        }
    }

    private func startRenamingFolder(_ folder: SnippetFolder) {
        selectedFolderID = folder.id
        renamingFolderID = folder.id
        folderNameDraft = folder.name
        DispatchQueue.main.async {
            isFolderNameFieldFocused = true
        }
    }

    private func commitFolderRename() {
        guard let id = renamingFolderID else { return }
        let trimmedName = folderNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            snippetManager.renameFolder(id: id, name: trimmedName)
        }
        cancelFolderRename()
    }

    private func cancelFolderRename() {
        renamingFolderID = nil
        folderNameDraft = ""
        isFolderNameFieldFocused = false
    }
}
