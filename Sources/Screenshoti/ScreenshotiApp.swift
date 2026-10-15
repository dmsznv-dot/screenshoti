import SwiftUI

@main
struct ScreenshotiApp: App {
    @NSApplicationDelegateAdaptor(ScreenshotiAppDelegate.self) private var appDelegate
    @StateObject private var editorViewModel = EditorViewModel()
    @ObservedObject private var prefs = AppPreferences.shared
    
    var body: some Scene {
        Window("Screenshoti", id: "studio") {
            MainStudioWindow(viewModel: editorViewModel)
                .frame(minWidth: 1020, minHeight: 680)
                .onAppear {
                    GlobalHotkeyManager.shared.start { [weak model = editorViewModel] action in
                        switch action {
                        case .area: model?.triggerAreaCapture()
                        case .window: model?.triggerWindowCapture()
                        case .fullscreen: model?.triggerFullscreenCapture()
                        }
                    }
                }
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
            
            Button(prefs.tr(.quitApp)) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}

final class ScreenshotiAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
