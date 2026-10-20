import SwiftUI

@main
struct ScreenshotiApp: App {
    @NSApplicationDelegateAdaptor(ScreenshotiAppDelegate.self) private var appDelegate
    @StateObject private var editorViewModel = ApplicationRuntime.shared.editor
    @ObservedObject private var prefs = AppPreferences.shared
    
    var body: some Scene {
        Window("Screenshoti", id: "studio") {
            MainStudioWindow(viewModel: editorViewModel)
                .frame(minWidth: 1020, minHeight: 680)

        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        
        // Иконка быстрого доступа в строке меню macOS (Menu Bar)
        MenuBarExtra("Screenshoti", systemImage: "camera.viewfinder") {
            Button(prefs.language == .ru ? "Открыть редактор" : "Open Editor") {
                editorViewModel.openStudio?()
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            Divider()
            Button(prefs.tr(.captureArea)) {
                editorViewModel.triggerAreaCapture()
            }
            
            Button(prefs.tr(.captureWindow)) {
                editorViewModel.triggerWindowCapture()
            }
            
            Button(prefs.tr(.captureFullscreen)) {
                editorViewModel.triggerFullscreenCapture()
            }
            
            Divider()
            
            Button(prefs.tr(.smartRedact)) {
                editorViewModel.performSmartRedaction()
            }
            
            Button(prefs.tr(.extractOCR)) {
                editorViewModel.extractTextOCR()
            }
            
            Divider()
            
            Button(prefs.language == .ru ? "Доступ к захвату экрана…" : "Screen Capture Access…") {
                CapturePermissionController.shared.showSetup()
            }
            Divider()
            Button(prefs.tr(.quitApp)) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}

@MainActor
final class ScreenshotiAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { ApplicationRuntime.shared.start() }
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        CapturePermissionController.shared.refresh()
        GlobalHotkeyManager.shared.retryFailedRegistrations()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
