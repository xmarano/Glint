import AppKit
import Testing
@testable import Glint

private struct DelayedProvider: AIProvider {
    func ask(_ prompt: String) async throws -> String {
        if prompt.hasSuffix("old") {
            // Simulate a provider that ignores cancellation and completes late.
            try? await Task.sleep(for: .milliseconds(250))
            return "stale"
        }
        try await Task.sleep(for: .milliseconds(20))
        return "newest"
    }
}

@MainActor
struct CoordinatorTests {
    @Test func supersededRequestCannotOverwriteClipboard() async throws {
        let name = "com.glint.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let shortcuts = ShortcutManager()
        defer { shortcuts.shutdown() }
        let model = AssistantModel(settings: SettingsManager(defaults: defaults), shortcuts: shortcuts,
                                   provider: DelayedProvider(), pasteboard: pasteboard)
        model.toggleInput()
        model.query = "old"
        model.submit()
        try await Task.sleep(for: .milliseconds(30))
        model.toggleInput()
        model.query = "new"
        model.submit()
        try await Task.sleep(for: .milliseconds(150))
        #expect(pasteboard.string(forType: .string) == "newest")
        #expect(model.state == .success)
        model.cancel()
    }

    @Test func cancellationClearsInputAndPreservesClipboard() async throws {
        let name = "com.glint.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("existing", forType: .string)
        let shortcuts = ShortcutManager()
        defer { shortcuts.shutdown() }
        let model = AssistantModel(settings: SettingsManager(defaults: defaults), shortcuts: shortcuts,
                                   provider: DelayedProvider(), pasteboard: pasteboard)
        model.toggleInput()
        model.query = "old"
        model.submit()
        model.cancel()
        try await Task.sleep(for: .milliseconds(100))
        #expect(pasteboard.string(forType: .string) == "existing")
        #expect(model.state == .hidden)
        #expect(model.query.isEmpty)
    }
}
