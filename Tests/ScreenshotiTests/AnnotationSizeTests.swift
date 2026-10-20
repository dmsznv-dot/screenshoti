import AppKit
import SwiftUI
import Testing
@testable import Screenshoti

@Suite(.serialized) @MainActor
struct AnnotationSizeTests {
    private func marker(diameter: CGFloat) -> AnnotationItem {
        AnnotationItem(tool: .stepCounter, startPoint: CGPoint(x: 90, y: 90),
                       endPoint: CGPoint(x: 90, y: 90), color: .red, stepNumber: 12,
                       stepDiameter: diameter)
    }

    @Test func markerSizeExpandsItsSelectionAndHitArea() {
        let small = marker(diameter: 28), large = marker(diameter: 72)
        #expect(large.selectionRect.width == 78)
        #expect(large.selectionRect.midX == 90 && large.selectionRect.midY == 90)
        let edge = CGPoint(x: 122, y: 90)
        #expect(!small.hitTest(edge))
        #expect(large.hitTest(edge))
    }

    @Test func markerDiameterStaysFiniteAndWithinSupportedBounds() {
        #expect(marker(diameter: .nan).resolvedStepDiameter == 28)
        #expect(marker(diameter: 0).resolvedStepDiameter == 16)
        #expect(marker(diameter: 9999).resolvedStepDiameter == 128)
    }

    @Test func markerResizeGestureIsOneUndoStep() {
        let model = EditorViewModel()
        let original = marker(diameter: 28)
        model.addAnnotation(original)
        model.beginAnnotationStyleEdit()
        for size: CGFloat in [40, 52, 72] {
            var edited = model.selectedAnnotation!
            edited.stepDiameter = size
            model.updateAnnotation(edited)
        }
        model.endAnnotationStyleEdit()
        #expect(model.annotations.first?.stepDiameter == 72)
        #expect(model.annotations.first?.stepNumber == 12)
        #expect(model.annotations.first?.endPoint == original.endPoint)
        model.undoLastAnnotation()
        #expect(model.annotations == [original])
        model.redoLastAnnotation()
        #expect(model.annotations.first?.stepDiameter == 72)
        model.undoLastAnnotation()
        model.undoLastAnnotation()
        #expect(model.annotations.isEmpty)
    }

    @Test func largerMarkerProducesLargerCircleInExport() throws {
        let small = try exportedMarkerBounds(diameter: 28)
        let large = try exportedMarkerBounds(diameter: 72)
        #expect(small.width >= 27 && small.width <= 29)
        #expect(large.width >= 71 && large.width <= 73)
        #expect(large.height > small.height * 2)
    }

    private func exportedMarkerBounds(diameter: CGFloat) throws -> CGRect {
        let renderer = ImageRenderer(content: AnnotationVectorLayerView(annotations: [marker(diameter: diameter)])
            .frame(width: 180, height: 180).background(.white))
        let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
        var bounds = CGRect.null
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                   color.redComponent > 0.7, color.greenComponent < 0.4, color.blueComponent < 0.4 {
                    bounds = bounds.union(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        #expect(!bounds.isNull)
        return bounds
    }
}
