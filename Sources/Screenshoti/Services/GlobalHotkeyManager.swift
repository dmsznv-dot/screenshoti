import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class GlobalHotkeyManager: ObservableObject {
    static let shared = GlobalHotkeyManager()
    @Published private(set) var errors: [CaptureAction: String] = [:]
    private let signature: OSType = 0x53534854 // SSHT
    private var registered: [CaptureAction: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var subscription: AnyCancellable?
    private var onCapture: ((CaptureAction) -> Void)?
    private var configuration = CaptureHotkeyConfiguration()
    private var recording = false

    func start(preferences: AppPreferences = .shared, onCapture: @escaping (CaptureAction) -> Void) {
        self.onCapture = onCapture
        guard handler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard result == noErr else { return result }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            // Carbon dispatches application hotkey events on the main run loop.
            MainActor.assumeIsolated { manager.fire(id) }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else {
            let message = AppPreferences.shared.language == .ru ? "Не удалось включить горячие клавиши (\(status))." : "Could not enable shortcuts (\(status))."
            errors = Dictionary(uniqueKeysWithValues: CaptureAction.allCases.map { ($0, message) }); return
        }
        configuration = preferences.captureHotkeys
        install()
        subscription = preferences.$captureHotkeys.dropFirst().sink { [weak self] value in
            DispatchQueue.main.async { self?.configuration = value; self?.install() }
        }
    }
    private func fire(_ id: EventHotKeyID) {
        guard id.signature == signature, !recording,
              let action = CaptureAction.allCases.first(where: { $0.eventID == id.id }) else { return }
        onCapture?(action)
    }
    func setRecording(_ recording: Bool) { self.recording = recording; install() }
    func retryFailedRegistrations() {
        guard !errors.isEmpty, !recording else { return }
        install()
    }
    private func install() {
        registered.values.forEach { UnregisterEventHotKey($0) }
        registered.removeAll()
        errors.removeAll()
        guard !recording, handler != nil else { return }
        for action in CaptureAction.allCases {
            guard let hotkey = configuration[action] else { continue }
            let ru = AppPreferences.shared.language == .ru
            guard hotkey.isValid, configuration.duplicate(of: hotkey, excluding: action) == nil else {
                errors[action] = ru ? "Некорректное или повторяющееся сочетание." : "Invalid or duplicate shortcut."; continue
            }
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(hotkey.keyCode, hotkey.modifiers,
                EventHotKeyID(signature: signature, id: action.eventID), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
            if status == noErr, let reference { registered[action] = reference }
            else { errors[action] = ru ? "Сочетание занято системой или другим приложением (\(status))." : "Shortcut is used by the system or another app (\(status))." }
        }
    }
}
