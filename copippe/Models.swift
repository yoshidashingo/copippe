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
