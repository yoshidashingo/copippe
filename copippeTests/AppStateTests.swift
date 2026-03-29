import Foundation
import Testing
@testable import copippe

@Suite("AppState Tests")
struct AppStateTests {

    @Test("Initial state defaults to active")
    func initialState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "copippe_isActive")

        let state = AppState()
        #expect(state.isActive == true)
    }

    @Test("Toggle changes state")
    func toggleActivation() {
        let state = AppState()
        let initial = state.isActive

        state.toggleActivation()
        #expect(state.isActive == !initial)

        state.toggleActivation()
        #expect(state.isActive == initial)
    }

    @Test("State persists to UserDefaults")
    func statePersistence() {
        let state = AppState()
        state.isActive = false

        let persisted = UserDefaults.standard.bool(forKey: "copippe_isActive")
        #expect(persisted == false)

        state.isActive = true
        let persisted2 = UserDefaults.standard.bool(forKey: "copippe_isActive")
        #expect(persisted2 == true)
    }

    @Test("Max history count defaults to 30")
    func maxHistoryCountDefault() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "copippe_maxHistoryCount")

        let state = AppState()
        #expect(state.maxHistoryCount == 30)
    }

    @Test("Max history count persists to UserDefaults")
    func maxHistoryCountPersistence() {
        let state = AppState()
        state.maxHistoryCount = 50

        let persisted = UserDefaults.standard.integer(forKey: "copippe_maxHistoryCount")
        #expect(persisted == 50)

        // Cleanup
        state.maxHistoryCount = 30
    }

    @Test("Default plain text mode defaults to true")
    func defaultPlainTextModeDefault() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "copippe_defaultPlainTextMode")

        let state = AppState()
        #expect(state.defaultPlainTextMode == true)
    }

    @Test("Default plain text mode persists to UserDefaults")
    func defaultPlainTextModePersistence() {
        let state = AppState()
        state.defaultPlainTextMode = false

        let persisted = UserDefaults.standard.bool(forKey: "copippe_defaultPlainTextMode")
        #expect(persisted == false)

        // Cleanup
        state.defaultPlainTextMode = true
    }
}
