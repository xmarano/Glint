import AppKit
import SwiftUI

@main
struct GlintApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate: any NSApplicationDelegate
        #if DEBUG
        if CommandLine.arguments.contains("--smoke-test") { delegate = SmokeCheckDelegate() }
        else { delegate = AppDelegate() }
        #else
        delegate = AppDelegate()
        #endif
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let settings = SettingsManager()
    private let shortcuts = ShortcutManager()
    private lazy var model = AssistantModel(settings: settings, shortcuts: shortcuts)
    private var panel: FloatingPanelController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = FloatingPanelController(model: model)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = GlintBrand.menuBarImage()
        statusItem?.button?.toolTip = "Glint — inline AI assistant"
        menu.delegate = self
        statusItem?.menu = menu
        installEditMenu()
        model.start()
        if !settings.hasLaunched || shortcuts.current == nil {
            settings.hasLaunched = true
            showSettings()
        }
        Log.app.info("Glint started")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add("Ask Glint    \(settings.shortcut?.display ?? "")", #selector(ask))
        if model.state == .processing { add("Cancel Request", #selector(cancel)) }
        if model.pendingAnswer != nil { add("Copy Last Answer", #selector(copyAnswer)) }
        menu.addItem(.separator())
        add("Settings…", #selector(showSettings))
        add("Test Codex", #selector(test))
        add("About Glint", #selector(about))
        menu.addItem(.separator())
        add("Quit Glint", #selector(quit))
    }
    private func add(_ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }
    @objc private func ask() { model.toggleInput() }
    @objc private func cancel() { model.cancel() }
    @objc private func copyAnswer() { model.copyPendingAnswer() }
    @objc private func test() { model.testCodex() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func about() {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Glint", .applicationVersion: "1.0.0",
            .credits: NSAttributedString(string: "An inline AI assistant for macOS.\nPowered by your local Codex CLI.")])
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showSettings() {
        model.cancel()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 700),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Glint Settings"
            window.contentView = NSHostingView(rootView: SettingsView(model: model, settings: settings))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationWillTerminate(_ notification: Notification) {
        model.cancel()
        shortcuts.shutdown()
    }
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === settingsWindow {
            // End local shortcut recording as soon as Settings loses keyboard focus.
            window.makeFirstResponder(nil)
            shortcuts.isRecording = false
        }
    }
    private func installEditMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Glint", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        for (title, action, key) in [("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }
}
