import AppKit
import Carbon

@MainActor
final class ShortcutManager {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private(set) var current: Shortcut?
    var onTrigger: (() -> Void)?
    var isRecording = false
    private var identifier: UInt32 = 0

    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard identifier.signature == 0x474C4E54 else { return OSStatus(eventNotHandledErr) }
            // Carbon delivers this handler on the application's main event loop.
            MainActor.assumeIsolated {
                let manager = Unmanaged<ShortcutManager>.fromOpaque(context).takeUnretainedValue()
                if !manager.isRecording { manager.onTrigger?() }
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        Log.shortcut.info("Hotkey event handler status=\(status)")
    }

    func register(_ shortcut: Shortcut) throws {
        if current == shortcut, hotKey != nil { return }
        guard handler != nil else { throw ShortcutError.registration(-1) }
        if Self.systemConflict(shortcut) { throw ShortcutError.systemConflict }
        // Preserve the working shortcut if the proposed registration fails.
        var candidate: EventHotKeyRef?
        identifier &+= 1
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
            EventHotKeyID(signature: 0x474C4E54, id: identifier), GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive), &candidate)
        Log.shortcut.info("Shortcut registration status=\(status)")
        guard status == noErr, let candidate else { throw ShortcutError.registration(status) }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = candidate
        current = shortcut
    }

    func shutdown() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }

    static func systemConflict(_ shortcut: Shortcut) -> Bool {
        var entries: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&entries) == noErr,
              let entries = entries?.takeRetainedValue() as? [[String: Any]] else { return false }
        return entries.contains {
            ($0[kHISymbolicHotKeyEnabled as String] as? NSNumber)?.boolValue == true
                && ($0[kHISymbolicHotKeyCode as String] as? NSNumber)?.uint32Value == shortcut.keyCode
                && ($0[kHISymbolicHotKeyModifiers as String] as? NSNumber)?.uint32Value == shortcut.modifiers
        }
    }
}

enum ShortcutError: LocalizedError {
    case systemConflict, registration(OSStatus)
    var errorDescription: String? {
        switch self {
        case .systemConflict: "That shortcut is enabled in macOS Keyboard Shortcuts. Choose another combination."
        case let .registration(code): "Shortcut unavailable (macOS status \(code)). Choose another combination. Your previous shortcut is unchanged."
        }
    }
}
