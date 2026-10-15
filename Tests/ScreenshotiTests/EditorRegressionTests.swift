import AppKit
import SwiftUI
import Testing
@testable import Screenshoti

@Suite(.serialized) @MainActor
struct EditorRegressionTests {
    private func editor() -> EditorViewModel { EditorViewModel() }
    private func item(_ tool: AnnotationTool = .rectangle) -> AnnotationItem {
        AnnotationItem(tool: tool, startPoint: CGPoint(x: 20, y: 20), endPoint: CGPoint(x: 60, y: 60))
    }
    @Test func newCaptureCannotUndoIntoPreviousImage() {
        let model = editor()
        model.addAnnotation(item())
        let prefs = AppPreferences.shared
        let copy = prefs.autoCopyToClipboard, overlay = prefs.showQuickOverlay
        defer { prefs.autoCopyToClipboard = copy; prefs.showQuickOverlay = overlay }
        prefs.autoCopyToClipboard = false; prefs.showQuickOverlay = false
        model.applyCapturedImage(NSImage(size: CGSize(width: 300, height: 200)))
        #expect(model.undoStack.isEmpty)
        model.undoLastAnnotation()
        #expect(model.annotations.isEmpty)
    }
    @Test func undoRestoresStepNumber() {
        let model = editor(); model.addAnnotation(item(.stepCounter)); model.undoLastAnnotation()
        #expect(model.stepCounterValue == 1)
    }
    @Test func clearingAndUndoingRestoresStepSequence() {
        let model = editor(); model.addAnnotation(item(.stepCounter)); model.clearAnnotations(); model.undoLastAnnotation()
        #expect(model.stepCounterValue == 2)
    }
    @Test func squarePresetChangesExportDimensions() throws {
        let model = editor(); model.aspectRatio = .square
        let image = try #require(model.renderFinalImage())
        #expect(abs(image.size.width - image.size.height) < 1)
    }
    @Test func redoRestoresDeletedLayer() {
        let model = editor(); let annotation = item(.text)
        model.addAnnotation(annotation); model.deleteSelectedAnnotation()
        #expect(model.annotations.isEmpty)
        model.undoLastAnnotation(); #expect(model.annotations == [annotation])
        model.redoLastAnnotation(); #expect(model.annotations.isEmpty)
    }
    @Test func newEditInvalidatesRedoBranch() {
        let model = editor(); model.addAnnotation(item(.arrow)); model.undoLastAnnotation()
        var annotation = item(.text); annotation.text = "New branch"; model.addAnnotation(annotation)
        model.redoLastAnnotation()
        #expect(model.annotations == [annotation])
    }
    @Test func movingLayerIsOneUndoableChange() {
        let model = editor(); let annotation = item()
        model.addAnnotation(annotation); model.moveAnnotation(id: annotation.id, translation: CGSize(width: 30, height: -10))
        #expect(model.annotations[0].startPoint == CGPoint(x: 50, y: 10))
        #expect(model.annotations[0].endPoint == CGPoint(x: 90, y: 50))
        model.undoLastAnnotation(); #expect(model.annotations == [annotation])
        model.redoLastAnnotation(); #expect(model.annotations[0].startPoint == CGPoint(x: 50, y: 10))
    }
    @Test func selectionChoosesTopmostLayer() {
        let model = editor(); let bottom = item(); let top = item()
        model.addAnnotation(bottom); model.addAnnotation(top); model.selectAnnotation(at: CGPoint(x: 40, y: 40))
        #expect(model.selectedAnnotationID == top.id)
        model.selectAnnotation(at: CGPoint(x: 300, y: 300)); #expect(model.selectedAnnotationID == nil)
    }
    @Test func arrowHitTestRejectsEmptyBoundingBoxSpace() {
        let arrow = AnnotationItem(tool: .arrow, startPoint: .zero, endPoint: CGPoint(x: 100, y: 100))
        #expect(arrow.hitTest(CGPoint(x: 50, y: 52)))
        #expect(!arrow.hitTest(CGPoint(x: 5, y: 95)))
    }
    @Test func historySwitchResetsOtherImageAnnotations() {
        let model = editor(); model.addAnnotation(item(.text))
        let capture = CaptureHistoryItem(timestamp: Date(), image: NSImage(size: CGSize(width: 200, height: 100)), recognizedText: "")
        model.restoreCapture(capture)
        #expect(model.sourceImage === capture.image)
        #expect(model.annotations.isEmpty && model.undoStack.isEmpty && model.redoStack.isEmpty)
        #expect(model.selectedAnnotationID == nil && model.selectedHistoryID == capture.id)
    }
    @Test func selectingCurrentCapturePreservesEdits() {
        let model = editor()
        let capture = CaptureHistoryItem(timestamp: Date(), image: NSImage(size: CGSize(width: 200, height: 100)), recognizedText: "")
        model.restoreCapture(capture); let annotation = item(.text); model.addAnnotation(annotation); model.restoreCapture(capture)
        #expect(model.annotations == [annotation]); #expect(!model.undoStack.isEmpty)
    }
    @Test func widescreenLayoutPreservesMinimumPadding() {
        let geometry = CanvasGeometry(imageSize: CGSize(width: 100, height: 200), padding: 20, inset: 5, showsHeader: true, ratio: 16.0 / 9.0)
        #expect(abs(geometry.canvasSize.width - 501.3333333333) < 0.001)
        #expect(geometry.canvasSize.height == 282)
    }
    private func whiteImage(scale: Int) throws -> NSImage {
        let context = try #require(CGContext(data: nil, width: 100 * scale, height: 80 * scale, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 100 * scale, height: 80 * scale))
        return NSImage(cgImage: try #require(context.makeImage()), size: CGSize(width: 100, height: 80))
    }
    private func plainEditor(scale: Int = 1) throws -> EditorViewModel {
        let model = editor(); model.sourceImage = try whiteImage(scale: scale)
        model.outerPadding = 0; model.innerInset = 0; model.cornerRadius = 0; model.shadowRadius = 0; model.showMacOSHeader = false
        return model
    }
    @Test(arguments: [1, 2]) func exportPreservesOriginalPixelScale(scale: Int) throws {
        let model = try plainEditor(scale: scale); let image = try #require(model.renderFinalImage())
        let cg = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(cg.width == 100 * scale && cg.height == 80 * scale)
    }
    @Test func redactedPixelsAreFullyOpaqueAndContainNoSourceColor() throws {
        let model = try plainEditor(); model.addAnnotation(item(.redactBlur))
        let image = try #require(model.renderFinalImage())
        let cg = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let bitmap = NSBitmapImageRep(cgImage: cg)
        try saveDiagnostic(bitmap, name: "redaction.png")
        let masked = try #require(bitmap.colorAt(x: 40, y: 40)?.usingColorSpace(.deviceRGB))
        let clear = try #require(bitmap.colorAt(x: 5, y: 5)?.usingColorSpace(.deviceRGB))
        #expect(masked.redComponent < 0.01 && masked.greenComponent < 0.01 && masked.blueComponent < 0.01)
        #expect(masked.alphaComponent > 0.99 && clear.redComponent > 0.99)
    }
    @Test func standaloneAnnotationLayerExports() throws {
        let renderer = ImageRenderer(content: AnnotationVectorLayerView(annotations: [item(.redactBlur)]).frame(width: 100, height: 80).background(.white))
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        try saveDiagnostic(bitmap, name: "layer.png")
        let color = try #require(bitmap.colorAt(x: 40, y: 40)?.usingColorSpace(.deviceRGB))
        #expect(color.redComponent < 0.01)
    }
    @Test func editingTextKeepsLayerIdentityAndUndo() {
        let model = editor(); var annotation = item(.text); annotation.text = "Before"; model.addAnnotation(annotation)
        annotation.text = "After"; model.updateAnnotation(annotation)
        #expect(model.annotations.first?.text == "After" && model.selectedAnnotationID == annotation.id)
        model.undoLastAnnotation(); #expect(model.annotations.first?.text == "Before")
    }
    @Test(arguments: ["alex@example.com", "+7 (999) 123-45-67", "4111 1111 1111 1111", "192.168.1.5", "sk-test1234567890123", "Bearer abc.def_123"])
    func detectsSensitiveData(text: String) { #expect(VisionOCRAndRedactService.containsSensitiveInfo(text)) }
    @Test func ordinaryTextIsNotRedacted() { #expect(!VisionOCRAndRedactService.containsSensitiveInfo("Screenshoti — beautiful screenshots")) }
    private func saveDiagnostic(_ bitmap: NSBitmapImageRep, name: String) throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOTI_TEST_ARTIFACTS"], let data = bitmap.representation(using: .png, properties: [:]) else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
    }
}
