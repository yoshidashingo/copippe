import Foundation
import AppKit

// MARK: - History Entry

enum HistoryEntry: Codable, Identifiable {
    case text(id: UUID = UUID(), value: String)
    case image(id: UUID = UUID(), imageID: UUID)

    var id: UUID {
        switch self {
        case .text(let id, _): return id
        case .image(let id, _): return id
        }
    }

    var textValue: String? {
        if case .text(_, let value) = self { return value }
        return nil
    }

    var imageID: UUID? {
        if case .image(_, let imageID) = self { return imageID }
        return nil
    }
}

extension HistoryEntry: Equatable {
    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        switch (lhs, rhs) {
        case (.text(_, let a), .text(_, let b)): return a == b
        case (.image(_, let a), .image(_, let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Snippet

struct SnippetFolder: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var snippets: [Snippet]

    init(id: UUID = UUID(), name: String, snippets: [Snippet] = []) {
        self.id = id
        self.name = name
        self.snippets = snippets
    }
}

struct Snippet: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var hotkey: HotkeyBinding?

    init(id: UUID = UUID(), title: String, content: String, hotkey: HotkeyBinding? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.hotkey = hotkey
    }
}

// MARK: - Hotkey

struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt // NSEvent.ModifierFlags.rawValue

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }

    var displayString: String {
        var parts: [String] = []
        let flags = modifierFlags
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(KeyCodeMap.string(for: keyCode))
        return parts.joined()
    }
}

enum HotkeyAction: Codable, Equatable, Hashable {
    case showHistory
    case showSnippets
    case snippet(UUID)
}

// MARK: - Popup

enum PopupTab {
    case history
    case snippets
}

// MARK: - Key Code Mapping

enum KeyCodeMap {
    private static let map: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        49: "Space", 50: "`", 51: "Delete", 53: "Escape",
        36: "Return", 48: "Tab",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15",
        118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    static func string(for keyCode: UInt16) -> String {
        map[keyCode] ?? "Key\(keyCode)"
    }
}
