import SwiftUI
import AppKit

struct HotkeyTab: View {
    let hotkeyManager: HotkeyManager
    @State private var isRecordingHistory = false
    @State private var conflictMessage: String?

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
                                conflictMessage = "\(binding.displayString) is already assigned to \(label(for: conflict))."
                            } else {
                                hotkeyManager.registerHotkey(action: .showHistory, binding: binding)
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
        .alert(
            "Hotkey Conflict",
            isPresented: Binding(
                get: { conflictMessage != nil },
                set: { if !$0 { conflictMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(conflictMessage ?? "")
        }
    }

    private func hotkeyDisplay(for action: HotkeyAction) -> String {
        hotkeyManager.binding(for: action)?.displayString ?? "Not set"
    }

    private func label(for action: HotkeyAction) -> String {
        switch action {
        case .showHistory: return "Show History Popup"
        case .showSnippets: return "Show Snippets Popup"
        case .snippet: return "a snippet"
        }
    }
}

struct KeyRecorderButton: View {
    let displayString: String
    @Binding var isRecording: Bool
    let onRecord: (UInt16, UInt) -> Void
    @State private var keyMonitor: Any?

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            Text(isRecording ? "Press keys..." : displayString)
                .frame(minWidth: 100)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels recording
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Require at least one modifier so plain typing can't become a hotkey
            guard !modifiers.isEmpty else { return event }
            onRecord(event.keyCode, modifiers.rawValue)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
