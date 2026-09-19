import SwiftUI
import AppKit

struct PromptInputView: View {
    @ObservedObject var model: AssistantModel
    var body: some View {
        HStack(spacing: 14) {
            GlintMark().frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("GLINT").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(2)
                    Spacer()
                    Text("esc to close").font(.system(size: 10)).foregroundStyle(.tertiary)
                }.foregroundStyle(.secondary)
                PromptField(text: $model.query, onSubmit: model.submit, onCancel: model.cancel)
                    .frame(height: 26)
            }
            Button(action: model.submit) {
                Image(systemName: "arrow.up").font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Submit request")
        }
        .padding(.horizontal, 21).padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 23))
        .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
        .padding(8)
    }
}

private struct PromptField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = InputTextField()
        field.placeholderString = "Ask anything…"
        field.font = .systemFont(ofSize: 18, weight: .regular)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.setAccessibilityLabel("Ask Glint")
        field.lineBreakMode = .byTruncatingHead
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PromptField
        init(_ parent: PromptField) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) { parent.onSubmit(); return true }
            if selector == #selector(NSResponder.cancelOperation(_:)) { parent.onCancel(); return true }
            return false
        }
    }
}

private final class InputTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, window.isVisible else { return }
            window.makeFirstResponder(self)
        }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            let selectors: [String: Selector] = ["a": #selector(NSText.selectAll(_:)),
                "c": #selector(NSText.copy(_:)), "v": #selector(NSText.paste(_:)), "x": #selector(NSText.cut(_:))]
            if let key = event.charactersIgnoringModifiers, let action = selectors[key] {
                return NSApp.sendAction(action, to: window?.firstResponder, from: self)
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct StatusPill: View {
    @ObservedObject var model: AssistantModel
    var body: some View {
        HStack(spacing: 9) {
            switch model.state {
            case .processing:
                ProgressView().controlSize(.small)
                Text(model.testing ? "Testing Codex" : "Thinking")
                Button(action: model.cancel) { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Cancel request")
            case .success:
                Image(systemName: "checkmark").foregroundStyle(.mint)
                Text("Copied")
            case .testSuccess:
                Image(systemName: "checkmark").foregroundStyle(.mint)
                Text("Connected")
            case .ready:
                Image(systemName: "checkmark").foregroundStyle(.mint)
                Text("Ready in menu")
            case .error(let text):
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text(text)
            default: EmptyView()
            }
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 17).frame(height: 37)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.09), lineWidth: 1))
        .padding(8)
    }
}
