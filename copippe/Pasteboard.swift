import AppKit

/// クリップボード書き込みの共通入口(clearContents + set のペア漏れを防ぐ)。
enum Pasteboard {
    static func copy(_ string: String, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    static func copy(_ image: NSImage, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        if let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }
}
