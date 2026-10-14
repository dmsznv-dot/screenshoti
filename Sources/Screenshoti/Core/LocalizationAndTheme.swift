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
    
    static let shared = AppPreferences()
    
    func tr(_ key: LKey) -> String {
        return key.localized(for: language)
    }
}

enum LKey {
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
        switch (self, lang) {
        case (.appTitle, .ru): return "Screenshoti Студия"
        case (.appTitle, .en): return "Screenshoti Studio"
        case (.captureArea, .ru): return "Захват области"
        case (.captureArea, .en): return "Capture Area"
        case (.captureFullscreen, .ru): return "Весь экран"
        case (.captureFullscreen, .en): return "Fullscreen"
        case (.captureWindow, .ru): return "Захват окна"
        case (.captureWindow, .en): return "Capture Window"
        case (.sampleCanvas, .ru): return "Демо-скриншот"
        case (.sampleCanvas, .en): return "Demo Screenshot"
        case (.toolSelect, .ru): return "Курсор"
        case (.toolSelect, .en): return "Select"
        case (.toolArrow, .ru): return "Стрелка"
        case (.toolArrow, .en): return "Arrow"
        case (.toolRect, .ru): return "Рамка"
        case (.toolRect, .en): return "Rectangle"
        case (.toolText, .ru): return "Текст"
        case (.toolText, .en): return "Text"
        case (.toolStep, .ru): return "Шаги (1,2,3)"
        case (.toolStep, .en): return "Steps (1,2,3)"
        case (.toolBlur, .ru): return "Блюр"
        case (.toolBlur, .en): return "Redact/Blur"
        case (.smartRedact, .ru): return "Умное скрытие (AI)"
        case (.smartRedact, .en): return "Smart Redact (AI)"
        case (.extractOCR, .ru): return "Текст (OCR)"
        case (.extractOCR, .en): return "Extract Text (OCR)"
        case (.pinToScreen, .ru): return "Закрепить"
        case (.pinToScreen, .en): return "Pin to Screen"
        case (.copyImage, .ru): return "Копировать"
        case (.copyImage, .en): return "Copy"
        case (.saveImage, .ru): return "Сохранить"
        case (.saveImage, .en): return "Save"
        case (.copiedBadge, .ru): return "Скопировано в буфер!"
        case (.copiedBadge, .en): return "Copied to Clipboard!"
        case (.backgroundSection, .ru): return "Фон и Градиенты"
        case (.backgroundSection, .en): return "Background & Gradients"
        case (.autoBalanceColors, .ru): return "Автоподбор под скриншот"
        case (.autoBalanceColors, .en): return "Smart Color Match"
        case (.geometrySection, .ru): return "Отступы и Рамка"
        case (.geometrySection, .en): return "Geometry & Frame"
        case (.outerPadding, .ru): return "Внешний отступ"
        case (.outerPadding, .en): return "Outer Padding"
        case (.innerInset, .ru): return "Внутренняя рамка"
        case (.innerInset, .en): return "Inner Inset"
        case (.cornerRadius, .ru): return "Скругление углов"
        case (.cornerRadius, .en): return "Corner Radius"
        case (.shadowRadius, .ru): return "Мягкость тени"
        case (.shadowRadius, .en): return "Drop Shadow"
        case (.windowHeaderToggle, .ru): return "Шапка окна macOS"
        case (.windowHeaderToggle, .en): return "macOS Window Header"
        case (.aspectRatioSection, .ru): return "Соотношение сторон"
        case (.aspectRatioSection, .en): return "Aspect Ratio"
        case (.annotationsSection, .ru): return "Слои и Аннотации"
        case (.annotationsSection, .en): return "Layers & Annotations"
        case (.clearAnnotations, .ru): return "Очистить слои"
        case (.clearAnnotations, .en): return "Clear Layers"
        case (.historySection, .ru): return "Недавние снимки"
        case (.historySection, .en): return "Recent Captures"
        case (.settingsTitle, .ru): return "Настройки"
        case (.settingsTitle, .en): return "Settings"
        case (.themeLabel, .ru): return "Оформление"
        case (.themeLabel, .en): return "Appearance"
        case (.themeSystem, .ru): return "Системное"
        case (.themeSystem, .en): return "System"
        case (.themeLight, .ru): return "Светлое"
        case (.themeLight, .en): return "Light"
        case (.themeDark, .ru): return "Темное"
        case (.themeDark, .en): return "Dark"
        case (.languageLabel, .ru): return "Язык интерфейса"
        case (.languageLabel, .en): return "Language"
        case (.autoCopyLabel, .ru): return "Автокопирование в буфер"
        case (.autoCopyLabel, .en): return "Auto-copy to Clipboard"
        case (.quickOverlayLabel, .ru): return "Плавающее превью в углу"
        case (.quickOverlayLabel, .en): return "Show Quick Overlay"
        case (.ocrResultTitle, .ru): return "Распознанный текст (OCR)"
        case (.ocrResultTitle, .en): return "Recognized Text (OCR)"
        case (.noTextFound, .ru): return "Текст на изображении не обнаружен."
        case (.noTextFound, .en): return "No text detected on the image."
        case (.copyTextBtn, .ru): return "Скопировать текст"
        case (.copyTextBtn, .en): return "Copy Text"
        case (.closeBtn, .ru): return "Закрыть"
        case (.closeBtn, .en): return "Close"
        case (.quitApp, .ru): return "Выйти из Screenshoti"
        case (.quitApp, .en): return "Quit Screenshoti"
        case (.openStudio, .ru): return "Открыть студию..."
        case (.openStudio, .en): return "Open Studio..."
        }
    }
}
