import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var model: AssistantModel
    @ObservedObject var settings: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                GlintMark().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Glint").font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text("A little help, right where you are.").foregroundStyle(.secondary)
                }
            }
            Form {
                Section("Global shortcut") {
                    ShortcutRecorder(label: settings.shortcut?.display ?? "Record shortcut",
                        onRecord: model.changeShortcut,
                        recordingChanged: { model.shortcuts.isRecording = $0 })
                        .frame(height: 30)
                    Text(model.shortcutDiagnostic).font(.caption).foregroundStyle(.secondary)
                    Text("Click to record. Press the shortcut again to close. macOS registration detects many conflicts, but shortcuts intercepted by other apps may not be discoverable.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("AI provider · Codex CLI") {
                    HStack {
                        TextField("Automatic executable discovery", text: $settings.executablePath)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { Task { await model.checkExecutable() } }
                        Button("Choose…", action: chooseExecutable)
                    }
                    if !model.resolvedPath.isEmpty {
                        Text(model.resolvedPath).font(.caption.monospaced()).textSelection(.enabled)
                    }
                    HStack {
                        Button(model.testing ? "Testing…" : "Test Codex", action: model.testCodex)
                            .disabled(model.testing)
                        Button("Find Executable") { Task { await model.checkExecutable() } }
                    }
                    Text(model.diagnostic).font(.caption).textSelection(.enabled)
                }
                Section("Behavior") {
                    Toggle("Copy answer automatically", isOn: $settings.copyAutomatically)
                    Text("When off, use Copy Last Answer in the menu. That answer stays in memory until copied, replaced, or the app quits.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped)
            Text("Only the request you submit is sent to Codex. No history, screenshots, keyboard monitoring, or automatic paste.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(width: 560, height: 700)
        .onDisappear { model.shortcuts.isRecording = false }
    }

    private func chooseExecutable() {
        let picker = NSOpenPanel()
        picker.title = "Choose the Codex executable"
        picker.canChooseDirectories = false
        picker.showsHiddenFiles = true
        picker.allowsMultipleSelection = false
        guard picker.runModal() == .OK, let url = picker.url else { return }
        settings.executablePath = url.path
        Task { await model.checkExecutable() }
    }
}
