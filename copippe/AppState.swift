import Foundation
import Observation

@Observable
final class AppState {
    private static let isActiveKey = "copippe_isActive"

    var isActive: Bool {
        didSet {
            UserDefaults.standard.set(isActive, forKey: Self.isActiveKey)
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
    }

    func toggleActivation() {
        isActive.toggle()
    }
}
