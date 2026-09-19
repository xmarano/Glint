import SwiftUI
import AppKit

struct ShortcutRecorder: NSViewRepresentable {
    let label: String
    let onRecord: (Shortcut) -> Void
    let recordingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.target = button
        button.action = #selector(RecorderButton.beginRecording)
        button.setAccessibilityLabel("Record global shortcut")
        return button
    }
    func updateNSView(_ button: RecorderButton, context: Context) {
        button.normalTitle = label
        button.onRecord = onRecord
        button.recordingChanged = recordingChanged
        if !button.recording { button.title = label }
    }
    static func dismantleNSView(_ button: RecorderButton, coordinator: ()) { button.endRecording() }
}

final class RecorderButton: NSButton {
    var normalTitle = "Record shortcut"
    var onRecord: ((Shortcut) -> Void)?
    var recordingChanged: ((Bool) -> Void)?
    private(set) var recording = false
    private var monitor: Any?
    override var acceptsFirstResponder: Bool { true }

    @objc func beginRecording() {
        if recording { endRecording(); return }
        window?.makeFirstResponder(self)
        recording = true
        recordingChanged?(true)
        title = "Press shortcut… (Esc cancels)"
        // Local monitor exists ONLY while this Settings control is recording.
        // It never observes keystrokes delivered to other applications.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.recording else { return event }
            if event.keyCode == 53 { self.endRecording(); return nil }
            guard let shortcut = Shortcut.from(event) else {
                self.title = "Include ⌃ Control or ⌘ Command"
                return nil
            }
            self.endRecording()
            self.onRecord?(shortcut)
            return nil
        }
    }
    func endRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        recordingChanged?(false)
        title = normalTitle
    }
    override func resignFirstResponder() -> Bool { endRecording(); return super.resignFirstResponder() }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { endRecording() }
        super.viewWillMove(toWindow: newWindow)
    }
}
