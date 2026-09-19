import AppKit
import Carbon

struct Shortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    static let candidates = [
        Shortcut(keyCode: 49, modifiers: UInt32(controlKey | optionKey), keyLabel: "Space"),
        Shortcut(keyCode: 0, modifiers: UInt32(controlKey | optionKey | shiftKey), keyLabel: "A"),
        Shortcut(keyCode: 40, modifiers: UInt32(controlKey | optionKey | cmdKey), keyLabel: "K")
    ]

    var display: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + keyLabel
    }

    static func from(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Require Command or Control to avoid taking ordinary text input / Option accents.
        guard flags.contains(.command) || flags.contains(.control),
              ![36, 48, 51, 53, 76, 117].contains(Int(event.keyCode)) else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let special: [UInt16: String] = [49: "Space", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        let label = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
    }
}
