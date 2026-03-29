import Foundation
import Observation

@Observable
final class AppState {
    private static let isActiveKey = "copippe_isActive"
    private static let maxHistoryCountKey = "copippe_maxHistoryCount"
    private static let defaultPlainTextModeKey = "copippe_defaultPlainTextMode"

    var isActive: Bool {
        didSet {
            UserDefaults.standard.set(isActive, forKey: Self.isActiveKey)
        }
    }

    var maxHistoryCount: Int {
        didSet {
            UserDefaults.standard.set(maxHistoryCount, forKey: Self.maxHistoryCountKey)
        }
    }

    var defaultPlainTextMode: Bool {
        didSet {
            UserDefaults.standard.set(defaultPlainTextMode, forKey: Self.defaultPlainTextModeKey)
        }
    }

    init() {
        // Default to active on first launch
        if UserDefaults.standard.object(forKey: Self.isActiveKey) == nil {
            self.isActive = true
            UserDefaults.standard.set(true, forKey: Self.isActiveKey)
        } else {
            self.isActive = UserDefaults.standard.bool(forKey: Self.isActiveKey)
        }

        // Default max history count: 30
        if UserDefaults.standard.object(forKey: Self.maxHistoryCountKey) == nil {
            self.maxHistoryCount = 30
            UserDefaults.standard.set(30, forKey: Self.maxHistoryCountKey)
        } else {
            self.maxHistoryCount = UserDefaults.standard.integer(forKey: Self.maxHistoryCountKey)
        }

        // Default plain text mode: true
        if UserDefaults.standard.object(forKey: Self.defaultPlainTextModeKey) == nil {
            self.defaultPlainTextMode = true
            UserDefaults.standard.set(true, forKey: Self.defaultPlainTextModeKey)
        } else {
            self.defaultPlainTextMode = UserDefaults.standard.bool(forKey: Self.defaultPlainTextModeKey)
        }
    }

    func toggleActivation() {
        isActive.toggle()
    }
}
