import Foundation
import Testing
@testable import copippe

@Suite("AppState Tests")
struct AppStateTests {

    private let testDefaults = TestDefaults()

    private func makeState() -> AppState {
        AppState(defaults: testDefaults.defaults)
    }

    @Test("Initial state defaults to active")
    func initialState() {
        let state = makeState()
        #expect(state.isActive == true)
    }

    @Test("Toggle changes state")
    func toggleActivation() {
        let state = makeState()
        let initial = state.isActive

        state.toggleActivation()
        #expect(state.isActive == !initial)

        state.toggleActivation()
        #expect(state.isActive == initial)
    }

    @Test("State persists to UserDefaults")
    func statePersistence() {
        let state = makeState()

        state.isActive = false
        #expect(testDefaults.defaults.bool(forKey: "copippe_isActive") == false)

        state.isActive = true
        #expect(testDefaults.defaults.bool(forKey: "copippe_isActive") == true)
    }

    @Test("Max history count defaults to 30")
    func maxHistoryCountDefault() {
        let state = makeState()
        #expect(state.maxHistoryCount == 30)
    }

    @Test("Max history count persists to UserDefaults")
    func maxHistoryCountPersistence() {
        let state = makeState()

        state.maxHistoryCount = 50
        #expect(testDefaults.defaults.integer(forKey: "copippe_maxHistoryCount") == 50)
    }

    @Test("Default plain text mode defaults to true")
    func defaultPlainTextModeDefault() {
        let state = makeState()
        #expect(state.defaultPlainTextMode == true)
    }

    @Test("Default plain text mode persists to UserDefaults")
    func defaultPlainTextModePersistence() {
        let state = makeState()

        state.defaultPlainTextMode = false
        #expect(testDefaults.defaults.bool(forKey: "copippe_defaultPlainTextMode") == false)
    }
}
