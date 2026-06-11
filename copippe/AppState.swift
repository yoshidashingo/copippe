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

        // Default to active on first launch
        if defaults.object(forKey: Self.isActiveKey) == nil {
            self.isActive = true
            defaults.set(true, forKey: Self.isActiveKey)
        } else {
            self.isActive = defaults.bool(forKey: Self.isActiveKey)
        }

        // Default max history count: 30
        if defaults.object(forKey: Self.maxHistoryCountKey) == nil {
            self.maxHistoryCount = 30
            defaults.set(30, forKey: Self.maxHistoryCountKey)
        } else {
            self.maxHistoryCount = defaults.integer(forKey: Self.maxHistoryCountKey)
        }

    }

    func toggleActivation() {
        isActive.toggle()
    }
}
