import SwiftUI
import AppKit

@MainActor
final class FloatingWindowsManager {
    static let shared = FloatingWindowsManager()
    private var pinnedWindows: [NSWindow] = []
    private var quickOverlayPanel: NSPanel?
    
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
        pinnedWindows.append(panel)
    }
    
    /// Показать быстрый оверлей в правом нижнем углу после захвата
    func showQuickCornerOverlay(image: NSImage, onEdit: @escaping () -> Void, onPin: @escaping () -> Void) {
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
        
        let view = QuickOverlayCardView(
            image: image,
            onEdit: {
                panel.close()
                onEdit()
            },
            onPin: {
                panel.close()
                onPin()
            },
            onDismiss: {
                panel.close()
            }
        )
        panel.contentView = NSHostingView(rootView: view)
        panel.orderFrontRegardless()
        self.quickOverlayPanel = panel
        
        // Автоматическое скрытие через 6 секунд
        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            panel.close()
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
