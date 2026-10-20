import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class CapturePermissionController: ObservableObject {
    static let shared = CapturePermissionController()
    @Published private(set) var hasAccess = false
    @Published private(set) var didRequestAccess = false
    @Published private(set) var restartError: String?
    private let preflight: () -> Bool
    private let request: () -> Bool
    private let presentSetup: (() -> Void)?
    private var didBeginStartup = false
    private var setupPanel: NSPanel?

    init(preflight: @escaping () -> Bool = { CGPreflightScreenCaptureAccess() },
         request: @escaping () -> Bool = { CGRequestScreenCaptureAccess() },
         presentSetup: (() -> Void)? = nil) {
        self.preflight = preflight
        self.request = request
        self.presentSetup = presentSetup
    }

    func beginStartup() {
        guard !didBeginStartup else { return }
        didBeginStartup = true
        refresh()
        guard !hasAccess else { return }
        showSetup()
        requestAccess()
    }

    func refresh() {
        hasAccess = preflight()
        if hasAccess { setupPanel?.close() }
    }

    /// Runs before any capture UI or application windows are hidden.
    func ensureAccess() -> Bool {
        refresh()
        guard !hasAccess else { return true }
        showSetup()
        if !didRequestAccess { requestAccess() }
        return hasAccess
    }

    func requestAccess() {
        didRequestAccess = true
        if presentSetup == nil {
            NSApp?.unhide(nil)
            NSApp?.activate(ignoringOtherApps: true)
        }
        _ = request()
        refresh()
    }

    func showSetup() {
        if let presentSetup { presentSetup(); return }
        if setupPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 540, height: 500),
                                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = "Screenshoti"
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: CaptureSetupView(controller: self))
            panel.center()
            setupPanel = panel
        }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        setupPanel?.makeKeyAndOrderFront(nil)
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    func restartApplication() {
        restartError = nil
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error { self.restartError = error.localizedDescription }
                else { NSApp.terminate(nil) }
            }
        }
    }
}

struct CaptureSetupView: View {
    @ObservedObject var controller: CapturePermissionController
    @ObservedObject private var prefs = AppPreferences.shared
    private var ru: Bool { prefs.language == .ru }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "camera.viewfinder").font(.system(size: 38)).foregroundStyle(.tint)
            Text(ru ? "Разрешите захват экрана" : "Allow screen capture").font(.title2.weight(.semibold))
            Text(ru
                 ? "Screenshoti нужен доступ к записи экрана, чтобы делать снимки выбранной области, окна и всего экрана."
                 : "Screenshoti needs Screen Recording access to capture an area, a window, or the whole screen.")
            CaptureAccessSettings(controller: controller)
            Divider()
            Text(ru
                 ? "Если переключатель не включается после обновления: закройте старую копию Screenshoti, установите новую в «Программы», удалите старую запись приложения кнопкой «−» в этом разделе и добавьте установленную копию кнопкой «+»."
                 : "If the switch cannot be enabled after updating: quit the old copy, install the new Screenshoti in Applications, remove its old entry with − in this settings pane, then add the installed copy with +.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(Bundle.main.bundlePath).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
        }.padding(28).frame(width: 540).fixedSize(horizontal: false, vertical: true)
    }
}

struct CaptureAccessSettings: View {
    @ObservedObject var controller = CapturePermissionController.shared
    @ObservedObject private var prefs = AppPreferences.shared
    private var ru: Bool { prefs.language == .ru }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(controller.hasAccess
                  ? (ru ? "Захват экрана разрешён" : "Screen capture is allowed")
                  : (ru ? "Нужен доступ к записи экрана" : "Screen Recording access is required"),
                  systemImage: controller.hasAccess ? "checkmark.circle.fill" : "lock.shield")
                .font(.callout.weight(.medium))
            if !controller.hasAccess {
                HStack {
                    Button(ru ? "Запросить доступ" : "Request Access", action: controller.requestAccess)
                    Button(ru ? "Открыть настройки macOS" : "Open macOS Settings", action: controller.openSystemSettings)
                        .buttonStyle(.borderedProminent)
                }
                Text(ru
                     ? "Включите Screenshoti в «Конфиденциальность и безопасность» → «Запись экрана» (название может включать системное аудио). Затем вернитесь в приложение."
                     : "Enable Screenshoti in Privacy & Security → Screen Recording (the name may include System Audio), then return to the app.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button(ru ? "Проверить доступ" : "Check Access", action: controller.refresh)
                Button(ru ? "Перезапустить приложение" : "Restart App", action: controller.restartApplication)
            }
            Text(ru
                 ? "Если macOS просит перезапуск, сохраните нужные снимки и перезапустите приложение. Горячим клавишам отдельное разрешение не требуется."
                 : "If macOS requests a restart, save any screenshots you need, then restart the app. Shortcuts do not require a separate permission.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let error = controller.restartError { Text(error).font(.caption).foregroundStyle(.red) }
        }.onAppear { controller.refresh() }
    }
}
