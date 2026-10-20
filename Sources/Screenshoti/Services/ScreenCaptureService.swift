import AppKit
import ScreenCaptureKit
import CoreGraphics

@MainActor
final class ScreenCaptureService {
    enum Mode { case area, window, fullscreen }
    enum CaptureError: LocalizedError {
        case permission, unavailable, invalidImage, processFailed(Int32)
        var errorDescription: String? {
            switch self {
            case .permission: return AppPreferences.shared.tr(.capturePermission)
            case .unavailable, .invalidImage: return AppPreferences.shared.tr(.captureUnavailable)
            case .processFailed(let code):
                return AppPreferences.shared.language == .ru ? "Не удалось сделать снимок (код \(code))." : "Could not capture the screen (code \(code))."
            }
        }
    }
    static let shared = ScreenCaptureService()
    private var activeProcess: Process?

    func capture(_ mode: Mode) async throws -> NSImage? {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureError.permission }
        switch mode {
        case .area, .window:
            return try await interactiveCapture(startsWithWindow: mode == .window)
        case .fullscreen:
            return try await captureFullscreen()
        }
    }

    /// The OS owns hover highlighting, Space to switch area/window mode, and Escape cancellation.
    private func interactiveCapture(startsWithWindow: Bool) async throws -> NSImage? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Screenshoti-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory); activeProcess = nil }
        let output = directory.appendingPathComponent("capture.png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = Self.interactiveArguments(startsWithWindow: startsWithWindow, output: output)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        activeProcess = process
        let data: Data? = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                do {
                    if FileManager.default.fileExists(atPath: output.path) {
                        continuation.resume(returning: try Data(contentsOf: output))
                    } else if process.terminationStatus == 0 || process.terminationStatus == 1 {
                        continuation.resume(returning: nil)
                    } else { continuation.resume(throwing: CaptureError.processFailed(process.terminationStatus)) }
                } catch { continuation.resume(throwing: error) }
            }
            do { try process.run() }
            catch { process.terminationHandler = nil; continuation.resume(throwing: error) }
        }
        guard let data else { return nil }
        guard let image = NSImage(data: data) else { throw CaptureError.invalidImage }
        return image
    }
    static func interactiveArguments(startsWithWindow: Bool, output: URL) -> [String] {
        var args = ["-i", "-x", "-o", "-t", "png"]
        if startsWithWindow { args.append("-W") }
        args.append(output.path)
        return args
    }
    private func captureFullscreen() async throws -> NSImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen, let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else { throw CaptureError.unavailable }
        let ownWindows = content.windows.filter { $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
        let config = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        config.width = max(1, Int((filter.contentRect.width * scale).rounded()))
        config.height = max(1, Int((filter.contentRect.height * scale).rounded()))
        config.showsCursor = false
        let cg = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return NSImage(cgImage: cg, size: screen.frame.size)
    }
}
