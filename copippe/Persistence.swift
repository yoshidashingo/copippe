import Foundation
import os

/// Application Support 配下の copippe ディレクトリ解決(全ストレージで共通)
enum AppDirectories {
    static func appSupport() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("copippe", isDirectory: true)
    }
}

/// JSON ファイルへの Codable 値の保存・読込(atomic write、親ディレクトリ自動作成)
struct JSONFileStore<Value: Codable> {
    let fileURL: URL

    func load() -> Value? {
        guard let data = loadData() else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    /// マイグレーション用に生データも読めるようにする(HistoryManager の v1 フォールバックで使用)
    func loadData() -> Data? {
        try? Data(contentsOf: fileURL)
    }

    func save(_ value: Value) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(value)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Logger.persistence.error("Failed to save \(fileURL.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
