import SwiftUI

/// Экранный интерактивный холст с поддержкой рисования векторных слоев мышью
struct InteractiveBeautifiedCanvasView: View {
    @ObservedObject var viewModel: EditorViewModel
    @State private var dragStart: CGPoint? = nil
    @State private var dragCurrent: CGPoint? = nil
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                BeautifiedCanvasRenderView(
                    image: viewModel.sourceImage,
                    gradient: viewModel.selectedGradient,
                    outerPadding: viewModel.outerPadding,
                    innerInset: viewModel.innerInset,
                    cornerRadius: viewModel.cornerRadius,
                    shadowRadius: viewModel.shadowRadius,
                    showMacOSHeader: viewModel.showMacOSHeader,
                    annotations: allAnnotationsWithPreview,
                    onOverlayCoordinateDrag: { start, current, isEnded in
                        handleCanvasGesture(start: start, current: current, isEnded: isEnded)
                    }
                )
                .scaleEffect(calculateFitScale(in: geo.size))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var allAnnotationsWithPreview: [AnnotationItem] {
        var list = viewModel.annotations
        if let start = dragStart, let current = dragCurrent, viewModel.activeTool != .select {
            list.append(AnnotationItem(
                tool: viewModel.activeTool,
                startPoint: start,
                endPoint: current,
                color: viewModel.activeColor,
                text: "Важно / Note",
                stepNumber: viewModel.stepCounterValue
            ))
        }
        return list
    }
    
    private func handleCanvasGesture(start: CGPoint, current: CGPoint, isEnded: Bool) {
        guard viewModel.activeTool != .select else { return }
        if !isEnded {
            dragStart = start
            dragCurrent = current
        } else {
            let item = AnnotationItem(
                tool: viewModel.activeTool,
                startPoint: start,
                endPoint: current,
                color: viewModel.activeColor,
                text: "Важно / Note",
                stepNumber: viewModel.stepCounterValue
            )
            viewModel.addAnnotation(item)
            dragStart = nil
            dragCurrent = nil
        }
    }
    
    private func calculateFitScale(in containerSize: CGSize) -> CGFloat {
        let totalW = viewModel.sourceImage.size.width + viewModel.outerPadding * 2 + viewModel.innerInset * 2
        let totalH = viewModel.sourceImage.size.height + viewModel.outerPadding * 2 + viewModel.innerInset * 2 + (viewModel.showMacOSHeader ? 34 : 0)
        guard totalW > 0, totalH > 0 else { return 1.0 }
        let scaleX = (containerSize.width - 48) / totalW
        let scaleY = (containerSize.height - 48) / totalH
        return min(min(scaleX, scaleY), 1.05)
    }
}

/// Чистое представление холста, используемое как для отображения, так и для `ImageRenderer` при экспорте в PNG
struct BeautifiedCanvasRenderView: View {
    let image: NSImage
    let gradient: GradientPreset
    let outerPadding: CGFloat
    let innerInset: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let showMacOSHeader: Bool
    let annotations: [AnnotationItem]
    var onOverlayCoordinateDrag: ((CGPoint, CGPoint, Bool) -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Градиентная подложка
            LinearGradient(
                colors: gradient.colors,
                startPoint: gradient.startPoint,
                endPoint: gradient.endPoint
            )
            
            // Окно скриншота с опциональной шапкой macOS
            VStack(spacing: 0) {
                if showMacOSHeader {
                    HStack(spacing: 8) {
                        Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 12, height: 12)
                        Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 12, height: 12)
                        Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 12, height: 12)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                }
                
                ZStack(alignment: .topLeading) {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: image.size.width, height: image.size.height)
                    
                    // Слой векторных аннотаций
                    AnnotationVectorLayerView(annotations: annotations)
                        .frame(width: image.size.width, height: image.size.height)
                }
                .padding(innerInset)
                .background(Color(nsColor: .underPageBackgroundColor))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            onOverlayCoordinateDrag?(val.startLocation, val.location, false)
                        }
                        .onEnded { val in
                            onOverlayCoordinateDrag?(val.startLocation, val.location, true)
                        }
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(shadowRadius > 0 ? 0.36 : 0), radius: shadowRadius, x: 0, y: shadowRadius * 0.45)
            .padding(outerPadding)
        }
        .fixedSize()
    }
}

struct AnnotationVectorLayerView: View {
    let annotations: [AnnotationItem]
    
    var body: some View {
        Canvas { context, _ in
            for item in annotations {
                switch item.tool {
                case .rectangle:
                    let rect = item.boundingRect
                    let path = Path(roundedRect: rect, cornerRadius: 6)
                    context.stroke(path, with: .color(item.color), lineWidth: item.strokeWidth)
                    
                case .redactBlur:
                    let rect = item.boundingRect.insetBy(dx: -2, dy: -2)
                    let path = Path(roundedRect: rect, cornerRadius: 4)
                    context.fill(path, with: .color(Color.black.opacity(0.88)))
                    
                case .arrow:
                    var path = Path()
                    path.move(to: item.startPoint)
                    path.addLine(to: item.endPoint)
                    
                    let angle = atan2(item.endPoint.y - item.startPoint.y, item.endPoint.x - item.startPoint.x)
                    let arrowLength: CGFloat = 14
                    let arrowAngle: CGFloat = .pi / 6
                    
                    let p1 = CGPoint(
                        x: item.endPoint.x - arrowLength * cos(angle - arrowAngle),
                        y: item.endPoint.y - arrowLength * sin(angle - arrowAngle)
                    )
                    let p2 = CGPoint(
                        x: item.endPoint.x - arrowLength * cos(angle + arrowAngle),
                        y: item.endPoint.y - arrowLength * sin(angle + arrowAngle)
                    )
                    path.move(to: item.endPoint)
                    path.addLine(to: p1)
                    path.move(to: item.endPoint)
                    path.addLine(to: p2)
                    
                    context.stroke(
                        path,
                        with: .color(item.color),
                        style: StrokeStyle(lineWidth: item.strokeWidth, lineCap: .round, lineJoin: .round)
                    )
                    
                case .stepCounter:
                    let radius: CGFloat = 14
                    let center = item.endPoint
                    let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: circleRect), with: .color(item.color))
                    let text = Text("\(item.stepNumber)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    context.draw(text, at: center)
                    
                case .text:
                    let label = Text(item.text)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(item.color)
                    context.draw(label, at: item.endPoint, anchor: .leading)
                    
                case .select:
                    break
                }
            }
        }
    }
}
