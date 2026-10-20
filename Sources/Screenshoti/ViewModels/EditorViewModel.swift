import SwiftUI
import AppKit

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var sourceImage: NSImage
    @Published var selectedGradient = GradientPreset.presets[0]
    @Published var outerPadding: CGFloat = 56
    @Published var innerInset: CGFloat = 0
    @Published var cornerRadius: CGFloat = 14
    @Published var shadowRadius: CGFloat = 28
    @Published var showMacOSHeader = true
    @Published var aspectRatio: AspectRatioPreset = .auto
    @Published var activeTool: AnnotationTool = .select
    @Published var activeColor: Color = Color(red: 1, green: 0.23, blue: 0.19)
    @Published var activeStrokeWidth: CGFloat = 3.5
    @Published var activeFontName = "__system__"
    @Published var activeFontSize: CGFloat = 15
    @Published var annotations: [AnnotationItem] = []
    @Published var undoStack: [[AnnotationItem]] = []
    @Published var redoStack: [[AnnotationItem]] = []
    @Published var stepCounterValue = 1
    @Published var selectedAnnotationID: UUID?
    @Published var selectedHistoryID: UUID?
    @Published var history: [CaptureHistoryItem] = []
    @Published var showCopiedBanner = false
    @Published var ocrModalText: String?
    @Published var errorMessage: String?
    @Published var isProcessingAI = false
    @Published var isCapturing = false
    @Published private var editingTextControls: Set<UUID> = []
    var isEditingText: Bool { !editingTextControls.isEmpty || ocrModalText != nil }
    func setTextEditing(_ id: UUID, _ isEditing: Bool) {
        if isEditing { editingTextControls.insert(id) } else { editingTextControls.remove(id) }
    }
    private var routesCommandsToText: Bool { isEditingText || NSApp?.keyWindow?.firstResponder is NSTextView }
    func copyCommand(fromKeyboard: Bool = true) {
        if fromKeyboard && routesCommandsToText { NSApp?.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
        else { copyRenderedCanvasToClipboard() }
    }
    func undoCommand(fromKeyboard: Bool = true) {
        if fromKeyboard && routesCommandsToText { NSApp?.sendAction(Selector(("undo:")), to: nil, from: nil) }
        else { undoLastAnnotation() }
    }
    func redoCommand(fromKeyboard: Bool = true) {
        if fromKeyboard && routesCommandsToText { NSApp?.sendAction(Selector(("redo:")), to: nil, from: nil) }
        else { redoLastAnnotation() }
    }
    var openStudio: (() -> Void)?
    private var documentID = UUID()
    private var bannerTask: Task<Void, Never>?
    private let maximumUndoSteps = 100

    private let permissionController: CapturePermissionController
    init(permissionController: CapturePermissionController? = nil) {
        self.permissionController = permissionController ?? .shared
        sourceImage = Self.generateDemoScreenshot()
    }

    var canvasSize: CGSize {
        CanvasGeometry(imageSize: sourceImage.size, padding: outerPadding, inset: innerInset,
                       showsHeader: showMacOSHeader, ratio: aspectRatio.ratio).canvasSize
    }
    var selectedAnnotation: AnnotationItem? { annotations.first { $0.id == selectedAnnotationID } }
    var sourcePixelScale: CGFloat {
        guard sourceImage.size.width > 0,
              let cg = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 1 }
        return max(1, CGFloat(cg.width) / sourceImage.size.width)
    }

    func triggerAreaCapture() { capture(.area) }
    func triggerWindowCapture() { capture(.window) }
    func triggerFullscreenCapture() { capture(.fullscreen) }
    private func capture(_ mode: ScreenCaptureService.Mode) {
        guard !isCapturing, permissionController.ensureAccess() else { return }
        isCapturing = true
        FloatingWindowsManager.shared.hideForCapture()
        NSApp.hide(nil)
        Task {
            var needsAccessSetup = false
            defer {
                isCapturing = false
                NSApp.unhide(nil)
                FloatingWindowsManager.shared.restoreAfterCapture()
                if needsAccessSetup { permissionController.showSetup() }
            }
            do {
                try await Task.sleep(nanoseconds: 180_000_000)
                if let image = try await ScreenCaptureService.shared.capture(mode) {
                    applyCapturedImage(image)
                }
            } catch ScreenCaptureService.CaptureError.permission {
                needsAccessSetup = true
            } catch is CancellationError {
                // A cancelled selection leaves the document intact.
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func applyCapturedImage(_ image: NSImage) {
        loadImage(image)
        let item = CaptureHistoryItem(timestamp: Date(), image: image, recognizedText: "")
        history.insert(item, at: 0)
        history = Array(history.prefix(30))
        selectedHistoryID = item.id
        if AppPreferences.shared.autoCopyToClipboard { copyRenderedCanvasToClipboard() }
        if AppPreferences.shared.showQuickOverlay {
            FloatingWindowsManager.shared.showQuickCornerOverlay(image: image,
                onEdit: { [weak self] in
                    self?.restoreCapture(item)
                    self?.openStudio?()
                    NSApp.unhide(nil)
                    NSApp.activate(ignoringOtherApps: true)
                },
                onPin: { FloatingWindowsManager.shared.pinImageToScreen(image) })
        }
    }
    func restoreCapture(_ item: CaptureHistoryItem) {
        guard selectedHistoryID != item.id else { return }
        loadImage(item.image)
        selectedHistoryID = item.id
    }
    private func loadImage(_ image: NSImage) {
        documentID = UUID()
        sourceImage = image
        annotations = []
        undoStack = []
        redoStack = []
        selectedAnnotationID = nil
        stepCounterValue = 1
        ocrModalText = nil
    }
    private func rememberChange() {
        undoStack.append(annotations)
        if undoStack.count > maximumUndoSteps { undoStack.removeFirst() }
        redoStack.removeAll()
    }
    private func reconcileSelectionAndSteps() {
        stepCounterValue = (annotations.filter { $0.tool == .stepCounter }.map(\.stepNumber).max() ?? 0) + 1
        if !annotations.contains(where: { $0.id == selectedAnnotationID }) { selectedAnnotationID = nil }
    }
    func addAnnotation(_ item: AnnotationItem) {
        rememberChange()
        annotations.append(item)
        selectedAnnotationID = item.id
        reconcileSelectionAndSteps()
    }
    func updateAnnotation(_ item: AnnotationItem) {
        guard let index = annotations.firstIndex(where: { $0.id == item.id }), annotations[index] != item else { return }
        rememberChange()
        annotations[index] = item
        reconcileSelectionAndSteps()
    }
    func selectAnnotation(at point: CGPoint) {
        selectedAnnotationID = annotations.reversed().first { $0.hitTest(point) }?.id
    }
    func moveAnnotation(id: UUID, translation: CGSize) {
        guard var item = annotations.first(where: { $0.id == id }) else { return }
        item.startPoint.x += translation.width
        item.startPoint.y += translation.height
        item.endPoint.x += translation.width
        item.endPoint.y += translation.height
        updateAnnotation(item)
    }
    func deleteSelectedAnnotation() {
        guard let id = selectedAnnotationID, annotations.contains(where: { $0.id == id }) else { return }
        rememberChange()
        annotations.removeAll { $0.id == id }
        reconcileSelectionAndSteps()
    }
    func undoLastAnnotation() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previous
        reconcileSelectionAndSteps()
    }
    func redoLastAnnotation() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        reconcileSelectionAndSteps()
    }
    func clearAnnotations() {
        guard !annotations.isEmpty else { return }
        rememberChange()
        annotations.removeAll()
        reconcileSelectionAndSteps()
    }
    func autoBalanceBackgroundColors() {
        guard let cg = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let bitmap = NSBitmapImageRep(cgImage: cg)
        let w = bitmap.pixelsWide, h = bitmap.pixelsHigh
        guard w > 4, h > 4 else { return }
        let first = bitmap.colorAt(x: w / 4, y: h / 4) ?? .systemBlue
        let second = bitmap.colorAt(x: w * 3 / 4, y: h * 3 / 4) ?? .systemPurple
        selectedGradient = GradientPreset(id: "smart", name: "Smart Balance", colors: [Color(nsColor: first), Color(nsColor: second)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func performSmartRedaction() { analyzeText(redact: true) }
    func extractTextOCR() { analyzeText(redact: false) }
    private func analyzeText(redact: Bool) {
        guard !isProcessingAI,
              let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let currentDocument = documentID
        let imageSize = sourceImage.size
        isProcessingAI = true
        Task {
            defer { isProcessingAI = false }
            do {
                let result = try await VisionOCRAndRedactService.shared.analyzeImage(cgImage)
                guard currentDocument == documentID else { return }
                if redact {
                    let regions = result.regions.filter(\.isSensitive)
                    guard !regions.isEmpty else { ocrModalText = AppPreferences.shared.tr(.noSensitiveData); return }
                    let newItems = regions.map { region in
                        let rect = region.normalizedTopLeftRect
                        return AnnotationItem(tool: .redactBlur,
                            startPoint: CGPoint(x: rect.minX * imageSize.width, y: rect.minY * imageSize.height),
                            endPoint: CGPoint(x: rect.maxX * imageSize.width, y: rect.maxY * imageSize.height), color: .black)
                    }.filter { candidate in
                        !annotations.contains { $0.tool == .redactBlur && $0.boundingRect == candidate.boundingRect }
                    }
                    guard !newItems.isEmpty else { return }
                    rememberChange()
                    annotations.append(contentsOf: newItems)
                } else {
                    ocrModalText = result.fullText.isEmpty ? AppPreferences.shared.tr(.noTextFound) : result.fullText
                }
            } catch { if currentDocument == documentID { errorMessage = error.localizedDescription } }
        }
    }

    func renderFinalImage() -> NSImage? {
        let size = canvasSize
        guard size.width > 0, size.height > 0,
              size.width * size.height * sourcePixelScale * sourcePixelScale < 100_000_000 else {
            errorMessage = AppPreferences.shared.tr(.exportTooLarge)
            return nil
        }
        let view = BeautifiedCanvasRenderView(image: sourceImage, gradient: selectedGradient,
            outerPadding: outerPadding, innerInset: innerInset, cornerRadius: cornerRadius,
            shadowRadius: shadowRadius, showMacOSHeader: showMacOSHeader, annotations: annotations,
            aspectRatio: aspectRatio)
            .environment(\.colorScheme, AppPreferences.shared.theme.colorScheme ??
                (NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light))
        let renderer = ImageRenderer(content: view)
        renderer.scale = sourcePixelScale
        guard let cgImage = renderer.cgImage else { errorMessage = AppPreferences.shared.tr(.exportFailed); return nil }
        return NSImage(cgImage: cgImage, size: size)
    }
    func copyRenderedCanvasToClipboard() {
        guard let image = renderFinalImage() else { return }
        let board = NSPasteboard.general
        board.clearContents()
        guard board.writeObjects([image]) else { errorMessage = AppPreferences.shared.tr(.exportFailed); return }
        bannerTask?.cancel()
        withAnimation { showCopiedBanner = true }
        bannerTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 1_800_000_000) } catch { return }
            withAnimation { self?.showCopiedBanner = false }
        }
    }
    func saveRenderedCanvasToDisk() {
        guard let image = renderFinalImage(), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        panel.nameFieldStringValue = "Screenshoti_\(formatter.string(from: Date())).png"
        if panel.runModal() == .OK, let url = panel.url {
            do { try png.write(to: url, options: .atomic) } catch { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Генерация демо-скриншота при старте (с примером кода и чувствительных данных для проверки Smart Redact и OCR)
    static func generateDemoScreenshot() -> NSImage {
        let size = NSSize(width: 680, height: 420)
        let img = NSImage(size: size)
        img.lockFocus()
        
        NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.16, alpha: 1.0).setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        "Screenshoti — macOS Beautifier & AI Redaction".draw(at: NSPoint(x: 36, y: 350), withAttributes: titleAttrs)
        
        let codeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor(calibratedRed: 0.55, green: 0.88, blue: 0.98, alpha: 1.0)
        ]
        
        let sampleLines = [
            "func captureAndBeautify() async throws {",
            "    let image = try await ScreenCaptureService.shared.captureFrontWindow()",
            "    // Smart Redact Demo (Try clicking 'Smart Redact (AI)'):",
            #"    let customerEmail = "alex.dev@example.com""#,
            #"    let apiSecretKey  = "sk-Live9876543210SecretToken""#,
            #"    let supportPhone  = "+1 (555) 234-5678""#,
            "    return BeautifierStudio.render(image, padding: 56, cornerRadius: 14)",
            "}"
        ]
        
        for (idx, line) in sampleLines.enumerated() {
            line.draw(at: NSPoint(x: 36, y: 295 - CGFloat(idx * 30)), withAttributes: codeAttrs)
        }
        
        img.unlockFocus()
        return img
    }
}
