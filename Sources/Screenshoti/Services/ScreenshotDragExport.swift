import AppKit
import UniformTypeIdentifiers

@MainActor
enum ScreenshotDragExport {
    private static var cacheDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("com.dmsznv.screenshoti-drag", isDirectory: true)
    }

    static func makeFile(for image: NSImage, directory: URL? = nil) throws -> URL {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let directory = directory ?? cacheDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Screenshoti-\(UUID().uuidString).png")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func itemProvider(for image: NSImage) -> NSItemProvider {
        do {
            removeExpiredExports()
            let url = try makeFile(for: image)
            let provider = NSItemProvider(contentsOf: url) ?? NSItemProvider()
            provider.suggestedName = url.lastPathComponent
            // Finder consumes the file URL; image destinations can request PNG.
            provider.registerObject(url as NSURL, visibility: .all)
            if !provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
                provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
                    do { completion(try Data(contentsOf: url), nil) }
                    catch { completion(nil, error) }
                    return nil
                }
            }
            return provider
        } catch {
            NSLog("Screenshoti PNG drag export failed: %@", error.localizedDescription)
            return NSItemProvider(object: image)
        }
    }

    private static func removeExpiredExports() {
        // Keep files alive after the drag so asynchronous recipients can finish.
        let manager = FileManager.default
        guard let urls = try? manager.contentsOfDirectory(at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-86_400)
        for url in urls where url.lastPathComponent.hasPrefix("Screenshoti-") && url.pathExtension == "png" {
            if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               date < cutoff { try? manager.removeItem(at: url) }
        }
    }
}
