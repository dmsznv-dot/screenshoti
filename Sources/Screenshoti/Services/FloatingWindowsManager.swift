import SwiftUI
import AppKit

@MainActor
final class FloatingWindowsManager {
    static let shared = FloatingWindowsManager()
    private var pinnedWindows: [NSWindow] = []
    private var quickOverlayPanel: NSPanel?
    private var overlayDismissTask: Task<Void, Never>?
    private var hiddenForCapture: [NSWindow] = []
    func hideForCapture() {
        hiddenForCapture = (pinnedWindows + [quickOverlayPanel].compactMap { $0 }).filter(\.isVisible)
        hiddenForCapture.forEach { $0.orderOut(nil) }
    }
    func restoreAfterCapture() {
        let surviving = pinnedWindows + [quickOverlayPanel].compactMap { $0 }
        hiddenForCapture.filter { hidden in surviving.contains { $0 === hidden } }.forEach { $0.orderFrontRegardless() }
        hiddenForCapture.removeAll()
    }
    
    /// Закрепить скриншот поверх всех окон (Pin to Screen)
    func pinImageToScreen(_ image: NSImage) {
        let size = NSSize(
            width: min(max(image.size.width * 0.75, 260), 640),
            height: min(max(image.size.height * 0.75, 180), 480)
        )
        
        let panel = NSPanel(
            contentRect: NSRect(x: 200, y: 200, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        
        let contentView = PinnedScreenshotView(image: image) { [weak panel] in
            panel?.close()
        }
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        pinnedWindows.removeAll { !$0.isVisible }
        pinnedWindows.append(panel)
    }
    
    /// Показать быстрый оверлей в правом нижнем углу после захвата
    func showQuickCornerOverlay(image: NSImage, onEdit: @escaping () -> Void, onPin: @escaping () -> Void) {
        overlayDismissTask?.cancel()
        quickOverlayPanel?.close()
        
        guard let screen = NSScreen.main else { return }
        let width: CGFloat = 280
        let height: CGFloat = 190
        let origin = CGPoint(
            x: screen.visibleFrame.maxX - width - 20,
            y: screen.visibleFrame.minY + 20
        )
        
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        
        let view = QuickOverlayCardView(
            image: image,
            onEdit: { [weak panel] in
                panel?.orderOut(nil)
                onEdit()
            },
            onPin: { [weak panel] in
                panel?.orderOut(nil)
                onPin()
            },
            onDismiss: { [weak panel] in
                panel?.orderOut(nil)
            }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.orderFrontRegardless()
        self.quickOverlayPanel = panel
        
        // Автоматическое скрытие через 6 секунд
        overlayDismissTask = Task { [weak panel] in
            do { try await Task.sleep(nanoseconds: 6_000_000_000) } catch { return }
            panel?.orderOut(nil)
        }
    }
}

struct PinnedScreenshotView: View {
    let image: NSImage
    let onClose: () -> Void
    @State private var opacity: Double = 1.0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(opacity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            HStack(spacing: 6) {
                Slider(value: $opacity, in: 0.25...1.0)
                    .frame(width: 70)
                    .controlSize(.mini)
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
            }
            .padding(6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(8)
        }
    }
}

struct QuickOverlayCardView: View {
    let image: NSImage
    let onEdit: () -> Void
    let onPin: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 115)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onDrag {
                    NSItemProvider(object: image)
                }
            
            HStack(spacing: 10) {
                Button(action: onEdit) {
                    Label("Studio", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button(action: onPin) {
                    Label("Pin", systemImage: "pin.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        )
    }
}
