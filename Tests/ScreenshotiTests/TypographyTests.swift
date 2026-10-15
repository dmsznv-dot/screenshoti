import AppKit
import SwiftUI
import Testing
@testable import Screenshoti

@Suite(.serialized) @MainActor
struct TypographyTests {
    private func textItem(size: CGFloat = 15, font: String = "__system__") -> AnnotationItem {
        AnnotationItem(tool: .text, startPoint: CGPoint(x: 12, y: 50), endPoint: CGPoint(x: 12, y: 50),
                       color: .red, text: "Wide text", fontName: font, fontSize: size)
    }

    @Test func largerFontExpandsSelectionAndHitBounds() {
        let small = textItem(size: 12)
        let large = textItem(size: 36)
        #expect(large.selectionRect.width > small.selectionRect.width * 2)
        #expect(large.selectionRect.height > small.selectionRect.height)
        let point = CGPoint(x: small.selectionRect.maxX + 8, y: 50)
        #expect(!small.hitTest(point))
        #expect(large.hitTest(point))
    }

    @Test func missingFontFallsBackToBoldSystemAtChosenSize() {
        let item = textItem(size: 27, font: "Screenshoti.DoesNotExist")
        let expected = NSFont.systemFont(ofSize: 27, weight: .bold)
        #expect(item.nsFont.fontName == expected.fontName)
        #expect(item.nsFont.pointSize == 27)
        #expect(item.textSize.width > 0 && item.textSize.height > 0)
    }

    @Test func installedFontFamilyIsResolvedAtChosenSize() throws {
        let family = try #require(NSFont(name: "Menlo", size: 29)?.familyName)
        let item = textItem(size: 29, font: family)
        #expect(item.nsFont.familyName == family)
        #expect(item.nsFont.pointSize == 29)
    }

    @Test func textStyleUpdatePreservesIdentityAndUndoRedo() {
        let model = EditorViewModel()
        let original = textItem()
        model.addAnnotation(original)
        var edited = original
        edited.fontName = "Menlo"
        edited.fontSize = 34
        model.updateAnnotation(edited)
        #expect(model.selectedAnnotationID == original.id)
        #expect(model.annotations.first == edited)
        model.undoLastAnnotation()
        #expect(model.annotations.first == original)
        model.redoLastAnnotation()
        #expect(model.annotations.first?.fontName == "Menlo")
        #expect(model.annotations.first?.fontSize == 34)
    }

    @Test func largerTextProducesLargerExportedGlyphs() throws {
        let small = try exportedRedBounds(size: 12)
        let large = try exportedRedBounds(size: 36)
        #expect(large.width > small.width * 2)
        #expect(large.height > small.height * 2)
    }

    private func exportedRedBounds(size: CGFloat) throws -> CGRect {
        let model = EditorViewModel()
        let source = NSImage(size: CGSize(width: 260, height: 120))
        source.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: source.size)).fill()
        source.unlockFocus()
        model.sourceImage = source
        model.outerPadding = 0
        model.innerInset = 0
        model.cornerRadius = 0
        model.shadowRadius = 0
        model.showMacOSHeader = false
        model.addAnnotation(textItem(size: size))
        let image = try #require(model.renderFinalImage())
        let bitmap = NSBitmapImageRep(cgImage: try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil)))
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
