import Foundation
import Testing
@testable import Glint

struct SecurityTests {
    private let executable = URL(fileURLWithPath: "/synthetic/runtime/codex")

    @Test func onlyIntentionalEnvironmentReachesChild() async throws {
        let sentinel = "synthetic-not-a-real-credential"
        let rejected = ["GITHUB_TOKEN", "GH_TOKEN", "AWS_SECRET_ACCESS_KEY", "ANTHROPIC_API_KEY",
                        "SSH_AUTH_SOCK", "NODE_OPTIONS", "DYLD_INSERT_LIBRARIES", "BASH_ENV", "ENV",
                        "SHELL", "CODEX_UNKNOWN_SECRET", "OPENAI_BASE_URL", "GLINT_PRIVATE_SENTINEL"]
        var inherited = Dictionary(uniqueKeysWithValues: rejected.map { ($0, sentinel) })
        inherited["RUST_LOG"] = "trace"
        inherited["HOME"] = "/synthetic/home"
        inherited["PATH"] = ":.:relative:/synthetic/node/bin:/usr/bin:"
        let environment = ExecutableDiscovery.processEnvironment(executable, inherited: inherited)
        for key in rejected { #expect(environment[key] == nil) }
        #expect(environment["RUST_LOG"] == "off")
        #expect(environment["NO_COLOR"] == "1")
        #expect(environment["TERM"] == "dumb")
        let paths = try #require(environment["PATH"]).components(separatedBy: ":")
        #expect(paths.allSatisfy { $0.hasPrefix("/") })
        #expect(paths.count == Set(paths).count)
        #expect(paths.contains("/synthetic/node/bin"))

        // Verify the actual Process.environment boundary, not just the dictionary.
        let result = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/usr/bin/env"),
                                                   arguments: [], environment: environment)
        let output = String(decoding: result.stdout, as: UTF8.self)
        #expect(!output.contains(sentinel))
        #expect(output.contains("HOME=/synthetic/home"))
    }

    @Test func preservesExplicitCodexAuthenticationAndNetworkConfiguration() {
        let allowed = ["HOME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "TZ",
                       "CODEX_HOME", "CODEX_API_KEY", "OPENAI_API_KEY",
                       "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
                       "http_proxy", "https_proxy", "all_proxy", "no_proxy",
                       "CODEX_CA_CERTIFICATE", "SSL_CERT_FILE", "SSL_CERT_DIR", "NODE_EXTRA_CA_CERTS"]
        // Never read actual credentials in a regression test.
        let fixture = Dictionary(uniqueKeysWithValues: allowed.map { ($0, "synthetic-\($0)") })
        let environment = ExecutableDiscovery.processEnvironment(executable, inherited: fixture)
        for key in allowed { #expect(environment[key] == fixture[key]) }
        #expect(Set(environment.keys) == Set(allowed + ["PATH", "TERM", "NO_COLOR", "RUST_LOG"]))
    }

    @Test func defaultProcessEnvironmentIsEmpty() async throws {
        let result = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/usr/bin/env"), arguments: [])
        #expect(result.exitCode == 0)
        #expect(result.stdout.isEmpty)
    }

    @Test func discoveryDoesNotFallBackToShell() async throws {
        do {
            _ = try await ExecutableDiscovery.find(configuredPath: "", searchDirectories: [])
            Issue.record("Discovery must fail without executing a shell")
        } catch AssistantError.unavailable { }
        // Explicit selection still works even without a searchable PATH.
        let selected = try await ExecutableDiscovery.find(configuredPath: "/bin/cat", searchDirectories: [])
        #expect(selected.path == "/bin/cat")
    }

    @Test func privateWorkspacePermissionsAndCleanup() throws {
        let workspace = try TemporaryWorkspace()
        defer { if FileManager.default.fileExists(atPath: workspace.url.path) { workspace.remove() } }
        let attributes = try FileManager.default.attributesOfItem(atPath: workspace.url.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        #expect(try FileManager.default.contentsOfDirectory(atPath: workspace.url.path).isEmpty)
        let removed = workspace.remove()
        #expect(removed)
        #expect(!FileManager.default.fileExists(atPath: workspace.url.path))
    }

    @Test func cleanupFailureIsReportedWithoutPropagatingRawError() throws {
        let workspace = try TemporaryWorkspace()
        defer { workspace.remove() }
        let removed = workspace.remove { _ in
            throw NSError(domain: "synthetic", code: 1, userInfo: [NSLocalizedDescriptionKey: "synthetic sensitive path"])
        }
        #expect(!removed)
        #expect(FileManager.default.fileExists(atPath: workspace.url.path))
    }

    @Test func inheritedDescendantPipesCannotHangCompletion() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            // The descendant exits naturally; no permanent fixture process remains.
            _ = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "/bin/sleep 3 & exit 0"], timeout: 5)
            Issue.record("An unclosed descendant pipe must not produce a usable answer")
        } catch AssistantError.incompleteProcessOutput { }
        #expect(start.duration(to: clock.now) < .seconds(2))
    }

    @Test func cancellationWithBlockedInputIsBounded() async throws {
        let task = Task {
            try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["30"], input: String(repeating: "x", count: 2_000_000))
        }
        try await Task.sleep(for: .milliseconds(100))
        let clock = ContinuousClock()
        let start = clock.now
        task.cancel()
        do { _ = try await task.value; Issue.record("Cancelled process succeeded") }
        catch is CancellationError { }
        #expect(start.duration(to: clock.now) < .seconds(3))
    }

    @Test func earlyExitWithUnconsumedInputDoesNotCrash() async throws {
        let result = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/usr/bin/true"),
            arguments: [], input: String(repeating: "x", count: 2_000_000), timeout: 2)
        #expect(result.exitCode == 0)
    }

    @Test func timeoutRemainsArmedWhileDrainingDescendantPipes() async throws {
        do {
            _ = try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "/bin/sleep 3 & exit 0"], timeout: 0.1)
            Issue.record("Timeout must cover IO after direct child exit")
        } catch AssistantError.timeout { }
    }

    #if DEBUG
    @Test @MainActor func documentationSnapshotsExcludeSettings() {
        #expect(SmokeCheckDelegate.permitsSnapshot(name: "input-preview"))
        #expect(SmokeCheckDelegate.permitsSnapshot(name: "success-preview"))
        #expect(!SmokeCheckDelegate.permitsSnapshot(name: "settings-preview"))
        #expect(!SmokeCheckDelegate.permitsSnapshot(name: "../settings-preview"))
    }
    #endif
}
