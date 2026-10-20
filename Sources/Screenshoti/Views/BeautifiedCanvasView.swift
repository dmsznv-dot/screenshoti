import SwiftUI
import AppKit

struct InteractiveBeautifiedCanvasView: View {
    @ObservedObject var viewModel: EditorViewModel
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var movingID: UUID?

    var body: some View {
        GeometryReader { geo in
            BeautifiedCanvasRenderView(image: viewModel.sourceImage, gradient: viewModel.selectedGradient,
                outerPadding: viewModel.outerPadding, innerInset: viewModel.innerInset,
                cornerRadius: viewModel.cornerRadius, shadowRadius: viewModel.shadowRadius,
                showMacOSHeader: viewModel.showMacOSHeader, annotations: previewAnnotations,
                aspectRatio: viewModel.aspectRatio, selectedID: viewModel.selectedAnnotationID,
                onOverlayCoordinateDrag: handleGesture)
                .scaleEffect(fitScale(in: geo.size))
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .onChange(of: viewModel.selectedHistoryID) { _, _ in resetDrag() }
    }
    private var previewAnnotations: [AnnotationItem] {
        var items = viewModel.annotations
        guard let start = dragStart, let current = dragCurrent else { return items }
        if viewModel.activeTool == .select {
            if let id = movingID, let index = items.firstIndex(where: { $0.id == id }) {
                let dx = current.x - start.x, dy = current.y - start.y
                items[index].startPoint.x += dx
                items[index].startPoint.y += dy
                items[index].endPoint.x += dx
                items[index].endPoint.y += dy
            }
        } else { items.append(newItem(start: start, end: current)) }
        return items
    }
    private func newItem(start: CGPoint, end: CGPoint) -> AnnotationItem {
        AnnotationItem(tool: viewModel.activeTool, startPoint: start, endPoint: end,
                       color: viewModel.activeColor, strokeWidth: viewModel.activeStrokeWidth,
                       text: AppPreferences.shared.tr(.newText), stepNumber: viewModel.stepCounterValue,
                       fontName: viewModel.activeFontName, fontSize: viewModel.activeFontSize,
                       stepDiameter: viewModel.activeStepDiameter)
    }
    private func handleGesture(start: CGPoint, current: CGPoint, isEnded: Bool) {
        let end = CGPoint(x: min(max(current.x, 0), viewModel.sourceImage.size.width),
                          y: min(max(current.y, 0), viewModel.sourceImage.size.height))
        if dragStart == nil {
            if viewModel.activeTool == .select {
                viewModel.selectAnnotation(at: start)
                movingID = viewModel.selectedAnnotationID
            }
            dragStart = start
        }
        dragCurrent = end
        guard isEnded else { return }
        if viewModel.activeTool == .select {
            if let id = movingID {
                viewModel.moveAnnotation(id: id, translation: CGSize(width: end.x - start.x, height: end.y - start.y))
            }
        } else if viewModel.activeTool == .text || viewModel.activeTool == .stepCounter || hypot(end.x - start.x, end.y - start.y) > 3 {
            let item = newItem(start: start, end: end)
            viewModel.addAnnotation(item)
            if item.tool == .text { viewModel.activeTool = .select }
        }
        resetDrag()
    }
    private func resetDrag() { dragStart = nil; dragCurrent = nil; movingID = nil }
    private func fitScale(in size: CGSize) -> CGFloat {
        let canvas = viewModel.canvasSize
        return max(0.01, min(1, min((size.width - 64) / canvas.width, (size.height - 64) / canvas.height)))
    }
}

/// Preview and export share the same layout; only the preview has input handling and selection decoration.
struct BeautifiedCanvasRenderView: View {
    let image: NSImage
    let gradient: GradientPreset
    let outerPadding: CGFloat
    let innerInset: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let showMacOSHeader: Bool
    let annotations: [AnnotationItem]
    var aspectRatio: AspectRatioPreset = .auto
    var selectedID: UUID?
    var onOverlayCoordinateDrag: ((CGPoint, CGPoint, Bool) -> Void)?

    private var geometry: CanvasGeometry {
        CanvasGeometry(imageSize: image.size, padding: outerPadding, inset: innerInset,
                       showsHeader: showMacOSHeader, ratio: aspectRatio.ratio)
    }
    var body: some View {
        ZStack {
            LinearGradient(colors: gradient.colors, startPoint: gradient.startPoint, endPoint: gradient.endPoint)
            VStack(spacing: 0) {
                if showMacOSHeader { windowHeader }
                imageWithOptionalGesture
                    .padding(innerInset)
                    .background(Color(nsColor: .underPageBackgroundColor))
            }
            .frame(width: image.size.width + innerInset * 2)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(shadowRadius > 0 ? 0.28 : 0), radius: shadowRadius, x: 0, y: shadowRadius * 0.4)
        }
        .frame(width: geometry.canvasSize.width, height: geometry.canvasSize.height)
        .clipped()
    }
    private var windowHeader: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 10, height: 10)
            Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 10, height: 10)
            Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 10, height: 10)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: CanvasGeometry.headerHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    @ViewBuilder private var imageWithOptionalGesture: some View {
        if let onOverlayCoordinateDrag {
            imageContent.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0)
                .onChanged { onOverlayCoordinateDrag($0.startLocation, $0.location, false) }
                .onEnded { onOverlayCoordinateDrag($0.startLocation, $0.location, true) })
        } else { imageContent }
    }
    private var imageContent: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: image).resizable().frame(width: image.size.width, height: image.size.height)
            AnnotationVectorLayerView(annotations: annotations).frame(width: image.size.width, height: image.size.height)
            if let selected = annotations.first(where: { $0.id == selectedID }) {
                Path { $0.addRect(selected.selectionRect) }
                    .stroke(StudioPalette.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: image.size.width, height: image.size.height)
    }
}

struct AnnotationVectorLayerView: View {
    let annotations: [AnnotationItem]
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(annotations) { item in
                switch item.tool {
                case .rectangle:
                    Path(roundedRect: item.boundingRect, cornerRadius: 6).stroke(item.color, lineWidth: item.strokeWidth)
                case .redactBlur:
                    // A nonzero RGB black avoids ImageRenderer dropping pure-black fills on macOS 15.
                    Path(item.boundingRect.insetBy(dx: -2, dy: -2))
                        .fill(Color(.sRGB, red: 1.0 / 255, green: 1.0 / 255, blue: 1.0 / 255, opacity: 1))
                case .arrow:
                    arrowPath(item).stroke(item.color, style: StrokeStyle(lineWidth: item.strokeWidth, lineCap: .round, lineJoin: .round))
                case .stepCounter:
                    ZStack {
                        Circle().fill(item.color)
                        Text("\(item.stepNumber)")
                            .font(.system(size: item.resolvedStepDiameter * 13 / 28, weight: .bold))
                            .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.35)
                            .padding(.horizontal, item.resolvedStepDiameter * 0.1)
                    }.frame(width: item.resolvedStepDiameter, height: item.resolvedStepDiameter).position(item.endPoint)
                case .text:
                    let size = item.textSize
                    Text(item.text).font(Font(item.nsFont)).foregroundStyle(item.color).fixedSize()
                        .position(x: item.endPoint.x + size.width / 2, y: item.endPoint.y)
                case .select:
                    EmptyView()
                }
            }
        }.allowsHitTesting(false)
    }
    private func arrowPath(_ item: AnnotationItem) -> Path {
        let angle = atan2(item.endPoint.y - item.startPoint.y, item.endPoint.x - item.startPoint.x)
        let length: CGFloat = max(14, item.strokeWidth * 3)
        let spread: CGFloat = .pi / 6
        return Path { path in
            path.move(to: item.startPoint)
            path.addLine(to: item.endPoint)
            path.addLine(to: CGPoint(x: item.endPoint.x - length * cos(angle - spread), y: item.endPoint.y - length * sin(angle - spread)))
            path.move(to: item.endPoint)
            path.addLine(to: CGPoint(x: item.endPoint.x - length * cos(angle + spread), y: item.endPoint.y - length * sin(angle + spread)))
        }
    }
}
