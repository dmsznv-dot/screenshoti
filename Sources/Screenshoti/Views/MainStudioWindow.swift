import SwiftUI
import AppKit

struct MainStudioWindow: View {
    @ObservedObject var viewModel: EditorViewModel
    @ObservedObject var prefs = AppPreferences.shared
    @State private var showSettings = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 185, ideal: 210, max: 245)
        } detail: {
            HStack(spacing: 0) {
                workspace
                Divider()
                InspectorSidebarView(viewModel: viewModel).frame(width: 270)
                    .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) { Text("Screenshoti").font(.headline) }
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.isProcessingAI { ProgressView().controlSize(.small) }
                Menu {
                    Button(prefs.tr(.extractOCR), systemImage: "text.viewfinder", action: viewModel.extractTextOCR)
                    Button(prefs.tr(.smartRedact), systemImage: "wand.and.stars", action: viewModel.performSmartRedaction)
                    Divider()
                    Button(prefs.tr(.pinToScreen), systemImage: "pin") {
                        if let image = viewModel.renderFinalImage() { FloatingWindowsManager.shared.pinImageToScreen(image) }
                    }
                    Divider()
                    Button(prefs.tr(.settings), systemImage: "gearshape") { showSettings = true }
                } label: { Image(systemName: "ellipsis.circle") }
                .disabled(viewModel.isProcessingAI || viewModel.isCapturing)
                Button(action: viewModel.copyCommand) { Label(prefs.tr(.copyImage), systemImage: "doc.on.doc") }
                    .keyboardShortcut("c", modifiers: .command)
                Button(action: viewModel.saveRenderedCanvasToDisk) { Label(prefs.tr(.saveImage), systemImage: "square.and.arrow.down") }
                    .keyboardShortcut("s", modifiers: .command).buttonStyle(.borderedProminent)
            }
        }
        .onAppear { viewModel.openStudio = { openWindow(id: "studio") } }
        .sheet(isPresented: $showSettings) { settings }
        .sheet(isPresented: Binding(get: { viewModel.ocrModalText != nil }, set: { if !$0 { viewModel.ocrModalText = nil } })) {
            OCRResultModalView(text: viewModel.ocrModalText ?? "") { viewModel.ocrModalText = nil }
        }
        .alert(prefs.tr(.errorTitle), isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .onChange(of: prefs.previewCorner) { _, _ in FloatingWindowsManager.shared.relayoutPreviews() }
        .preferredColorScheme(prefs.theme.colorScheme).tint(StudioPalette.accent)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "camera.viewfinder").font(.title2).foregroundStyle(.tint)
                Text("SCREENSHOTI").font(.system(size: 11, weight: .semibold)).tracking(1.8)
            }.padding(.top, 12)
            VStack(spacing: 8) {
                captureButton(prefs.tr(viewModel.isCapturing ? .captureBusy : .captureArea), icon: "viewfinder", action: viewModel.triggerAreaCapture)
                    .buttonStyle(.borderedProminent)
                captureButton(prefs.tr(.captureWindow), icon: "macwindow", action: viewModel.triggerWindowCapture)
                    .buttonStyle(.bordered)
                captureButton(prefs.tr(.captureFullscreen), icon: "rectangle.dashed", action: viewModel.triggerFullscreenCapture).buttonStyle(.bordered)
            }.disabled(viewModel.isCapturing)
            Divider()
            HStack {
                Text(prefs.tr(.historySection)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.history.count)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
            }
            if viewModel.history.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled").font(.title2)
                    Text(prefs.tr(.emptyHistory)).font(.caption).multilineTextAlignment(.center)
                }.foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.vertical, 32)
            }
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.history) { item in
                        Button { viewModel.restoreCapture(item) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(nsImage: item.image).resizable().scaledToFit().frame(height: 80).frame(maxWidth: .infinity)
                                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                                Text(item.timestamp, format: .dateTime.hour().minute().second()).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }.padding(8)
                                .background(viewModel.selectedHistoryID == item.id ? StudioPalette.accent.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(viewModel.selectedHistoryID == item.id ? StudioPalette.accent.opacity(0.7) : Color.primary.opacity(0.07)))
                        }.buttonStyle(.plain)
                    }
                }
            }
            Spacer(minLength: 0)
            Button { showSettings = true } label: { Label(prefs.tr(.settings), systemImage: "gearshape").font(.caption).foregroundStyle(.secondary) }
                .buttonStyle(.plain).padding(.bottom, 10)
        }.padding(.horizontal, 14).background(.regularMaterial)
    }
    private func captureButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading) }.controlSize(.large)
    }
    private var workspace: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "photo").foregroundStyle(.tertiary)
                Text("\(Int(viewModel.sourceImage.size.width * viewModel.sourcePixelScale)) × \(Int(viewModel.sourceImage.size.height * viewModel.sourcePixelScale))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Label(prefs.tr(.localProcessing), systemImage: "desktopcomputer").font(.caption2).foregroundStyle(.tertiary)
            }.padding(.horizontal, 20).padding(.vertical, 14)
            ZStack(alignment: .top) {
                InteractiveBeautifiedCanvasView(viewModel: viewModel)
                if viewModel.showCopiedBanner {
                    Label(prefs.tr(.copiedBadge), systemImage: "checkmark.circle.fill").font(.callout.weight(.medium))
                        .padding(.horizontal, 16).padding(.vertical, 10).background(.regularMaterial, in: Capsule()).padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            toolDock.padding(.bottom, 12)
            HStack {
                Text(prefs.tr(.canvasHint)).font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("\(Int(ceil(viewModel.canvasSize.width * viewModel.sourcePixelScale))) × \(Int(ceil(viewModel.canvasSize.height * viewModel.sourcePixelScale))) px")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.bottom, 14)
        }.background(Color(nsColor: .underPageBackgroundColor).opacity(0.55))
    }
    private var toolDock: some View {
        HStack(spacing: 3) {
            ForEach(AnnotationTool.allCases) { tool in
                Button { viewModel.activeTool = tool } label: {
                    Image(systemName: tool.iconName).font(.system(size: 15, weight: .medium)).frame(width: 34, height: 34)
                        .foregroundStyle(viewModel.activeTool == tool ? Color.white : Color.primary.opacity(0.7))
                        .background(viewModel.activeTool == tool ? StudioPalette.accent : .clear, in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).help(tool.title(prefs)).accessibilityLabel(tool.title(prefs))
            }
            Divider().frame(height: 22).padding(.horizontal, 5)
            CompactColorPalette(color: $viewModel.activeColor, title: prefs.tr(.colorLabel), onEditingChanged: viewModel.setTextEditing)
            Divider().frame(height: 22).padding(.horizontal, 5)
            Button(action: viewModel.undoCommand) { Image(systemName: "arrow.uturn.backward").frame(width: 30, height: 34) }
                .buttonStyle(.plain).help(prefs.tr(.undo)).disabled(viewModel.undoStack.isEmpty)
                .keyboardShortcut("z", modifiers: .command)
            Button(action: viewModel.redoCommand) { Image(systemName: "arrow.uturn.forward").frame(width: 30, height: 34) }
                .buttonStyle(.plain).help(prefs.tr(.redo)).disabled(viewModel.redoStack.isEmpty)
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }.padding(7).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.07), radius: 12, y: 3)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(prefs.tr(.settings)).font(.title2.weight(.semibold))
            Picker(prefs.tr(.languageLabel), selection: $prefs.language) { ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) } }.pickerStyle(.segmented)
            Picker(prefs.tr(.themeLabel), selection: $prefs.theme) {
                Text(prefs.tr(.themeSystem)).tag(AppTheme.system)
                Text(prefs.tr(.themeLight)).tag(AppTheme.light)
                Text(prefs.tr(.themeDark)).tag(AppTheme.dark)
            }.pickerStyle(.segmented)
            Toggle(prefs.tr(.autoCopyLabel), isOn: $prefs.autoCopyToClipboard)
            Toggle(prefs.tr(.quickOverlayLabel), isOn: $prefs.showQuickOverlay)
            Picker(prefs.language == .ru ? "Расположение снимков" : "Screenshot position", selection: $prefs.previewCorner) {
                ForEach(PreviewCorner.allCases) { corner in Text(corner.title(for: prefs.language)).tag(corner) }
            }
            Divider()
            CaptureShortcutSettings()
            HStack { Spacer(); Button(prefs.tr(.done)) { showSettings = false }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(width: 510)
    }
}

struct InspectorSidebarView: View {
    @ObservedObject var viewModel: EditorViewModel
    @ObservedObject var prefs = AppPreferences.shared
    @FocusState private var textFocused: Bool
    @State private var textInputID = UUID()
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(prefs.tr(.appearance)).font(.title3.weight(.semibold))
                section(prefs.tr(.backgroundSection)) {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(GradientPreset.presets) { preset in
                            Button { viewModel.selectedGradient = preset } label: {
                                RoundedRectangle(cornerRadius: 9).fill(LinearGradient(colors: preset.colors, startPoint: preset.startPoint, endPoint: preset.endPoint)).frame(height: 46)
                                    .overlay(alignment: .bottomTrailing) {
                                        if viewModel.selectedGradient.id == preset.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white).shadow(radius: 2).padding(5) }
                                    }
                                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(viewModel.selectedGradient.id == preset.id ? StudioPalette.accent : Color.primary.opacity(0.08), lineWidth: viewModel.selectedGradient.id == preset.id ? 2 : 1))
                            }.buttonStyle(.plain).help(preset.name).accessibilityLabel(preset.name)
                        }
                    }
                    Button(action: viewModel.autoBalanceBackgroundColors) { Label(prefs.tr(.autoBalanceColors), systemImage: "sparkles").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.small)
                }
                section(prefs.tr(.geometrySection)) {
                    LabeledSlider(title: prefs.tr(.outerPadding), value: $viewModel.outerPadding, range: 0...140)
                    LabeledSlider(title: prefs.tr(.innerInset), value: $viewModel.innerInset, range: 0...48)
                    LabeledSlider(title: prefs.tr(.shadowRadius), value: $viewModel.shadowRadius, range: 0...60)
                    Toggle(prefs.tr(.windowHeaderToggle), isOn: $viewModel.showMacOSHeader).toggleStyle(.switch).font(.caption)
                }
                section(prefs.tr(.aspectRatioSection)) {
                    Picker("", selection: $viewModel.aspectRatio) { ForEach(AspectRatioPreset.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).labelsHidden()
                }
                Divider()
                if viewModel.activeTool == .text {
                    section(prefs.language == .ru ? "Новый текст" : "New text") {
                        FontControls(fontName: $viewModel.activeFontName, fontSize: $viewModel.activeFontSize, onEditingChanged: viewModel.setTextEditing)
                    }
                }
                section(prefs.tr(.annotationsSection)) {
                    if viewModel.annotations.isEmpty {
                        Text(prefs.tr(.layersHint)).font(.caption).foregroundStyle(.secondary)
                        LabeledSlider(title: prefs.tr(.lineWidth), value: $viewModel.activeStrokeWidth, range: 1...12)
                    } else {
                        ForEach(viewModel.annotations.reversed()) { item in
                            Button { viewModel.selectedAnnotationID = item.id; viewModel.activeTool = .select } label: {
                                HStack {
                                    Image(systemName: item.tool.iconName).frame(width: 18)
                                    Text(item.tool == .text ? item.text : item.tool.title(prefs)).lineLimit(1)
                                    Spacer()
                                    if item.id == viewModel.selectedAnnotationID { Image(systemName: "checkmark").foregroundStyle(.tint) }
                                }.font(.caption).padding(9).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(item.id == viewModel.selectedAnnotationID ? StudioPalette.accent.opacity(0.1) : Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 7))
                            }.buttonStyle(.plain)
                        }
                    }
                    if let item = viewModel.selectedAnnotation {
                        Divider().padding(.vertical, 4)
                        Text(prefs.tr(.selectedLayer)).font(.caption.weight(.semibold))
                        if item.tool == .text {
                            TextField(prefs.tr(.textContent), text: Binding(get: { viewModel.selectedAnnotation?.text ?? "" }, set: { value in
                                guard var selected = viewModel.selectedAnnotation else { return }; selected.text = value; viewModel.updateAnnotation(selected)
                            })).textFieldStyle(.roundedBorder).focused($textFocused)
                            FontControls(fontName: Binding(get: { viewModel.selectedAnnotation?.fontName ?? AnnotationItem.systemFontName }, set: { value in
                                guard var selected = viewModel.selectedAnnotation else { return }; selected.fontName = value; viewModel.updateAnnotation(selected)
                            }), fontSize: Binding(get: { viewModel.selectedAnnotation?.fontSize ?? AnnotationItem.defaultFontSize }, set: { value in
                                guard var selected = viewModel.selectedAnnotation else { return }; selected.fontSize = value; viewModel.updateAnnotation(selected)
                            }), onEditingChanged: viewModel.setTextEditing)
                        }
                        if item.tool != .redactBlur {
                            HStack {
                                Text(prefs.tr(.colorLabel)).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                CompactColorPalette(color: Binding(get: { viewModel.selectedAnnotation?.color ?? .red }, set: { value in
                                    guard var selected = viewModel.selectedAnnotation else { return }; selected.color = value; viewModel.updateAnnotation(selected)
                                }), title: prefs.tr(.colorLabel), onEditingChanged: viewModel.setTextEditing)
                            }
                        }
                        if item.tool == .arrow || item.tool == .rectangle {
                            LabeledSlider(title: prefs.tr(.lineWidth), value: Binding(get: { viewModel.selectedAnnotation?.strokeWidth ?? 3.5 }, set: { value in
                                guard var selected = viewModel.selectedAnnotation else { return }; selected.strokeWidth = value; viewModel.updateAnnotation(selected)
                            }), range: 1...12)
                        }
                        Button(role: .destructive, action: viewModel.deleteSelectedAnnotation) { Label(prefs.tr(.deleteLayer), systemImage: "trash").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.small)
                    }
                    if !viewModel.annotations.isEmpty {
                        Button(prefs.tr(.clearAnnotations), role: .destructive, action: viewModel.clearAnnotations).font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
                Text(prefs.tr(.redactionNote)).font(.caption2).foregroundStyle(.tertiary)
            }.padding(18)
        }
        .onChange(of: viewModel.selectedAnnotationID) { _, _ in textFocused = viewModel.selectedAnnotation?.tool == .text }
        .onChange(of: textFocused) { _, focused in viewModel.setTextEditing(textInputID, focused) }
        .onDisappear { viewModel.setTextEditing(textInputID, false) }

    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) { Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary); content() }
    }
}
struct LabeledSlider: View {
    let title: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var body: some View {
        VStack(spacing: 3) {
            HStack { Text(title); Spacer(); Text("\(Int(value)) px").monospacedDigit() }.font(.caption).foregroundStyle(.secondary)
            Slider(value: $value, in: range, step: 1).controlSize(.small)
        }
    }
}
struct OCRResultModalView: View {
    let text: String
    let onClose: () -> Void
    @ObservedObject var prefs = AppPreferences.shared
    @State private var editableText = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(prefs.tr(.ocrResultTitle)).font(.title3.weight(.semibold))
            TextEditor(text: $editableText).font(.system(.body, design: .monospaced)).frame(minWidth: 440, minHeight: 230)
            HStack {
                Label(prefs.tr(.localProcessing), systemImage: "desktopcomputer").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(prefs.tr(.closeBtn), action: onClose)
                Button(prefs.tr(.copyTextBtn)) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(editableText, forType: .string); onClose() }.buttonStyle(.borderedProminent)
            }
        }.padding(24).onAppear { editableText = text }
    }
}
extension AnnotationTool {
    func title(_ prefs: AppPreferences) -> String {
        switch self {
        case .select: return prefs.tr(.toolSelect)
        case .arrow: return prefs.tr(.toolArrow)
        case .rectangle: return prefs.tr(.toolRect)
        case .text: return prefs.tr(.toolText)
        case .stepCounter: return prefs.tr(.toolStep)
        case .redactBlur: return prefs.tr(.toolBlur)
        }
    }
}
