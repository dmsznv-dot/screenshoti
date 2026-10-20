import AppKit
import Carbon.HIToolbox
import Testing
@testable import Screenshoti

struct CaptureHotkeyTests {
    @Test func shortcutRequiresCommandControlOrOption() {
        for modifiers in [UInt32(0), UInt32(shiftKey)] {
            #expect(!CaptureHotkey(keyCode: 19, modifiers: modifiers, keyLabel: "2").isValid)
        }
        #expect(CaptureHotkeyConfiguration().area?.isValid == true)
        #expect(!CaptureHotkey(keyCode: 200, modifiers: UInt32(cmdKey), keyLabel: "?").isValid)
    }
    @Test func duplicateUsesPhysicalKeyAndModifiers() throws {
        let configuration = CaptureHotkeyConfiguration()
        let area = try #require(configuration.area)
        let translated = CaptureHotkey(keyCode: area.keyCode, modifiers: area.modifiers, keyLabel: "Д")
        #expect(configuration.duplicate(of: translated, excluding: .window) == .area)
        #expect(configuration.duplicate(of: translated, excluding: .area) == nil)
    }
    @Test func disabledAndCustomShortcutsSurviveRelaunch() throws {
        let suite = "ScreenshotiTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var configuration = CaptureHotkeyConfiguration()
        configuration.area = nil
        configuration.window = CaptureHotkey(keyCode: 0, modifiers: UInt32(controlKey | shiftKey), keyLabel: "A")
        configuration.save(to: defaults)
        #expect(CaptureHotkeyConfiguration.load(from: defaults) == configuration)
        defaults.set(Data("invalid".utf8), forKey: "capture_hotkeys_v1")
        #expect(CaptureHotkeyConfiguration.load(from: defaults) == CaptureHotkeyConfiguration())
    }
    @Test @MainActor func recorderSupportsStandardButtonActivationAndCancellation() {
        _ = NSApplication.shared
        let button = ShortcutRecorderButton(frame: .zero)
        button.performClick(nil)
        #expect(button.recording)
        button.finish()
        #expect(!button.recording)
    }
    @Test @MainActor func nativeAreaSelectionAllowsSpaceAndWindowHover() {
        let path = URL(fileURLWithPath: "/tmp/a path/capture.png")
        let area = ScreenCaptureService.interactiveArguments(startsWithWindow: false, output: path)
        let window = ScreenCaptureService.interactiveArguments(startsWithWindow: true, output: path)
        #expect(area.contains("-i") && !area.contains("-s") && !area.contains("-w"))
        #expect(!area.contains("-W") && window.contains("-W"))
        #expect(area.last == path.path && window.last == path.path)
    }
}
