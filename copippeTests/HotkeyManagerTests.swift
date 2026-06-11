import Testing
import AppKit
@testable import copippe

@Suite("HotkeyManager Tests")
@MainActor
struct HotkeyManagerTests {

    private let testDefaults = TestDefaults()

    private func makeManager() -> HotkeyManager {
        HotkeyManager(defaults: testDefaults.defaults)
    }

    @Test("Register and retrieve hotkey")
    func registerHotkey() {
        let manager = makeManager()
        let binding = HotkeyBinding(
            keyCode: 9, // V
            modifiers: NSEvent.ModifierFlags([.shift, .command]).rawValue
        )

        manager.registerHotkey(action: .showHistory, binding: binding)

        let retrieved = manager.binding(for: .showHistory)
        #expect(retrieved != nil)
        #expect(retrieved?.keyCode == 9)
    }

    @Test("Unregister hotkey")
    func unregisterHotkey() {
        let manager = makeManager()
        let binding = HotkeyBinding(keyCode: 9, modifiers: 0)

        manager.registerHotkey(action: .showHistory, binding: binding)
        manager.unregisterHotkey(action: .showHistory)

        #expect(manager.binding(for: .showHistory) == nil)
    }

    @Test("Check conflict detects duplicate binding")
    func checkConflict() {
        let manager = makeManager()
        let binding = HotkeyBinding(keyCode: 9, modifiers: 0)

        manager.registerHotkey(action: .showHistory, binding: binding)

        let conflict = manager.checkConflict(binding: binding)
        #expect(conflict == .showHistory)
    }

    @Test("Check conflict with exclusion")
    func checkConflictExcluding() {
        let manager = makeManager()
        let binding = HotkeyBinding(keyCode: 9, modifiers: 0)

        manager.registerHotkey(action: .showHistory, binding: binding)

        let conflict = manager.checkConflict(binding: binding, excluding: .showHistory)
        #expect(conflict == nil)
    }

    @Test("Update hotkey replaces binding")
    func updateHotkey() {
        let manager = makeManager()
        let old = HotkeyBinding(keyCode: 9, modifiers: 0)
        let new = HotkeyBinding(keyCode: 12, modifiers: 0)

        manager.registerHotkey(action: .showHistory, binding: old)
        manager.updateHotkey(action: .showHistory, binding: new)

        let retrieved = manager.binding(for: .showHistory)
        #expect(retrieved?.keyCode == 12)
    }

    @Test("HotkeyBinding display string")
    func displayString() {
        let binding = HotkeyBinding(
            keyCode: 9, // V
            modifiers: NSEvent.ModifierFlags([.shift, .command]).rawValue
        )

        let display = binding.displayString
        #expect(display.contains("⇧"))
        #expect(display.contains("⌘"))
        #expect(display.contains("V"))
    }
}
