import SwiftUI

enum AnnotationTool: String, CaseIterable, Identifiable {
    case select
    case arrow
    case rectangle
    case text
    case stepCounter
    case redactBlur
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        case .stepCounter: return "1.circle.fill"
        case .redactBlur: return "eye.slash.fill"
        }
    }
}

struct AnnotationItem: Identifiable, Equatable {
    static let systemFontName = "__system__"
    static let defaultFontSize: CGFloat = 15
    static let fontSizeRange: ClosedRange<CGFloat> = 8...144

    let id: UUID
    var tool: AnnotationTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: Color
    var strokeWidth: CGFloat
    var text: String
    var stepNumber: Int
    var fontName: String
    var fontSize: CGFloat
    
    init(
        id: UUID = UUID(),
        tool: AnnotationTool,
        startPoint: CGPoint,
        endPoint: CGPoint,
        color: Color = .red,
        strokeWidth: CGFloat = 3.5,
        text: String = "Note",
        stepNumber: Int = 1,
        fontName: String = AnnotationItem.systemFontName,
        fontSize: CGFloat = AnnotationItem.defaultFontSize
    ) {
        self.id = id
        self.tool = tool
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
        self.strokeWidth = strokeWidth
        self.text = text
        self.stepNumber = stepNumber
        self.fontName = fontName
        self.fontSize = fontSize
    }
    
    var boundingRect: CGRect {
        CGRect(
            x: min(startPoint.x, endPoint.x),
            y: min(startPoint.y, endPoint.y),
            width: abs(endPoint.x - startPoint.x),
            height: abs(endPoint.y - startPoint.y)
        )
    }
}

enum AspectRatioPreset: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case square = "1:1"
    case standard = "4:3"
    case widescreen = "16:9"
    case story = "9:16"
    
    var id: String { rawValue }
    
    var ratio: CGFloat? {
        switch self {
        case .auto: return nil
        case .square: return 1.0
        case .standard: return 4.0 / 3.0
        case .widescreen: return 16.0 / 9.0
        case .story: return 9.0 / 16.0
        }
    }
}

struct GradientPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    
    static let presets: [GradientPreset] = [
        GradientPreset(id: "sunset", name: "Sunset Mesh", colors: [Color(red: 0.98, green: 0.38, blue: 0.42), Color(red: 0.99, green: 0.72, blue: 0.35), Color(red: 0.58, green: 0.25, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing),
        GradientPreset(id: "ocean", name: "Nordic Ocean", colors: [Color(red: 0.08, green: 0.55, blue: 0.92), Color(red: 0.18, green: 0.85, blue: 0.78), Color(red: 0.09, green: 0.18, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing),
        GradientPreset(id: "aurora", name: "Neon Aurora", colors: [Color(red: 0.12, green: 0.91, blue: 0.58), Color(red: 0.25, green: 0.42, blue: 0.96), Color(red: 0.55, green: 0.15, blue: 0.82)], startPoint: .top, endPoint: .bottomTrailing),
        GradientPreset(id: "graphite", name: "Pro Graphite", colors: [Color(red: 0.18, green: 0.19, blue: 0.22), Color(red: 0.09, green: 0.10, blue: 0.12)], startPoint: .top, endPoint: .bottom),
        GradientPreset(id: "sakura", name: "Sakura Soft", colors: [Color(red: 1.0, green: 0.75, blue: 0.82), Color(red: 0.78, green: 0.72, blue: 0.98)], startPoint: .topLeading, endPoint: .bottomTrailing),
        GradientPreset(id: "clean", name: "Clean Silver", colors: [Color(red: 0.93, green: 0.95, blue: 0.97), Color(red: 0.82, green: 0.86, blue: 0.91)], startPoint: .top, endPoint: .bottom)
    ]
}

struct CaptureHistoryItem: Identifiable {
    let id = UUID()
    let timestamp: Date
    let image: NSImage
    let recognizedText: String
}

struct CanvasGeometry {
    let canvasSize: CGSize
    static let headerHeight: CGFloat = 32

    init(imageSize: CGSize, padding: CGFloat, inset: CGFloat, showsHeader: Bool, ratio: CGFloat?) {
        let width = imageSize.width + 2 * (padding + inset)
        let height = imageSize.height + 2 * (padding + inset) + (showsHeader ? Self.headerHeight : 0)
        if let ratio, ratio > 0 {
            canvasSize = CGSize(width: max(width, height * ratio), height: max(height, width / ratio))
        } else {
            canvasSize = CGSize(width: width, height: height)
        }
    }
}

extension AnnotationItem {
    /// One resolved font drives both canvas rendering and selection geometry.
    var nsFont: NSFont {
        let size = fontSize.isFinite ? min(Self.fontSizeRange.upperBound, max(Self.fontSizeRange.lowerBound, fontSize)) : Self.defaultFontSize
        if fontName != Self.systemFontName {
            if let font = NSFont(name: fontName, size: size) { return font }
            if let font = NSFontManager.shared.font(withFamily: fontName, traits: [], weight: 5, size: size) { return font }
        }
        return NSFont.systemFont(ofSize: size, weight: .bold)
    }

    var textSize: CGSize {
        (text as NSString).size(withAttributes: [.font: nsFont])
    }

    var selectionRect: CGRect {
        switch tool {
        case .text:
            let size = textSize
            return CGRect(x: endPoint.x, y: endPoint.y - size.height / 2, width: max(size.width, 20), height: size.height).insetBy(dx: -5, dy: -5)
        case .stepCounter:
            return CGRect(x: endPoint.x - 17, y: endPoint.y - 17, width: 34, height: 34)
        default:
            return boundingRect.insetBy(dx: -6, dy: -6)
        }
    }

    func hitTest(_ point: CGPoint) -> Bool {
        guard tool == .arrow else { return selectionRect.contains(point) }
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let length = dx * dx + dy * dy
        guard length > 0 else { return hypot(point.x - startPoint.x, point.y - startPoint.y) <= 10 }
        let t = min(1, max(0, ((point.x - startPoint.x) * dx + (point.y - startPoint.y) * dy) / length))
        return hypot(point.x - startPoint.x - t * dx, point.y - startPoint.y - t * dy) <= max(10, strokeWidth)
    }
}
