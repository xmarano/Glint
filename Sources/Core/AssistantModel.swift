import AppKit
import Combine

enum PanelState: Equatable {
    case hidden, input, processing, success, testSuccess, ready, error(String)
}

@MainActor
final class AssistantModel: ObservableObject {
    @Published private(set) var state: PanelState = .hidden
    @Published var query = ""
    @Published var diagnostic = "Checking Codex…"
    @Published var shortcutDiagnostic = ""
    @Published var resolvedPath = ""
    @Published var testing = false
    @Published private(set) var pendingAnswer: String?
    let settings: SettingsManager
    let shortcuts: ShortcutManager
    var stateChanged: ((PanelState) -> Void)?
    var restoreFocus: (() -> Void)?
    var preparePanel: (() -> Void)?
    private var request: Task<Void, Never>?
    private var dismissal: Task<Void, Never>?
    private var generation = UUID()
    private let providerOverride: (any AIProvider)?
    private let pasteboard: NSPasteboard

    init(settings: SettingsManager, shortcuts: ShortcutManager,
         provider: (any AIProvider)? = nil, pasteboard: NSPasteboard = .general) {
        self.settings = settings
        self.shortcuts = shortcuts
        self.providerOverride = provider
        self.pasteboard = pasteboard
    }

    func start() {
        shortcuts.onTrigger = { [weak self] in self?.toggleInput() }
        if let saved = settings.shortcut { changeShortcut(saved) }
        else {
            for candidate in Shortcut.candidates {
                do {
                    try shortcuts.register(candidate)
                    settings.shortcut = candidate
                    shortcutDiagnostic = "Registered \(candidate.display)"
                    break
                } catch { shortcutDiagnostic = error.localizedDescription }
            }
        }
        Task { await checkExecutable() }
    }

    func changeShortcut(_ shortcut: Shortcut) {
        do {
            try shortcuts.register(shortcut)
            settings.shortcut = shortcut
            shortcutDiagnostic = "Registered \(shortcut.display)"
        } catch { shortcutDiagnostic = error.localizedDescription }
    }

    func checkExecutable() async {
        do {
            let url = try await ExecutableDiscovery.find(configuredPath: settings.executablePath)
            resolvedPath = url.path
            diagnostic = "Codex found. Use Test Codex to verify sign-in and connectivity."
        } catch {
            resolvedPath = ""
            diagnostic = error.localizedDescription
        }
    }

    func toggleInput() {
        if state == .input { cancel(); return }
        cancelWork()
        pendingAnswer = nil
        query = ""
        preparePanel?()
        transition(.input)
    }

    func submit() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard text.utf8.count <= 32_000 else {
            diagnostic = "The request is too long. Keep it under 32 KB."
            return
        }
        query = ""
        run(text, isTest: false)
    }

    func testCodex() {
        query = ""
        preparePanel?()
        run("What is 12 * 12? Return only the number.", isTest: true)
    }

    private func run(_ query: String, isTest: Bool) {
        cancelWork()
        pendingAnswer = nil
        testing = isTest
        let id = generation
        let path = settings.executablePath
        let shouldCopy = settings.copyAutomatically
        let providerOverride = providerOverride
        transition(.processing)
        restoreFocus?()
        request = Task { [weak self] in
            do {
                let executable: URL?
                let provider: any AIProvider
                if let providerOverride {
                    executable = nil
                    provider = providerOverride
                } else {
                    let discovered = try await ExecutableDiscovery.find(configuredPath: path)
                    executable = discovered
                    provider = CodexCLIProvider(executable: discovered)
                }
                let answer = try await provider.ask(PromptBuilder.build(query))
                try Task.checkCancellation()
                guard let self, self.generation == id else { return }
                if let executable { self.resolvedPath = executable.path }
                if isTest {
                    guard answer.trimmingCharacters(in: .whitespacesAndNewlines) == "144" else {
                        throw AssistantError.invalidResponse
                    }
                    self.diagnostic = "Test passed: Codex returned the expected arithmetic answer. Clipboard unchanged."
                    self.transition(.testSuccess)
                } else if shouldCopy {
                    try ClipboardManager.copy(answer, to: self.pasteboard)
                    self.diagnostic = "Last request succeeded; answer copied. No request history is stored."
                    self.transition(.success)
                } else {
                    self.pendingAnswer = answer
                    self.diagnostic = "Answer ready in memory. Choose Copy Last Answer from the menu."
                    self.transition(.ready)
                }
                self.testing = false
                self.scheduleDismissal(after: 1.3)
            } catch is CancellationError {
                // The newer generation owns all UI and clipboard changes.
            } catch {
                guard let self, self.generation == id, !Task.isCancelled else { return }
                self.testing = false
                self.diagnostic = error.localizedDescription
                self.transition(.error((error as? AssistantError)?.shortMessage ?? "Request failed"))
                Log.app.error("Request failed; sanitized diagnostics available in Settings")
                self.scheduleDismissal(after: 3)
            }
        }
    }

    func copyPendingAnswer() {
        guard let answer = pendingAnswer else { return }
        do {
            try ClipboardManager.copy(answer, to: pasteboard)
            pendingAnswer = nil
            transition(.success)
            scheduleDismissal(after: 1.3)
        } catch { diagnostic = error.localizedDescription }
    }

    func cancel() {
        cancelWork()
        query = ""
        pendingAnswer = nil
        transition(.hidden)
        restoreFocus?()
    }

    private func cancelWork() {
        generation = UUID()
        request?.cancel()
        request = nil
        dismissal?.cancel()
        dismissal = nil
        testing = false
    }

    private func scheduleDismissal(after seconds: Double) {
        let id = generation
        dismissal = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self, self.generation == id else { return }
            self.transition(.hidden)
        }
    }

    private func transition(_ state: PanelState) {
        self.state = state
        Log.app.debug("Panel state changed")
        stateChanged?(state)
    }
}
