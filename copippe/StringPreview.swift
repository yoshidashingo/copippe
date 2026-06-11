import Foundation

extension String {
    /// メニュー・リスト表示用の 1 行プレビュー(改行をスペース化し maxLength で切り詰め)。
    func singleLinePreview(maxLength: Int) -> String {
        let singleLine = replacingOccurrences(of: "\n", with: " ")
        guard singleLine.count > maxLength else { return singleLine }
        return String(singleLine.prefix(maxLength)) + "..."
    }
}
