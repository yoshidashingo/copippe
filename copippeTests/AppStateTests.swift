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
}
