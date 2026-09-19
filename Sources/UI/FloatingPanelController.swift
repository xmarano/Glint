import AppKit
import SwiftUI

private final class AssistantPanel: NSPanel {
    var acceptsInput = false
    override var canBecomeKey: Bool { acceptsInput }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let panel: AssistantPanel
    private let model: AssistantModel
    private var originalApplication: NSRunningApplication?
    private var targetScreen: NSScreen?
    private var changingState = false

    init(model: AssistantModel) {
        self.model = model
        panel = AssistantPanel(contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.delegate = self
        panel.setAccessibilityLabel("Glint assistant")
        model.preparePanel = { [weak self] in self?.captureContext() }
        model.restoreFocus = { [weak self] in self?.restoreApplication() }
        model.stateChanged = { [weak self] in self?.show($0) }
    }

    private func captureContext() {
        let app = NSWorkspace.shared.frontmostApplication
        if app?.processIdentifier != ProcessInfo.processInfo.processIdentifier { originalApplication = app }
        targetScreen = ScreenLocator.screen(for: originalApplication)
    }

    private func show(_ state: PanelState) {
        changingState = true
        defer { changingState = false }
        // Ordering out releases the nonactivating panel's keyboard focus before status display.
        panel.orderOut(nil)
        guard state != .hidden else { panel.contentView = nil; return }
        let input = state == .input
        panel.acceptsInput = input
        panel.contentView = input
            ? NSHostingView(rootView: AnyView(PromptInputView(model: model)))
            : NSHostingView(rootView: AnyView(StatusPill(model: model)))
        let screen = targetScreen.flatMap { target in NSScreen.screens.first { $0 == target } }
            ?? ScreenLocator.screen(for: originalApplication)
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 700)
        let width = min(input ? 550.0 : 250.0, visible.width - 24)
        let height = input ? 100.0 : 55.0
        panel.setFrame(NSRect(x: visible.midX - width / 2, y: visible.minY + 24,
                             width: width, height: height), display: true)
        if input { panel.makeKeyAndOrderFront(nil) }
        else { panel.orderFrontRegardless() }
    }

    private func restoreApplication() {
        // Never interrupt someone who switched to a different app during the request.
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier == ProcessInfo.processInfo.processIdentifier,
           let originalApplication, !originalApplication.isTerminated {
            originalApplication.activate(options: [])
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if !changingState, model.state == .input { model.cancel() }
    }
}

@MainActor
enum ScreenLocator {
    static func screen(for application: NSRunningApplication?) -> NSScreen? {
        // Read only frontmost-app window geometry; never titles, pixels, or accessibility text.
        // macOS may withhold metadata. Pointer screen is the permission-free fallback.
        if let pid = application?.processIdentifier,
           let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
           let window = windows.first(where: {
               ($0[kCGWindowOwnerPID as String] as? Int32) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
           }), let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
           let x = bounds["X"], let y = bounds["Y"], let w = bounds["Width"], let h = bounds["Height"],
           let primary = NSScreen.screens.first {
            let rect = NSRect(x: x, y: primary.frame.maxY - y - h, width: w, height: h)
            let best = NSScreen.screens.max { area($0.frame.intersection(rect)) < area($1.frame.intersection(rect)) }
            if let best, area(best.frame.intersection(rect)) > 0 { return best }
        }
        return NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }
    private static func area(_ rect: NSRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }
}
