import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case ru = "ru"
    case en = "en"
    
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class AppPreferences: ObservableObject {
    @AppStorage("app_language") var language: AppLanguage = .ru {
        didSet { objectWillChange.send() }
    }
    @AppStorage("app_theme") var theme: AppTheme = .system {
        didSet { objectWillChange.send() }
    }
    @AppStorage("auto_copy_clipboard") var autoCopyToClipboard: Bool = true
    @AppStorage("show_quick_overlay") var showQuickOverlay: Bool = true
    
    @AppStorage("preview_corner") var previewCorner: PreviewCorner = .bottomLeft {
        didSet { objectWillChange.send() }
    }
    @Published var captureHotkeys = CaptureHotkeyConfiguration.load(from: .standard) {
        didSet { captureHotkeys.save(to: .standard) }
    }
    static let shared = AppPreferences()
    
    func tr(_ key: LKey) -> String {
        return key.localized(for: language)
    }
}

enum LKey {
    case newText
    case noSensitiveData
    case exportTooLarge
    case exportFailed
    case errorTitle
    case undo
    case redo
    case selectedLayer
    case textContent
    case lineWidth
    case colorLabel
    case deleteLayer
    case emptyHistory
    case canvasHint
    case localProcessing
    case redactionNote
    case capturePermission
    case captureUnavailable
    case noWindow
    case appearance
    case settings
    case done
    case captureBusy
    case layersHint
    case appTitle
    case captureArea
    case captureFullscreen
    case captureWindow
    case sampleCanvas
    case toolSelect
    case toolArrow
    case toolRect
    case toolText
    case toolStep
    case toolBlur
    case smartRedact
    case extractOCR
    case pinToScreen
    case copyImage
    case saveImage
    case copiedBadge
    case backgroundSection
    case autoBalanceColors
    case geometrySection
    case outerPadding
    case innerInset
    case cornerRadius
    case shadowRadius
    case windowHeaderToggle
    case aspectRatioSection
    case annotationsSection
    case clearAnnotations
    case historySection
    case settingsTitle
    case themeLabel
    case themeSystem
    case themeLight
    case themeDark
    case languageLabel
    case autoCopyLabel
    case quickOverlayLabel
    case ocrResultTitle
    case noTextFound
    case copyTextBtn
    case closeBtn
    case quitApp
    case openStudio
    
    func localized(for lang: AppLanguage) -> String {
        switch self {
        case .newText: return lang == .ru ? "Текст" : "Text"
        case .noSensitiveData: return lang == .ru ? "Чувствительные данные не найдены. Проверьте снимок вручную." : "No sensitive data found. Check the image manually."
        case .exportTooLarge: return lang == .ru ? "Изображение слишком большое. Уменьшите отступы или измените пропорции." : "Image is too large. Reduce padding or change the aspect ratio."
        case .exportFailed: return lang == .ru ? "Не удалось экспортировать изображение." : "Could not export the image."
        case .errorTitle: return lang == .ru ? "Не получилось" : "Something went wrong"
        case .undo: return lang == .ru ? "Отменить" : "Undo"
        case .redo: return lang == .ru ? "Повторить" : "Redo"
        case .selectedLayer: return lang == .ru ? "Выбранный слой" : "Selected layer"
        case .textContent: return lang == .ru ? "Текст аннотации" : "Annotation text"
        case .lineWidth: return lang == .ru ? "Толщина" : "Thickness"
        case .colorLabel: return lang == .ru ? "Цвет" : "Color"
        case .deleteLayer: return lang == .ru ? "Удалить слой" : "Delete layer"
        case .emptyHistory: return lang == .ru ? "Здесь появятся ваши снимки" : "Your captures appear here"
        case .canvasHint: return lang == .ru ? "Выберите инструмент или перетащите аннотацию" : "Choose a tool or drag an annotation"
        case .localProcessing: return lang == .ru ? "Обработка на вашем Mac" : "Processed on your Mac"
        case .redactionNote: return lang == .ru ? "Автопоиск может пропустить данные — проверьте снимок перед отправкой." : "Automatic detection can miss data. Review before sharing."
        case .capturePermission: return lang == .ru ? "Разрешите запись экрана для Screenshoti в Системных настройках → Конфиденциальность и безопасность." : "Allow screen recording for Screenshoti in System Settings → Privacy & Security."
        case .captureUnavailable: return lang == .ru ? "Не удалось найти экран или окно для захвата." : "No screen or window is available to capture."
        case .noWindow: return lang == .ru ? "Окно не найдено. Переключитесь на нужное приложение и повторите захват." : "No window found. Switch to the target application and try again."
        case .appearance: return lang == .ru ? "Оформление" : "Appearance"
        case .settings: return lang == .ru ? "Настройки" : "Settings"
        case .done: return lang == .ru ? "Готово" : "Done"
        case .captureBusy: return lang == .ru ? "Захват…" : "Capturing…"
        case .layersHint: return lang == .ru ? "Кликните по аннотации, чтобы изменить её" : "Click an annotation to edit it"
        case .appTitle: return lang == .ru ? "Screenshoti Студия" : "Screenshoti Studio"
        case .captureArea: return lang == .ru ? "Захват области" : "Capture Area"
        case .captureFullscreen: return lang == .ru ? "Весь экран" : "Fullscreen"
        case .captureWindow: return lang == .ru ? "Захват окна" : "Capture Window"
        case .sampleCanvas: return lang == .ru ? "Демо-скриншот" : "Demo Screenshot"
        case .toolSelect: return lang == .ru ? "Курсор" : "Select"
        case .toolArrow: return lang == .ru ? "Стрелка" : "Arrow"
        case .toolRect: return lang == .ru ? "Рамка" : "Rectangle"
        case .toolText: return lang == .ru ? "Текст" : "Text"
        case .toolStep: return lang == .ru ? "Шаги (1,2,3)" : "Steps (1,2,3)"
        case .toolBlur: return lang == .ru ? "Скрыть данные" : "Redact"
        case .smartRedact: return lang == .ru ? "Автоскрытие" : "Auto Redact"
        case .extractOCR: return lang == .ru ? "Текст (OCR)" : "Extract Text (OCR)"
        case .pinToScreen: return lang == .ru ? "Закрепить" : "Pin to Screen"
        case .copyImage: return lang == .ru ? "Копировать" : "Copy"
        case .saveImage: return lang == .ru ? "Сохранить" : "Save"
        case .copiedBadge: return lang == .ru ? "Скопировано в буфер!" : "Copied to Clipboard!"
        case .backgroundSection: return lang == .ru ? "Фон и Градиенты" : "Background & Gradients"
        case .autoBalanceColors: return lang == .ru ? "Автоподбор под скриншот" : "Smart Color Match"
        case .geometrySection: return lang == .ru ? "Отступы и Рамка" : "Geometry & Frame"
        case .outerPadding: return lang == .ru ? "Внешний отступ" : "Outer Padding"
        case .innerInset: return lang == .ru ? "Внутренняя рамка" : "Inner Inset"
        case .cornerRadius: return lang == .ru ? "Скругление углов" : "Corner Radius"
        case .shadowRadius: return lang == .ru ? "Мягкость тени" : "Drop Shadow"
        case .windowHeaderToggle: return lang == .ru ? "Шапка окна macOS" : "macOS Window Header"
        case .aspectRatioSection: return lang == .ru ? "Соотношение сторон" : "Aspect Ratio"
        case .annotationsSection: return lang == .ru ? "Слои и Аннотации" : "Layers & Annotations"
        case .clearAnnotations: return lang == .ru ? "Очистить слои" : "Clear Layers"
        case .historySection: return lang == .ru ? "Недавние снимки" : "Recent Captures"
        case .settingsTitle: return lang == .ru ? "Настройки" : "Settings"
        case .themeLabel: return lang == .ru ? "Оформление" : "Appearance"
        case .themeSystem: return lang == .ru ? "Системное" : "System"
        case .themeLight: return lang == .ru ? "Светлое" : "Light"
        case .themeDark: return lang == .ru ? "Темное" : "Dark"
        case .languageLabel: return lang == .ru ? "Язык интерфейса" : "Language"
        case .autoCopyLabel: return lang == .ru ? "Автокопирование в буфер" : "Auto-copy to Clipboard"
        case .quickOverlayLabel: return lang == .ru ? "Плавающее превью в углу" : "Show Quick Overlay"
        case .ocrResultTitle: return lang == .ru ? "Распознанный текст (OCR)" : "Recognized Text (OCR)"
        case .noTextFound: return lang == .ru ? "Текст на изображении не обнаружен." : "No text detected on the image."
        case .copyTextBtn: return lang == .ru ? "Скопировать текст" : "Copy Text"
        case .closeBtn: return lang == .ru ? "Закрыть" : "Close"
        case .quitApp: return lang == .ru ? "Выйти из Screenshoti" : "Quit Screenshoti"
        case .openStudio: return lang == .ru ? "Открыть студию..." : "Open Studio..."
        }
    }
}

enum StudioPalette {
    static let accent = Color(red: 0.43, green: 0.37, blue: 0.86)
}
