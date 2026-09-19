import Foundation

struct CodexCLIProvider: AIProvider {
    let executable: URL

    static let arguments = [
        "exec", "--ignore-user-config", "--ignore-rules", "--ephemeral",
        "--skip-git-repo-check", "--json", "--color", "never", "--sandbox", "read-only",
        "-c", "approval_policy=\"never\"", "-c", "model_reasoning_effort=\"low\"",
        "-c", "web_search=\"disabled\"", "-c", "history.persistence=\"none\"",
        "-c", "project_doc_max_bytes=0",
        "-c", "features.shell_tool=false", "-c", "features.unified_exec=false",
        "-c", "features.multi_agent=false", "-c", "features.apps=false",
        "-c", "features.plugins=false", "-c", "features.hooks=false",
        "-c", "features.memories=false", "-c", "features.shell_snapshot=false",
        "-c", "features.browser_use=false", "-c", "features.computer_use=false",
        "-c", "features.view_image=false", "-c", "features.image_generation=false",
        "-c", "features.skill_search=false", "-c", "features.skip_host_skill_discovery=true",
        "-"
    ]

    func ask(_ prompt: String) async throws -> String {
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let result = try await ProcessRunner().run(executable: executable, arguments: Self.arguments,
            input: prompt, directory: workspace.url, environment: ExecutableDiscovery.processEnvironment(executable))
        try Task.checkCancellation()
        guard result.exitCode == 0 else {
            throw AssistantError.processFailed(result.exitCode, Self.failureHint(result.stderr))
        }
        guard !result.truncated else { throw AssistantError.outputTooLarge }
        return try Self.finalAnswer(from: result.stdout)
    }

    static func finalAnswer(from data: Data) throws -> String {
        var lastMessage: String?
        var completed = false
        for line in data.split(separator: 10) where !line.isEmpty {
            guard let event = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let type = event["type"] as? String else { throw AssistantError.invalidResponse }
            if type == "turn.failed" || type == "error" { throw AssistantError.invalidResponse }
            if type == "turn.completed" { completed = true }
            if type == "item.completed", let item = event["item"] as? [String: Any],
               item["type"] as? String == "agent_message", let text = item["text"] as? String {
                lastMessage = text
            }
        }
        guard completed, let message = lastMessage else { throw AssistantError.invalidResponse }
        // Preserve code indentation, Markdown and explicitly requested formatting.
        // Formatting is controlled in the prompt, never by deleting arbitrary prose/fences.
        let answer = message.trimmingCharacters(in: .newlines)
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw AssistantError.emptyResponse }
        return answer
    }

    private static func failureHint(_ data: Data) -> String {
        // Raw stderr may echo a prompt. Only surface fixed diagnostic categories.
        let text = String(decoding: data, as: UTF8.self).lowercased()
        if text.contains("401") || text.contains("login") || text.contains("authentication") {
            return "Run codex login in Terminal once, then Test Codex again."
        }
        if text.contains("unexpected argument") || text.contains("unrecognized") {
            return "Update Codex; this integration was verified with CLI 0.153.4."
        }
        if text.contains("429") || text.contains("usage limit") { return "Your Codex usage limit may have been reached." }
        if text.contains("connect") || text.contains("network") { return "Check your network connection and Codex service availability." }
        return "Run codex --version and codex login status to check the installation."
    }
}
