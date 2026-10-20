import AppKit

/// Application services must also run when the Studio window is closed.
@MainActor
final class ApplicationRuntime {
    static let shared = ApplicationRuntime()
    let editor = EditorViewModel()
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        GlobalHotkeyManager.shared.start { [weak editor] action in
            switch action {
            case .area: editor?.triggerAreaCapture()
            case .window: editor?.triggerWindowCapture()
            case .fullscreen: editor?.triggerFullscreenCapture()
            }
        }
        CapturePermissionController.shared.beginStartup()
        // A just-restarted predecessor may still hold its Carbon registrations.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            GlobalHotkeyManager.shared.retryFailedRegistrations()
        }
    }
}
