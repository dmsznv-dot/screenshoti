import AppKit
import ScreenCaptureKit
import CoreGraphics

@MainActor
final class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    private var overlayWindows: [NSWindow] = []
    
    /// Захват всего активного экрана через ScreenCaptureKit (с фолбэком на CGDisplayCreateImage)
    func captureFullscreen() async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                return fallbackFullscreenCapture()
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width * 2
            config.height = display.height * 2
            config.showsCursor = false
            
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: cgImage, size: NSSize(width: display.width, height: display.height))
        } catch {
            return fallbackFullscreenCapture()
        }
    }
    
    /// Захват верхнего активного окна приложения
    func captureFrontWindow() async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let ownBundleID = Bundle.main.bundleIdentifier
            guard let targetWindow = content.windows.first(where: {
                $0.isOnScreen && $0.frame.width > 120 && $0.frame.height > 120 &&
                $0.owningApplication?.bundleIdentifier != ownBundleID
            }) else {
                return await captureFullscreen()
            }
            
            let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
            let config = SCStreamConfiguration()
            config.width = Int(targetWindow.frame.width * 2)
            config.height = Int(targetWindow.frame.height * 2)
            config.showsCursor = false
            
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: cgImage, size: targetWindow.frame.size)
        } catch {
            return await captureFullscreen()
        }
    }
    
    /// Интерактивный захват области с кастомным прицелом и координатами
    func beginInteractiveAreaCapture(completion: @escaping (NSImage?) -> Void) {
        guard let screen = NSScreen.main else {
            completion(nil)
            return
        }
        
        // Сначала делаем мгновенный снимок экрана для оверлея
        guard let cgScreenImage = CGDisplayCreateImage(CGMainDisplayID()) else {
            completion(nil)
            return
        }
        let fullNSImage = NSImage(cgImage: cgScreenImage, size: screen.frame.size)
        
        let panel = AreaSelectionWindow(screen: screen, backgroundSnapshot: fullNSImage) { [weak self] selectedRect in
            self?.closeOverlays()
            guard let rect = selectedRect, rect.width > 8, rect.height > 8 else {
                completion(nil)
                return
            }
            
            // Пересчет координат из системы AppKit (снизу-вверх) в CoreGraphics (сверху-вниз)
            let scale = CGFloat(cgScreenImage.width) / screen.frame.width
            let flippedY = screen.frame.height - rect.origin.y - rect.height
            let cropRect = CGRect(
                x: rect.origin.x * scale,
                y: flippedY * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )
            
            if let croppedCG = cgScreenImage.cropping(to: cropRect) {
                let result = NSImage(cgImage: croppedCG, size: rect.size)
                completion(result)
            } else {
                completion(nil)
            }
        }
        
        overlayWindows = [panel]
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closeOverlays() {
        for win in overlayWindows {
            win.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
    
    private func fallbackFullscreenCapture() -> NSImage? {
        guard let screen = NSScreen.main,
              let cgImg = CGDisplayCreateImage(CGMainDisplayID()) else { return nil }
        return NSImage(cgImage: cgImg, size: screen.frame.size)
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
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint = .zero
    
    init(frame: NSRect, snapshot: NSImage, onComplete: @escaping (CGRect?) -> Void) {
        self.snapshot = snapshot
        self.onComplete = onComplete
        super.init(frame: frame)
        NSCursor.crosshair.push()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            NSCursor.pop()
            onComplete(nil)
        }
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
        NSCursor.pop()
        guard let start = startPoint else {
            onComplete(nil)
            return
        }
        let end = convert(event.locationInWindow, from: nil)
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        onComplete(rect)
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
            snapshot.draw(in: selection, from: selection, operation: .sourceOver, fraction: 1.0)
            
            // Белая + синяя рамка выделения
            let path = NSBezierPath(rect: selection)
            path.lineWidth = 1.5
            NSColor.white.setStroke()
            path.stroke()
            
            // Плашка с размерами в пикселях
            let dimensionText = "\(Int(selection.width)) × \(Int(selection.height)) px"
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
