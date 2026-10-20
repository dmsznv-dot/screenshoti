import AppKit
import Testing
import UniformTypeIdentifiers
@testable import Screenshoti

@Suite(.serialized) @MainActor
struct StartupAndDragTests {
    @Test func startupRequestsMissingAccessOnceAndPresentsSetup() {
        var requests = 0, presentations = 0
        let access = CapturePermissionController(preflight: { false }, request: { requests += 1; return false },
            presentSetup: { presentations += 1 })
        access.beginStartup()
        access.beginStartup()
        #expect(requests == 1)
        #expect(presentations >= 1)
        #expect(!access.hasAccess && access.didRequestAccess)
    }

    @Test func existingAccessDoesNotPrompt() {
        var requests = 0, presentations = 0
        let access = CapturePermissionController(preflight: { true }, request: { requests += 1; return true },
            presentSetup: { presentations += 1 })
        access.beginStartup()
        #expect(access.hasAccess)
        #expect(requests == 0 && presentations == 0)
    }

    @Test func returningFromSettingsRefreshesActualAccess() {
        var granted = false, requests = 0
        let access = CapturePermissionController(preflight: { granted }, request: { requests += 1; return false },
            presentSetup: {})
        access.beginStartup()
        granted = true
        access.refresh()
        #expect(access.hasAccess)
        #expect(access.ensureAccess())
        #expect(requests == 1)
    }

    @Test func missingPermissionLeavesDocumentAndCaptureStateUntouched() {
        let access = CapturePermissionController(preflight: { false }, request: { false }, presentSetup: {})
        let editor = EditorViewModel(permissionController: access)
        let source = editor.sourceImage
        let annotation = AnnotationItem(tool: .rectangle, startPoint: .zero, endPoint: CGPoint(x: 20, y: 20))
        editor.addAnnotation(annotation)
        editor.triggerAreaCapture()
        #expect(!editor.isCapturing)
        #expect(editor.sourceImage === source)
        #expect(editor.annotations == [annotation])
        #expect(editor.history.isEmpty)
    }

    @Test func dragExportsARealPNGAtOriginalPixelResolution() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = try sourceImage()
        let url = try ScreenshotDragExport.makeFile(for: image, directory: directory)
        #expect(url.pathExtension == "png")
        let data = try Data(contentsOf: url)
        #expect(Array(data.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
        let bitmap = try #require(NSBitmapImageRep(data: data))
        #expect(bitmap.pixelsWide == 120 && bitmap.pixelsHigh == 80)
        let second = try ScreenshotDragExport.makeFile(for: image, directory: directory)
        #expect(second != url)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func dragProviderOffersFileURLAndPNG() throws {
        let provider = ScreenshotDragExport.itemProvider(for: try sourceImage())
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
        #expect(provider.hasItemConformingToTypeIdentifier(UTType.png.identifier))
        #expect(provider.suggestedName?.hasSuffix(".png") == true)
    }

    private func sourceImage() throws -> NSImage {
        let context = try #require(CGContext(data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        return NSImage(cgImage: try #require(context.makeImage()), size: CGSize(width: 60, height: 40))
    }
}
