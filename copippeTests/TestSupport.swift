import Foundation

/// テスト用に隔離された UserDefaults。
/// インスタンス解放時に永続ドメインを削除し、~/Library/Preferences に plist を残さない。
/// 注意: テスト関数より先に解放されると掃除が走った後に書き込みが復活するため、
/// 必ず @Suite struct のストアドプロパティとして保持すること(makeXxx() 内のローカル変数にしない)。
final class TestDefaults {
    private let suiteName = "copippe-tests-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
        // synchronize で cfprefsd の保留書き込みを確定させてからファイルを消す。
        // これを挟まないと、削除後に空の plist が非同期で書き出されて残留する。
        defaults.synchronize()
        let plistURL = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Preferences/\(suiteName).plist")
        try? FileManager.default.removeItem(at: plistURL)
    }
}
