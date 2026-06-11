import Foundation
import Observation

@Observable
final class AppState {
    private static let isActiveKey = "copippe_isActive"
    private static let maxHistoryCountKey = "copippe_maxHistoryCount"

    @ObservationIgnored private let defaults: UserDefaults

    var isActive: Bool {
        didSet {
            defaults.set(isActive, forKey: Self.isActiveKey)
        }
    }

    var maxHistoryCount: Int {
        didSet {
            defaults.set(maxHistoryCount, forKey: Self.maxHistoryCountKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Self.isActiveKey: true,
            Self.maxHistoryCountKey: 30,
        ])
        self.isActive = defaults.bool(forKey: Self.isActiveKey)
        self.maxHistoryCount = defaults.integer(forKey: Self.maxHistoryCountKey)
    }

    func toggleActivation() {
        isActive.toggle()
    }
}
