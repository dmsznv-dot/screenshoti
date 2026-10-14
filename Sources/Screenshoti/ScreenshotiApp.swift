import SwiftUI

@main
struct ScreenshotiApp: App {
    @StateObject private var editorViewModel = EditorViewModel()
    @ObservedObject private var prefs = AppPreferences.shared
    
    var body: some Scene {
        WindowGroup("Screenshoti") {
            MainStudioWindow(viewModel: editorViewModel)
                .frame(minWidth: 1020, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        
        // Иконка быстрого доступа в строке меню macOS (Menu Bar)
        MenuBarExtra("Screenshoti", systemImage: "camera.viewfinder") {
            Button(prefs.tr(.captureArea)) {
                editorViewModel.triggerAreaCapture()
            }
            .keyboardShortcut("2", modifiers: [.command, .shift])
            
            Button(prefs.tr(.captureWindow)) {
                editorViewModel.triggerWindowCapture()
            }
            .keyboardShortcut("3", modifiers: [.command, .shift])
            
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
