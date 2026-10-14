import SwiftUI

struct MainStudioWindow: View {
    @ObservedObject var viewModel: EditorViewModel
    @ObservedObject var prefs = AppPreferences.shared
    @State private var showSettingsSheet = false
    
    var body: some View {
        NavigationSplitView {
            // Левая панель: Захват + История скриншотов
            VStack(alignment: .leading, spacing: 14) {
                Text(prefs.tr(.appTitle))
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                
                VStack(spacing: 8) {
                    Button(action: viewModel.triggerAreaCapture) {
                        Label(prefs.tr(.captureArea), systemImage: "viewfinder")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut("2", modifiers: [.command, .shift])
                    
                    Button(action: viewModel.triggerWindowCapture) {
                        Label(prefs.tr(.captureWindow), systemImage: "macwindow")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .keyboardShortcut("3", modifiers: [.command, .shift])
                    
                    Button(action: viewModel.triggerFullscreenCapture) {
                        Label(prefs.tr(.captureFullscreen), systemImage: "rectangle.dashed")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 12)
                
                Divider()
                
                Text(prefs.tr(.historySection))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.history) { item in
                            Button {
                                viewModel.sourceImage = item.image
                            } label: {
                                Image(nsImage: item.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 76)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                
                Spacer()
                
                Divider()
                
                // Быстрое переключение Темы (Light/Dark) и Языка (RU/EN) прямо внизу боковой панели
                VStack(alignment: .leading, spacing: 8) {
                    Picker(prefs.tr(.languageLabel), selection: $prefs.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Picker(prefs.tr(.themeLabel), selection: $prefs.theme) {
                        Text(prefs.tr(.themeSystem)).tag(AppTheme.system)
                        Text(prefs.tr(.themeLight)).tag(AppTheme.light)
                        Text(prefs.tr(.themeDark)).tag(AppTheme.dark)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(12)
            }
            .frame(minWidth: 215, idealWidth: 230, maxWidth: 250)
            .background(.regularMaterial)
        } detail: {
            HStack(spacing: 0) {
                // Центральная рабочая область
                ZStack(alignment: .top) {
                    Color(nsColor: .underPageBackgroundColor)
                        .ignoresSafeArea()
                    
                    InteractiveBeautifiedCanvasView(viewModel: viewModel)
                    
                    if viewModel.showCopiedBanner {
                        Label(prefs.tr(.copiedBadge), systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                Divider()
                
                // Правая панель инспектора (Beautifier Studio)
                InspectorSidebarView(viewModel: viewModel)
                    .frame(width: 290)
                    .background(.regularMaterial)
            }
        }
        .toolbar {
            // Панель векторных инструментов аннотирования
            ToolbarItemGroup(placement: .principal) {
                ForEach(AnnotationTool.allCases) { tool in
                    Button {
                        viewModel.activeTool = tool
                    } label: {
                        Image(systemName: tool.iconName)
                    }
                    .help(toolTitle(tool))
                }
                
                ColorPicker("", selection: $viewModel.activeColor)
                    .labelsHidden()
                
                Button(action: viewModel.undoLastAnnotation) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(viewModel.undoStack.isEmpty)
            }
            
            // Умные действия (Smart Redact, OCR, Pin, Copy, Save)
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: viewModel.performSmartRedaction) {
                    Label(prefs.tr(.smartRedact), systemImage: "wand.and.stars")
                }
                
                Button(action: viewModel.extractTextOCR) {
                    Label(prefs.tr(.extractOCR), systemImage: "text.viewfinder")
                }
                
                Button {
                    if let rendered = viewModel.renderFinalImage() {
                        FloatingWindowsManager.shared.pinImageToScreen(rendered)
                    }
                } label: {
                    Label(prefs.tr(.pinToScreen), systemImage: "pin")
                }
                
                Button(action: viewModel.copyRenderedCanvasToClipboard) {
                    Label(prefs.tr(.copyImage), systemImage: "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: [.command])
                
                Button(action: viewModel.saveRenderedCanvasToDisk) {
                    Label(prefs.tr(.saveImage), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: [.command])
            }
        }
        .sheet(item: Binding(
            get: { viewModel.ocrModalText.map { OCRTextWrapper(text: $0) } },
            set: { viewModel.ocrModalText = $0?.text }
        )) { wrapper in
            OCRResultModalView(text: wrapper.text) {
                viewModel.ocrModalText = nil
            }
        }
        .preferredColorScheme(prefs.theme.colorScheme)
    }
    
    private func toolTitle(_ tool: AnnotationTool) -> String {
        switch tool {
        case .select: return prefs.tr(.toolSelect)
        case .arrow: return prefs.tr(.toolArrow)
        case .rectangle: return prefs.tr(.toolRect)
        case .text: return prefs.tr(.toolText)
        case .stepCounter: return prefs.tr(.toolStep)
        case .redactBlur: return prefs.tr(.toolBlur)
        }
    }
}

struct OCRTextWrapper: Identifiable {
    let id = UUID()
    let text: String
}

struct InspectorSidebarView: View {
    @ObservedObject var viewModel: EditorViewModel
    @ObservedObject var prefs = AppPreferences.shared
    
    private let columns = [GridItem(.adaptive(minimum: 54), spacing: 10)]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Секция Фонов и Градиентов
                VStack(alignment: .leading, spacing: 10) {
                    Text(prefs.tr(.backgroundSection))
                        .font(.subheadline.weight(.semibold))
                    
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(GradientPreset.presets) { preset in
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    viewModel.selectedGradient = preset
                                }
                            } label: {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: preset.colors,
                                            startPoint: preset.startPoint,
                                            endPoint: preset.endPoint
                                        )
                                    )
                                    .frame(height: 38)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                viewModel.selectedGradient.id == preset.id ? Color.accentColor : Color.white.opacity(0.2),
                                                lineWidth: viewModel.selectedGradient.id == preset.id ? 2.5 : 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Button(action: viewModel.autoBalanceBackgroundColors) {
                        Label(prefs.tr(.autoBalanceColors), systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Divider()
                
                // 2. Секция Отступов, Скругления и Теней
                VStack(alignment: .leading, spacing: 12) {
                    Text(prefs.tr(.geometrySection))
                        .font(.subheadline.weight(.semibold))
                    
                    LabeledSlider(title: prefs.tr(.outerPadding), value: $viewModel.outerPadding, range: 0...140)
                    LabeledSlider(title: prefs.tr(.innerInset), value: $viewModel.innerInset, range: 0...48)
                    LabeledSlider(title: prefs.tr(.cornerRadius), value: $viewModel.cornerRadius, range: 0...36)
                    LabeledSlider(title: prefs.tr(.shadowRadius), value: $viewModel.shadowRadius, range: 0...60)
                    
                    Toggle(prefs.tr(.windowHeaderToggle), isOn: $viewModel.showMacOSHeader)
                        .toggleStyle(.switch)
                        .font(.caption)
                }
                
                Divider()
                
                // 3. Соотношение сторон
                VStack(alignment: .leading, spacing: 8) {
                    Text(prefs.tr(.aspectRatioSection))
                        .font(.subheadline.weight(.semibold))
                    
                    Picker("", selection: $viewModel.aspectRatio) {
                        ForEach(AspectRatioPreset.allCases) { ratio in
                            Text(ratio.rawValue).tag(ratio)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                Divider()
                
                // 4. Управление слоями
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(prefs.tr(.annotationsSection))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(viewModel.annotations.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(role: .destructive, action: viewModel.clearAnnotations) {
                        Label(prefs.tr(.clearAnnotations), systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.annotations.isEmpty)
                }
            }
            .padding(16)
        }
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value)) px")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
                .controlSize(.small)
        }
    }
}

struct OCRResultModalView: View {
    let text: String
    let onClose: () -> Void
    @ObservedObject var prefs = AppPreferences.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(prefs.tr(.ocrResultTitle))
                .font(.headline)
            
            TextEditor(text: .constant(text))
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 420, minHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    onClose()
                } label: {
                    Label(prefs.tr(.copyTextBtn), systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button(prefs.tr(.closeBtn), action: onClose)
            }
        }
        .padding(20)
    }
}
