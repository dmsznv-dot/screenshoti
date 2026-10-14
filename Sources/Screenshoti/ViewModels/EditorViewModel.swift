import SwiftUI
import AppKit

@MainActor
final class EditorViewModel: ObservableObject {
    // Текущий скриншот
    @Published var sourceImage: NSImage
    
    // Настройки Beautifier Studio
    @Published var selectedGradient: GradientPreset = GradientPreset.presets[0]
    @Published var outerPadding: CGFloat = 56
    @Published var innerInset: CGFloat = 0
    @Published var cornerRadius: CGFloat = 14
    @Published var shadowRadius: CGFloat = 28
    @Published var showMacOSHeader: Bool = true
    @Published var aspectRatio: AspectRatioPreset = .auto
    
    // Инструменты аннотирования и слои
    @Published var activeTool: AnnotationTool = .arrow
    @Published var activeColor: Color = Color(red: 1.0, green: 0.23, blue: 0.19)
    @Published var annotations: [AnnotationItem] = []
    @Published var undoStack: [[AnnotationItem]] = []
    @Published var stepCounterValue: Int = 1
    
    // История и статусы
    @Published var history: [CaptureHistoryItem] = []
    @Published var showCopiedBanner: Bool = false
    @Published var ocrModalText: String? = nil
    @Published var isProcessingAI: Bool = false
    
    init() {
        self.sourceImage = Self.generateDemoScreenshot()
    }
    
    // MARK: - Захват экрана
    func triggerAreaCapture() {
        NSApp.hide(nil)
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            ScreenCaptureService.shared.beginInteractiveAreaCapture { [weak self] captured in
                guard let self = self else { return }
                NSApp.unhide(nil)
                if let img = captured {
                    self.applyCapturedImage(img)
                }
            }
        }
    }
    
    func triggerWindowCapture() {
        Task {
            if let img = await ScreenCaptureService.shared.captureFrontWindow() {
                applyCapturedImage(img)
            }
        }
    }
    
    func triggerFullscreenCapture() {
        Task {
            if let img = await ScreenCaptureService.shared.captureFullscreen() {
                applyCapturedImage(img)
            }
        }
    }
    
    func applyCapturedImage(_ image: NSImage) {
        self.sourceImage = image
        self.annotations.removeAll()
        self.stepCounterValue = 1
        
        let item = CaptureHistoryItem(timestamp: Date(), image: image, recognizedText: "")
        history.insert(item, at: 0)
        
        if AppPreferences.shared.autoCopyToClipboard {
            copyRenderedCanvasToClipboard()
        }
        
        if AppPreferences.shared.showQuickOverlay {
            FloatingWindowsManager.shared.showQuickCornerOverlay(
                image: image,
                onEdit: { NSApp.activate(ignoringOtherApps: true) },
                onPin: { FloatingWindowsManager.shared.pinImageToScreen(image) }
            )
        }
    }
    
    // MARK: - Слои и Undo
    func addAnnotation(_ item: AnnotationItem) {
        undoStack.append(annotations)
        annotations.append(item)
        if item.tool == .stepCounter {
            stepCounterValue += 1
        }
    }
    
    func undoLastAnnotation() {
        guard let previous = undoStack.popLast() else { return }
        annotations = previous
    }
    
    func clearAnnotations() {
        guard !annotations.isEmpty else { return }
        undoStack.append(annotations)
        annotations.removeAll()
        stepCounterValue = 1
    }
    
    // MARK: - Smart Color Balance (Подбор градиента под цвета скриншота)
    func autoBalanceBackgroundColors() {
        guard let tiff = sourceImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return }
        
        let w = bitmap.pixelsWide
        let h = bitmap.pixelsHigh
        guard w > 4, h > 4 else { return }
        
        let c1 = bitmap.colorAt(x: w / 4, y: h / 4) ?? .systemBlue
        let c2 = bitmap.colorAt(x: (w * 3) / 4, y: (h * 3) / 4) ?? .systemPurple
        
        selectedGradient = GradientPreset(
            id: "smart_\(UUID().uuidString)",
            name: "Smart Balance",
            colors: [Color(nsColor: c1), Color(nsColor: c2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - AI Smart Redact & OCR (Vision)
    func performSmartRedaction() {
        isProcessingAI = true
        Task {
            let result = await VisionOCRAndRedactService.shared.analyzeImage(sourceImage)
            isProcessingAI = false
            
            let sensitiveRegions = result.regions.filter { $0.isSensitive }
            guard !sensitiveRegions.isEmpty else { return }
            
            undoStack.append(annotations)
            for region in sensitiveRegions {
                let norm = region.normalizedTopLeftRect
                let start = CGPoint(x: norm.minX * sourceImage.size.width, y: norm.minY * sourceImage.size.height)
                let end = CGPoint(x: norm.maxX * sourceImage.size.width, y: norm.maxY * sourceImage.size.height)
                annotations.append(AnnotationItem(
                    tool: .redactBlur,
                    startPoint: start,
                    endPoint: end,
                    color: .black
                ))
            }
        }
    }
    
    func extractTextOCR() {
        isProcessingAI = true
        Task {
            let result = await VisionOCRAndRedactService.shared.analyzeImage(sourceImage)
            isProcessingAI = false
            ocrModalText = result.fullText.isEmpty ? AppPreferences.shared.tr(.noTextFound) : result.fullText
        }
    }
    
    // MARK: - Экспорт и Буфер обмена (Retina 2x)
    func renderFinalImage() -> NSImage? {
        let renderView = BeautifiedCanvasRenderView(
            image: sourceImage,
            gradient: selectedGradient,
            outerPadding: outerPadding,
            innerInset: innerInset,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            showMacOSHeader: showMacOSHeader,
            annotations: annotations
        )
        
        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 2.0
        return renderer.nsImage
    }
    
    func copyRenderedCanvasToClipboard() {
        guard let finalImg = renderFinalImage() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([finalImg])
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedBanner = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation {
                showCopiedBanner = false
            }
        }
    }
    
    func saveRenderedCanvasToDisk() {
        guard let finalImg = renderFinalImage(),
              let tiff = finalImg.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        panel.nameFieldStringValue = "Screenshoti_\(formatter.string(from: Date())).png"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? pngData.write(to: url)
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
            "    let customerEmail = "alex.dev@example.com"",
            "    let apiSecretKey  = "sk-Live9876543210SecretToken"",
            "    let supportPhone  = "+1 (555) 234-5678"",
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
