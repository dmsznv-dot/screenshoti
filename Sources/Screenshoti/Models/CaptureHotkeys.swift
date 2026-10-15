import AppKit
import Carbon.HIToolbox

// Key codes stay physical when the keyboard layout changes; labels retain the recorded key.
enum CaptureAction: String, CaseIterable, Identifiable, Codable {
    case area, window, fullscreen
    var id: String { rawValue }
    var eventID: UInt32 { switch self { case .area: return 1; case .window: return 2; case .fullscreen: return 3 } }
    var titleKey: LKey { switch self { case .area: return .captureArea; case .window: return .captureWindow; case .fullscreen: return .captureFullscreen } }
}

struct CaptureHotkey: Codable, Equatable, Hashable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String
    static let allowedModifiers = UInt32(cmdKey | controlKey | optionKey | shiftKey)
    var isValid: Bool {
        keyCode <= 127 && !keyLabel.isEmpty && modifiers & ~Self.allowedModifiers == 0 &&
            modifiers & UInt32(cmdKey | controlKey | optionKey) != 0
    }
    var displayName: String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + keyLabel
    }
    func hasSameCombination(as other: Self) -> Bool { keyCode == other.keyCode && modifiers == other.modifiers }
    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.keyLabel = keyLabel
    }
    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var value: UInt32 = 0
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        modifiers = value
        let special: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Space", 123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        keyLabel = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "?"
    }
}

struct CaptureHotkeyConfiguration: Codable, Equatable {
    var area: CaptureHotkey? = CaptureHotkey(keyCode: 19, modifiers: UInt32(controlKey | optionKey | cmdKey), keyLabel: "2")
    var window: CaptureHotkey? = CaptureHotkey(keyCode: 20, modifiers: UInt32(controlKey | optionKey | cmdKey), keyLabel: "3")
    var fullscreen: CaptureHotkey? = CaptureHotkey(keyCode: 21, modifiers: UInt32(controlKey | optionKey | cmdKey), keyLabel: "4")
    subscript(action: CaptureAction) -> CaptureHotkey? {
        get { switch action { case .area: return area; case .window: return window; case .fullscreen: return fullscreen } }
        set { switch action { case .area: area = newValue; case .window: window = newValue; case .fullscreen: fullscreen = newValue } }
    }
    func duplicate(of hotkey: CaptureHotkey, excluding action: CaptureAction) -> CaptureAction? {
        CaptureAction.allCases.first { $0 != action && self[$0]?.hasSameCombination(as: hotkey) == true }
    }
    static func load(from defaults: UserDefaults) -> Self {
        guard let data = defaults.data(forKey: "capture_hotkeys_v1"), let value = try? JSONDecoder().decode(Self.self, from: data) else { return .init() }
        return value
    }
    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "capture_hotkeys_v1") }
    }
}
