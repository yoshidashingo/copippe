import Foundation
import AppKit

final class ImageStore {
    private let imagesDirectory: URL
    private var thumbnailCache: [UUID: NSImage] = [:]

    init() {
        let container = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        imagesDirectory = container.appendingPathComponent("copippe/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    func save(_ image: NSImage) -> UUID? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let id = UUID()
        let fileURL = imagesDirectory.appendingPathComponent("\(id.uuidString).png")
        do {
            try pngData.write(to: fileURL, options: .atomic)
            return id
        } catch {
            return nil
        }
    }

    func load(id: UUID) -> NSImage? {
        let fileURL = imagesDirectory.appendingPathComponent("\(id.uuidString).png")
        return NSImage(contentsOf: fileURL)
    }

    func thumbnail(id: UUID, maxSize: CGFloat = 40) -> NSImage? {
        if let cached = thumbnailCache[id] {
            return cached
        }

        guard let image = load(id: id) else { return nil }

        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }

        let scale = min(maxSize / originalSize.width, maxSize / originalSize.height, 1.0)
        let newSize = NSSize(width: originalSize.width * scale, height: originalSize.height * scale)

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()

        thumbnailCache[id] = thumbnail
        return thumbnail
    }

    func delete(id: UUID) {
        let fileURL = imagesDirectory.appendingPathComponent("\(id.uuidString).png")
        try? FileManager.default.removeItem(at: fileURL)
        thumbnailCache.removeValue(forKey: id)
    }

    func deleteAll() {
        if let files = try? FileManager.default.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
        thumbnailCache.removeAll()
    }
}
