import AppKit
import ScreenCaptureKit
import CoreGraphics

@MainActor
final class ScreenCaptureService {
    enum Mode { case area, window, fullscreen }
    enum CaptureError: LocalizedError {
        case permission, unavailable, noWindow
        var errorDescription: String? {
            switch self {
            case .permission: return AppPreferences.shared.tr(.capturePermission)
            case .unavailable: return AppPreferences.shared.tr(.captureUnavailable)
            case .noWindow: return AppPreferences.shared.tr(.noWindow)
            }
        }
    }
    static let shared = ScreenCaptureService()
    private var overlayWindow: NSWindow?

    func capture(_ mode: Mode, targetPID: pid_t? = nil) async throws -> NSImage? {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else { throw CaptureError.permission }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        switch mode {
        case .window:
            return try await captureWindow(content: content, targetPID: targetPID)
        case .fullscreen, .area:
            let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
            guard let screen, let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let display = content.displays.first(where: { $0.displayID == number.uint32Value }) else { throw CaptureError.unavailable }
            let ownWindows = content.windows.filter { $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier }
            let filter = SCContentFilter(display: display, excludingWindows: ownWindows)
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration(for: filter))
            let image = NSImage(cgImage: cgImage, size: screen.frame.size)
            if mode == .fullscreen { return image }
            return await selectArea(screen: screen, image: image, cgImage: cgImage)
        }
    }
    private func configuration(for filter: SCContentFilter) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        config.width = max(1, Int((filter.contentRect.width * scale).rounded()))
        config.height = max(1, Int((filter.contentRect.height * scale).rounded()))
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        return config
    }
    private func captureWindow(content: SCShareableContent, targetPID: pid_t?) async throws -> NSImage {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let desiredPID = targetPID == ownPID ? nil : targetPID
        let infos = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        let windowIDs = infos.compactMap { info -> CGWindowID? in
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  desiredPID == nil || pid == desiredPID,
                  let number = info[kCGWindowNumber as String] as? NSNumber else { return nil }
            return number.uint32Value
        }
        let target = windowIDs.compactMap { id in content.windows.first { $0.windowID == id } }
            .first { $0.isOnScreen && $0.frame.width > 60 && $0.frame.height > 60 }
        guard let target else { throw CaptureError.noWindow }
        let filter = SCContentFilter(desktopIndependentWindow: target)
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration(for: filter))
        return NSImage(cgImage: cgImage, size: filter.contentRect.size)
    }
    private func selectArea(screen: NSScreen, image: NSImage, cgImage: CGImage) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let panel = AreaSelectionWindow(screen: screen, backgroundSnapshot: image) { [weak self] rect in
                self?.overlayWindow?.orderOut(nil)
                self?.overlayWindow = nil
                guard let rect, rect.width >= 2, rect.height >= 2 else { continuation.resume(returning: nil); return }
                let scaleX = CGFloat(cgImage.width) / screen.frame.width
                let scaleY = CGFloat(cgImage.height) / screen.frame.height
                let crop = CGRect(x: rect.minX * scaleX, y: (screen.frame.height - rect.maxY) * scaleY,
                                  width: rect.width * scaleX, height: rect.height * scaleY).integral
                    .intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
                guard !crop.isEmpty, let cropped = cgImage.cropping(to: crop) else { continuation.resume(returning: nil); return }
                continuation.resume(returning: NSImage(cgImage: cropped, size: NSSize(width: crop.width / scaleX, height: crop.height / scaleY)))
            }
            overlayWindow = panel
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(panel.contentView)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

/// Кастомное полноэкранное окно выбора области с прицелом и размерами в пикселях
final class AreaSelectionWindow: NSPanel {
    init(screen: NSScreen, backgroundSnapshot: NSImage, onComplete: @escaping (CGRect?) -> Void) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        
        let selectorView = AreaSelectionView(
            frame: CGRect(origin: .zero, size: screen.frame.size),
            snapshot: backgroundSnapshot,
            onComplete: onComplete
        )
        self.contentView = selectorView
    }
    
    override var canBecomeKey: Bool { true }
}

final class AreaSelectionView: NSView {
    private let snapshot: NSImage
    private let onComplete: (CGRect?) -> Void
    private var isFinished = false
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint = .zero
    
    init(frame: NSRect, snapshot: NSImage, onComplete: @escaping (CGRect?) -> Void) {
        self.snapshot = snapshot
        self.onComplete = onComplete
        super.init(frame: frame)

    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            finish(nil)
        }
    }
    
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    private func finish(_ rect: CGRect?) {
        guard !isFinished else { return }
        isFinished = true
        onComplete(rect)
    }
    override func mouseMoved(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        startPoint = pt
        currentPoint = pt
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let start = startPoint else {
            finish(nil)
            return
        }
        let raw = convert(event.locationInWindow, from: nil)
        let end = CGPoint(x: min(max(0, raw.x), bounds.width), y: min(max(0, raw.y), bounds.height))
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        finish(rect)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        snapshot.draw(in: bounds)
        
        // Затемнение вокруг области выделения
        NSColor.black.withAlphaComponent(0.42).setFill()
        bounds.fill()
        
        if let start = startPoint {
            let selection = CGRect(
                x: min(start.x, currentPoint.x),
                y: min(start.y, currentPoint.y),
                width: abs(currentPoint.x - start.x),
                height: abs(currentPoint.y - start.y)
            )
            
            // Отрисовка светлого участка внутри выделения
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: selection).addClip()
            snapshot.draw(in: bounds)
            NSGraphicsContext.restoreGraphicsState()
            
            // Белая + синяя рамка выделения
            let path = NSBezierPath(rect: selection)
            path.lineWidth = 1.5
            NSColor.white.setStroke()
            path.stroke()
            
            // Плашка с размерами в пикселях
            let scale = window?.backingScaleFactor ?? 1
            let dimensionText = "\(Int(selection.width * scale)) × \(Int(selection.height * scale)) px"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let size = dimensionText.size(withAttributes: attrs)
            let pillRect = CGRect(
                x: selection.minX,
                y: max(8, selection.minY - 28),
                width: size.width + 16,
                height: 22
            )
            let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 6, yRadius: 6)
            NSColor.black.withAlphaComponent(0.78).setFill()
            pillPath.fill()
            dimensionText.draw(at: CGPoint(x: pillRect.minX + 8, y: pillRect.minY + 3), withAttributes: attrs)
        }
    }
}
