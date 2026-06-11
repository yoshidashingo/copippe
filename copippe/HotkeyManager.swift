import Foundation
import AppKit
import Carbon.HIToolbox

@MainActor
final class HotkeyManager {
    private var globalMonitor: Any?
    private var registeredHotkeys: [HotkeyAction: HotkeyBinding] = [:]

    var onAction: ((HotkeyAction) -> Void)?

    private static let defaultHistoryHotkey = HotkeyBinding(
        keyCode: UInt16(kVK_ANSI_V),
        modifiers: NSEvent.ModifierFlags([.control, .option]).rawValue
    )

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadHotkeys()
    }

    func start() {
        stop()

        // Request accessibility permission if not granted
        if !AXIsProcessTrusted() {
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let options = [promptKey: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }

        // Register default hotkeys if none exist
        if registeredHotkeys[.showHistory] == nil {
            registeredHotkeys[.showHistory] = Self.defaultHistoryHotkey
            saveHotkeys()
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
            Task { @MainActor in
                self?.handleKeyEvent(keyCode: keyCode, modifiers: modifiers)
            }
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    func registerHotkey(action: HotkeyAction, binding: HotkeyBinding) {
        registeredHotkeys[action] = binding
        saveHotkeys()
    }

    func unregisterHotkey(action: HotkeyAction) {
        registeredHotkeys.removeValue(forKey: action)
        saveHotkeys()
    }

    func binding(for action: HotkeyAction) -> HotkeyBinding? {
        registeredHotkeys[action]
    }

    func checkConflict(binding: HotkeyBinding, excluding: HotkeyAction? = nil) -> HotkeyAction? {
        for (action, existingBinding) in registeredHotkeys {
            if let excluding = excluding, action == excluding { continue }
            if existingBinding == binding {
                return action
            }
        }
        return nil
    }

    // MARK: - Event Handling

    private func handleKeyEvent(keyCode: UInt16, modifiers: UInt) {
        for (action, binding) in registeredHotkeys {
            if binding.keyCode == keyCode && binding.modifiers == modifiers {
                onAction?(action)
                return
            }
        }
    }

    // MARK: - Persistence

    private static let hotkeyDefaultsKey = "copippe_hotkeys"

    private func saveHotkeys() {
        var serializable: [String: HotkeyBinding] = [:]
        for (action, binding) in registeredHotkeys {
            let key: String
            switch action {
            case .showHistory: key = "showHistory"
            case .showSnippets: key = "showSnippets"
            case .snippet(let id): key = "snippet:\(id.uuidString)"
            }
            serializable[key] = binding
        }
        if let data = try? JSONEncoder().encode(serializable) {
            defaults.set(data, forKey: Self.hotkeyDefaultsKey)
        }
    }

    private func loadHotkeys() {
        guard let data = defaults.data(forKey: Self.hotkeyDefaultsKey),
              let serializable = try? JSONDecoder().decode([String: HotkeyBinding].self, from: data) else {
            return
        }
        registeredHotkeys = [:]
        for (key, binding) in serializable {
            let action: HotkeyAction
            if key == "showHistory" {
                action = .showHistory
            } else if key == "showSnippets" {
                action = .showSnippets
            } else if key.hasPrefix("snippet:"), let uuid = UUID(uuidString: String(key.dropFirst(8))) {
                action = .snippet(uuid)
            } else {
                continue
            }
            registeredHotkeys[action] = binding
        }
    }
}
