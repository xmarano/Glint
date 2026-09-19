#if DEBUG
import AppKit
import Carbon
import SwiftUI

/// Opt-in development harness: real AppKit event loop, private preferences/pasteboard.
/// No synthetic system keystrokes, Accessibility access, or user document changes.
@MainActor
final class SmokeCheckDelegate: NSObject, NSApplicationDelegate {
    private var controller: FloatingPanelController?
    private var model: AssistantModel?
    private var shortcuts: ShortcutManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do {
                try await check()
                print("PASS: native panel, focus, Carbon hotkey dispatch, clipboard, dismissal, Settings render")
                NSApp.terminate(nil)
            } catch {
                print("FAIL: \(error)")
                exit(1)
            }
        }
    }

    private func check() async throws {
        let domain = "com.glint.smoke.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let settings = SettingsManager(defaults: defaults)
        let shortcuts = ShortcutManager()
        self.shortcuts = shortcuts
        defer { shortcuts.shutdown() }
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let live = ProcessInfo.processInfo.environment["GLINT_SMOKE_LIVE"] == "1"
        let model = AssistantModel(settings: settings, shortcuts: shortcuts,
                                   provider: live ? nil : SmokeProvider(), pasteboard: pasteboard)
        self.model = model
        controller = FloatingPanelController(model: model)
        model.start()
        try require(shortcuts.current != nil, "No default hotkey could be registered")
        print("Registered default: \(shortcuts.current!.display)")
        let selected = shortcuts.current
        model.changeShortcut(Shortcut(keyCode: 49, modifiers: UInt32(cmdKey), keyLabel: "Space"))
        try require(shortcuts.current == selected, "System shortcut conflict was not rejected")
        if let selected { model.changeShortcut(selected) }
        let originalPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // Dispatch the same Carbon event delivered by the registered global shortcut.
        var event: EventRef?
        try require(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed),
            GetCurrentEventTime(), 0, &event) == noErr, "Create hotkey event")
        if let event {
            var identifier = EventHotKeyID(signature: 0x474C4E54, id: 1)
            SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              MemoryLayout<EventHotKeyID>.size, &identifier)
            SendEventToEventTarget(event, GetApplicationEventTarget())
            ReleaseEvent(event)
        }
        try await Task.sleep(for: .milliseconds(200))
        try require(model.state == .input, "Hotkey did not open input")
        let panel = try window()
        try require(panel.isKeyWindow, "Input panel did not become key")
        try require(panel.firstResponder is NSTextView, "Text field did not receive focus")
        try require(NSWorkspace.shared.frontmostApplication?.processIdentifier == originalPID,
                    "Nonactivating panel changed the frontmost app")
        try snapshot(panel, name: "input-preview")
        model.query = "What is 12 * 12?"
        model.submit()
        try require(model.state == .processing, "Submit did not start processing")
        try require(!panel.isKeyWindow, "Status pill kept keyboard focus")
        for _ in 0..<460 {
            if model.state != .processing { break }
            try await Task.sleep(for: .milliseconds(200))
        }
        try require(model.state == .success, "Request did not succeed")
        try require(pasteboard.string(forType: .string) == "144", "Clipboard mismatch")
        try snapshot(panel, name: "success-preview")
        try await Task.sleep(for: .milliseconds(1400))
        try require(!panel.isVisible && model.state == .hidden, "Success pill did not dismiss")
        model.toggleInput()
        model.toggleInput()
        try require(model.state == .hidden, "Repeated shortcut did not toggle closed")
        model.cancel()
        let settingsWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 700),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        settingsWindow.contentView = NSHostingView(rootView: SettingsView(model: model, settings: settings))
        settingsWindow.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(150))
        // Settings intentionally displays the real executable path. Exercise its
        // rendering, but never export it as a documentation screenshot.
        settingsWindow.orderOut(nil)
    }

    private func window() throws -> NSWindow {
        guard let panel = NSApp.windows.first(where: { $0.accessibilityLabel() == "Glint assistant" }) else {
            throw SmokeError.failed("Panel missing")
        }
        return panel
    }

    private func snapshot(_ window: NSWindow, name: String) throws {
        guard Self.permitsSnapshot(name: name) else { return }
        guard let destination = ProcessInfo.processInfo.environment["GLINT_SNAPSHOT_DIR"],
              let view = window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        if let data = bitmap.representation(using: .png, properties: [:]) {
            try data.write(to: URL(fileURLWithPath: destination).appendingPathComponent(name + ".png"))
        }
    }

    static func permitsSnapshot(name: String) -> Bool {
        ["input-preview", "success-preview"].contains(name)
    }
    private func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw SmokeError.failed(message) }
    }
}

private enum SmokeError: Error { case failed(String) }
private struct SmokeProvider: AIProvider {
    func ask(_ prompt: String) async throws -> String {
        try await Task.sleep(for: .milliseconds(200))
        return "144"
    }
}
#endif
