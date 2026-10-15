import SwiftUI
import AppKit

struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: CaptureHotkey?
    let onRecord: (CaptureHotkey?) -> String?
    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded
        button.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        button.onRecord = onRecord
        button.shortcut = shortcut
        button.refreshTitle()
        return button
    }
    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.onRecord = onRecord
        button.shortcut = shortcut
        if !button.recording { button.refreshTitle() }
    }
    static func dismantleNSView(_ button: ShortcutRecorderButton, coordinator: ()) { button.finish() }
}

final class ShortcutRecorderButton: NSButton {
    var shortcut: CaptureHotkey?
    var onRecord: ((CaptureHotkey?) -> String?)?
    private(set) var recording = false
    private var monitor: Any?
    override var acceptsFirstResponder: Bool { true }
    private var ru: Bool { AppPreferences.shared.language == .ru }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        target = self
        action = #selector(toggleRecording)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        target = self
        action = #selector(toggleRecording)
    }
    @objc private func toggleRecording() {
        if recording { finish(); return }
        window?.makeFirstResponder(self)
        recording = true
        title = ru ? "Нажмите сочетание…" : "Press shortcut…"
        toolTip = ru ? "Esc — отмена, Delete — очистить" : "Esc cancels, Delete clears"
        GlobalHotkeyManager.shared.setRecording(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording else { return event }
            self.record(event)
            return nil
        }
    }
    override func resignFirstResponder() -> Bool { finish(); return true }
    private func record(_ event: NSEvent) {
        if event.keyCode == 53 { finish(); return }
        if event.keyCode == 51 || event.keyCode == 117 { _ = onRecord?(nil); shortcut = nil; finish(); return }
        let candidate = CaptureHotkey(event: event)
        guard candidate.isValid else {
            title = ru ? "Добавьте ⌘, ⌥ или ⌃" : "Add ⌘, ⌥ or ⌃"; return
        }
        if let error = onRecord?(candidate) { title = error; return }
        shortcut = candidate
        finish()
    }
    func finish() {
        guard recording else { return }
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        GlobalHotkeyManager.shared.setRecording(false)
        refreshTitle()
    }
    func refreshTitle() {
        title = shortcut?.displayName ?? (ru ? "Назначить…" : "Set shortcut…")
        toolTip = ru ? "Нажмите, затем введите сочетание. Delete удаляет назначение." : "Click, then press a shortcut. Delete clears it."
        setAccessibilityLabel(ru ? "Назначить горячую клавишу" : "Record keyboard shortcut")
    }
}

struct CaptureShortcutSettings: View {
    @ObservedObject var prefs = AppPreferences.shared
    @ObservedObject var manager = GlobalHotkeyManager.shared
    @State private var inputErrors: [CaptureAction: String] = [:]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prefs.language == .ru ? "Горячие клавиши" : "Keyboard shortcuts").font(.headline)
            ForEach(CaptureAction.allCases) { action in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(prefs.tr(action.titleKey))
                        Spacer()
                        ShortcutRecorder(shortcut: prefs.captureHotkeys[action]) { shortcut in
                            if let shortcut, prefs.captureHotkeys.duplicate(of: shortcut, excluding: action) != nil {
                                let message = prefs.language == .ru ? "Уже назначено другому захвату" : "Used for another capture"
                                inputErrors[action] = message
                                return message
                            }
                            inputErrors[action] = nil
                            var config = prefs.captureHotkeys
                            config[action] = shortcut
                            prefs.captureHotkeys = config
                            return nil
                        }.frame(width: 200, height: 28)
                    }
                    if let error = inputErrors[action] ?? manager.errors[action] {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            Text(prefs.language == .ru ? "Работают из любого приложения, пока Screenshoti запущен. Нажмите на сочетание для записи; Esc отменяет, Delete удаляет." : "Work in any app while Screenshoti is running. Click to record; Esc cancels, Delete clears.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
