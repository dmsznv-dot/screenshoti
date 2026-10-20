import SwiftUI
import AppKit

@MainActor
final class FloatingWindowsManager: NSObject {
    static let shared = FloatingWindowsManager()

    private struct Preview {
        let id: UUID
        let panel: NSPanel
        let image: NSImage
        let onEdit: () -> Void
        let onPin: () -> Void
    }
    private final class WeakWindow {
        weak var window: NSWindow?
        init(_ window: NSWindow) { self.window = window }
    }

    private var pinnedWindows: [NSWindow] = []
    private var previews: [Preview] = []
    private var navigationPanel: NSPanel?
    private var previewScreen: NSScreen?
    private var currentPage = 0
    private var captureDepth = 0
    private var hiddenForCapture: [ObjectIdentifier: WeakWindow] = [:]

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    /// Keep weak references to all visible app windows, including Studio and Settings.
    /// Nested capture requests cannot restore windows while another capture is active.
    func hideForCapture() {
        captureDepth += 1
        for window in NSApp.windows where window.isVisible {
            hiddenForCapture[ObjectIdentifier(window)] = WeakWindow(window)
            window.orderOut(nil)
        }
    }

    func restoreAfterCapture() {
        guard captureDepth > 0 else { return }
        captureDepth -= 1
        guard captureDepth == 0 else { return }
        let windows = hiddenForCapture.values.compactMap(\.window)
        hiddenForCapture.removeAll()
        for window in windows where NSApp.windows.contains(where: { $0 === window }) {
            window.orderFrontRegardless()
        }
        relayoutPreviews()
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        hiddenForCapture.removeValue(forKey: ObjectIdentifier(window))
        pinnedWindows.removeAll { $0 === window }
        let oldCount = previews.count
        previews.removeAll { $0.panel === window }
        if oldCount != previews.count { relayoutPreviews() }
    }

    @objc private func screenParametersChanged() { relayoutPreviews() }

    /// Explicit Pin to Screen keeps a separately movable and resizable window.
    func pinImageToScreen(_ image: NSImage) {
        let size = NSSize(width: min(max(image.size.width * 0.75, 260), 640),
                          height: min(max(image.size.height * 0.75, 180), 480))
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .floating
        panel.title = AppPreferences.shared.language == .ru ? "Закреплённый снимок" : "Pinned Screenshot"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: PinnedScreenshotView(image: image) { [weak panel] in
            panel?.close()
        })
        panel.center()
        pinnedWindows.append(panel)
        if captureDepth == 0 { panel.orderFrontRegardless() }
    }

    /// Captures stay in the stack until the user dismisses, edits, or pins them.
    func showQuickCornerOverlay(image: NSImage, onEdit: @escaping () -> Void, onPin: @escaping () -> Void) {
        if previewScreen == nil { previewScreen = NSScreen.main ?? NSScreen.screens.first }
        let panel = makeOverlayPanel()
        let id = UUID()
        previews.append(Preview(id: id, panel: panel, image: image, onEdit: onEdit, onPin: onPin))
        // Reveal the newly captured image even when the previous page is full.
        currentPage = Int.max
        relayoutPreviews()
    }

    /// Call when the corner preference changes; display changes also trigger this automatically.
    func relayoutPreviews() {
        guard !previews.isEmpty else {
            navigationPanel?.orderOut(nil)
            currentPage = 0
            previewScreen = nil
            return
        }
        if let selected = previewScreen,
           let selectedNumber = selected.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            previewScreen = NSScreen.screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber) == selectedNumber
            }
        }
        guard let screen = previewScreen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        previewScreen = screen
        let layout = PreviewLayout(visibleFrame: screen.visibleFrame,
            corner: AppPreferences.shared.previewCorner, count: previews.count, page: currentPage)
        currentPage = layout.page
        for (index, preview) in previews.enumerated() {
            if layout.visibleRange.contains(index) {
                let frame = layout.frames[index - layout.visibleRange.lowerBound]
                let id = preview.id
                preview.panel.setFrame(frame, display: true)
                preview.panel.title = AppPreferences.shared.language == .ru ? "Превью снимка \(index + 1)" : "Screenshot Preview \(index + 1)"
                preview.panel.contentView = NSHostingView(rootView: QuickOverlayCardView(
                    image: preview.image,
                    onEdit: { [weak self] in self?.performAction(id: id, edit: true) },
                    onPin: { [weak self] in self?.performAction(id: id, edit: false) },
                    onDismiss: { [weak self] in self?.removePreview(id: id) }
                ))
                if captureDepth == 0 { preview.panel.orderFrontRegardless() }
            } else {
                hiddenForCapture.removeValue(forKey: ObjectIdentifier(preview.panel))
                preview.panel.orderOut(nil)
            }
        }
        if let frame = layout.navigationFrame {
            let panel = navigationPanel ?? makeOverlayPanel()
            navigationPanel = panel
            panel.title = AppPreferences.shared.language == .ru ? "Страницы превью" : "Preview Pages"
            panel.setFrame(frame, display: true)
            panel.contentView = NSHostingView(rootView: PreviewNavigationView(
                page: layout.page, pageCount: layout.pageCount, count: previews.count,
                onPrevious: { [weak self] in self?.changePage(by: -1) },
                onNext: { [weak self] in self?.changePage(by: 1) }
            ))
            if captureDepth == 0 { panel.orderFrontRegardless() }
        } else {
            if let navigationPanel { hiddenForCapture.removeValue(forKey: ObjectIdentifier(navigationPanel)) }
            navigationPanel?.orderOut(nil)
        }
    }

    private func changePage(by offset: Int) {
        currentPage += offset
        relayoutPreviews()
    }

    private func performAction(id: UUID, edit: Bool) {
        guard let preview = previews.first(where: { $0.id == id }) else { return }
        removePreview(id: id)
        if edit { preview.onEdit() } else { preview.onPin() }
    }

    private func removePreview(id: UUID) {
        guard let index = previews.firstIndex(where: { $0.id == id }) else { return }
        let preview = previews.remove(at: index)
        hiddenForCapture.removeValue(forKey: ObjectIdentifier(preview.panel))
        preview.panel.close()
        relayoutPreviews()
    }

    private func makeOverlayPanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}

struct PinnedScreenshotView: View {
    let image: NSImage
    let onClose: () -> Void
    @ObservedObject private var prefs = AppPreferences.shared
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(opacity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onDrag { ScreenshotDragExport.itemProvider(for: image) }
            HStack(spacing: 6) {
                Slider(value: $opacity, in: 0.25...1.0)
                    .frame(width: 70)
                    .controlSize(.mini)
                    .accessibilityLabel(prefs.language == .ru ? "Непрозрачность" : "Opacity")
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .help(prefs.tr(.closeBtn))
                .accessibilityLabel(prefs.tr(.closeBtn))
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
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onDrag { ScreenshotDragExport.itemProvider(for: image) }
                .accessibilityLabel(prefs.language == .ru ? "Снимок экрана — перетащите для экспорта" : "Screenshot — drag to export")
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Label(prefs.language == .ru ? "Изменить" : "Edit", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button(action: onPin) {
                    Image(systemName: "pin.fill").font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(prefs.tr(.pinToScreen))
                .accessibilityLabel(prefs.tr(.pinToScreen))
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.caption)
                }
                .buttonStyle(.plain)
                .help(prefs.tr(.closeBtn))
                .accessibilityLabel(prefs.tr(.closeBtn))
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1))
    }
}

private struct PreviewNavigationView: View {
    let page: Int
    let pageCount: Int
    let count: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    @ObservedObject private var prefs = AppPreferences.shared

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPrevious) { Image(systemName: "chevron.left") }
                .disabled(page == 0)
                .accessibilityLabel(prefs.language == .ru ? "Предыдущие снимки" : "Previous screenshots")
            Spacer(minLength: 0)
            Text(prefs.language == .ru ? "\(page + 1)/\(pageCount) · Снимков: \(count)" : "\(page + 1)/\(pageCount) · \(count) screenshots")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Button(action: onNext) { Image(systemName: "chevron.right") }
                .disabled(page == pageCount - 1)
                .accessibilityLabel(prefs.language == .ru ? "Следующие снимки" : "Next screenshots")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
