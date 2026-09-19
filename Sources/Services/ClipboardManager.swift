import AppKit

@MainActor
enum ClipboardManager {
    static func copy(_ answer: String, to pasteboard: NSPasteboard = .general) throws {
        pasteboard.clearContents()
        guard pasteboard.setString(answer, forType: .string) else { throw AssistantError.clipboardFailed }
    }
}
