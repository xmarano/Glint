import AppKit
import Testing
@testable import Glint

@MainActor
struct DesktopTests {
    @Test func clipboardContainsOnlyAnswer() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        try ClipboardManager.copy("144", to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "144")
        #expect(pasteboard.types?.contains(.string) == true)
        #expect(pasteboard.types?.contains(.rtf) == false)
        #expect(pasteboard.types?.contains(.html) == false)
    }
    @Test func shortcutPersistence() throws {
        let name = "com.glint.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = SettingsManager(defaults: defaults)
        settings.shortcut = Shortcut.candidates[1]
        settings.copyAutomatically = false
        let reloaded = SettingsManager(defaults: defaults)
        #expect(reloaded.shortcut == Shortcut.candidates[1])
        #expect(!reloaded.copyAutomatically)
    }
    @Test func currentScreenCanBeLocated() {
        #expect(ScreenLocator.screen(for: NSWorkspace.shared.frontmostApplication) != nil)
    }
}
