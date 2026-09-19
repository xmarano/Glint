import Foundation
import Testing
@testable import Glint

struct ProviderTests {
    @Test func extractsFinalMessageOnly() throws {
        let stream = """
        {"type":"thread.started","thread_id":"test"}
        {"type":"item.completed","item":{"type":"reasoning","text":"private reasoning"}}
        {"type":"item.completed","item":{"type":"agent_message","text":"Working…"}}
        {"type":"item.completed","item":{"type":"agent_message","text":"144"}}
        {"type":"turn.completed"}
        """
        #expect(try CodexCLIProvider.finalAnswer(from: Data(stream.utf8)) == "144")
    }
    @Test func preservesCodeIndentationAndRequestedMarkdown() throws {
        let answer = "    return x\n\n**Requested formatting**"
        let event: [String: Any] = ["type": "item.completed", "item": ["type": "agent_message", "text": answer]]
        var data = try JSONSerialization.data(withJSONObject: event)
        data.append(Data("\n{\"type\":\"turn.completed\"}\n".utf8))
        #expect(try CodexCLIProvider.finalAnswer(from: data) == answer)
    }
    @Test(arguments: ["", "not json", "{\"type\":\"turn.failed\"}",
        "{\"type\":\"item.completed\",\"item\":{\"type\":\"agent_message\",\"text\":\"partial\"}}",
        "{\"type\":\"item.completed\",\"item\":{\"type\":\"agent_message\",\"text\":\" \"}}\n{\"type\":\"turn.completed\"}"])
    func rejectsInvalidOrIncompleteOutput(_ input: String) {
        #expect(throws: (any Error).self) { try CodexCLIProvider.finalAnswer(from: Data(input.utf8)) }
    }
    @Test func drainsBothPipesAndCapturesExit() async throws {
        let result = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "i=0; while [ $i -lt 6000 ]; do echo output; echo diagnostic >&2; i=$((i+1)); done; exit 7"])
        #expect(result.exitCode == 7)
        #expect(result.stdout.count == 42000)
        #expect(!result.stderr.isEmpty)
    }
    @Test func inputNeverInterpretedAsShellCode() async throws {
        let input = "$(touch should-not-exist) `echo injected` ' \"\nhello"
        let result = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/cat"), arguments: [], input: input)
        #expect(String(decoding: result.stdout, as: UTF8.self) == input)
    }
    @Test func cancellationStopsChild() async throws {
        let task = Task { try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"]) }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled process succeeded") }
        catch is CancellationError { }
    }
    @Test func timeoutStopsChild() async throws {
        do {
            _ = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"], timeout: 0.1)
            Issue.record("Timed out process succeeded")
        } catch AssistantError.timeout { }
    }
    @Test func outputIsBounded() async throws {
        let result = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/usr/bin/head"),
            arguments: ["-c", "2100000", "/dev/zero"])
        #expect(result.stdout.count == 2_000_000)
        #expect(result.truncated)
    }
    @Test func invalidConfiguredPathDoesNotSilentlyFallBack() async {
        await #expect(throws: (any Error).self) {
            try await ExecutableDiscovery.find(configuredPath: "/does-not-exist/codex")
        }
    }
    @Test(.enabled(if: ProcessInfo.processInfo.environment["GLINT_LIVE_TESTS"] == "1"))
    func realCodexAcceptanceQueries() async throws {
        let executable = try await ExecutableDiscovery.find(configuredPath: "")
        let provider = CodexCLIProvider(executable: executable)
        let arithmetic = try await provider.ask(PromptBuilder.build("What is 12 * 12?"))
        #expect(arithmetic == "144")
        let code = try await provider.ask(PromptBuilder.build("python list comprehension from 1 to 10 squares"))
        let normalized = code.replacingOccurrences(of: " ", with: "")
        #expect(normalized == "[x**2forxinrange(1,11)]")
    }
}
