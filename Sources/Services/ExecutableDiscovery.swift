import Foundation

enum ExecutableDiscovery {
    static func find(configuredPath: String, searchDirectories: [String]? = nil) async throws -> URL {
        let configured = configuredPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !configured.isEmpty {
            let path = NSString(string: configured).expandingTildeInPath
            guard isExecutable(path) else { throw AssistantError.invalidExecutable }
            return URL(fileURLWithPath: path)
        }
        let directories = searchDirectories ?? candidateDirectories()
        for directory in directories where directory.hasPrefix("/") {
            let candidate = directory + "/codex"
            if isExecutable(candidate) { return URL(fileURLWithPath: candidate) }
        }
        // Never execute shell startup files just to locate a binary. Custom nvm/asdf
        // installations can be selected explicitly with Settings > Choose.
        throw AssistantError.unavailable
    }

    private static func candidateDirectories() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (ProcessInfo.processInfo.environment["PATH"] ?? "").components(separatedBy: ":")
            + ["\(home)/.local/bin", "\(home)/.npm-global/bin", "\(home)/.volta/bin",
               "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/Applications/Codex.app/Contents/Resources"]
    }

    private static func isExecutable(_ path: String) -> Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &directory)
            && !directory.boolValue && FileManager.default.isExecutableFile(atPath: path)
    }

    static func processEnvironment(_ executable: URL,
                                   inherited: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        // Deliberate boundary: existing login/API-key auth, locale, and intentional
        // network trust/proxy configuration only. Never pass SSH/GitHub/AWS secrets,
        // shell initialization hooks, DYLD_*, NODE_OPTIONS or arbitrary CODEX_*.
        let allowed = ["HOME", "TMPDIR", "LANG", "LC_ALL", "LC_CTYPE", "TZ",
                       "CODEX_HOME", "CODEX_API_KEY", "OPENAI_API_KEY",
                       "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
                       "http_proxy", "https_proxy", "all_proxy", "no_proxy",
                       "CODEX_CA_CERTIFICATE", "SSL_CERT_FILE", "SSL_CERT_DIR", "NODE_EXTRA_CA_CERTS"]
        var environment = inherited.filter { allowed.contains($0.key) }
        if environment["HOME"] == nil {
            environment["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        }
        if environment["TMPDIR"] == nil {
            environment["TMPDIR"] = FileManager.default.temporaryDirectory.path
        }
        // Retain absolute custom runtime locations for /usr/bin/env node installs,
        // but discard empty/relative entries that could execute from the work dir.
        let paths = [executable.deletingLastPathComponent().path,
                     "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
            + (inherited["PATH"] ?? "").components(separatedBy: ":")
        var seen = Set<String>()
        environment["PATH"] = paths.filter { $0.hasPrefix("/") && seen.insert($0).inserted }.joined(separator: ":")
        environment["NO_COLOR"] = "1"
        environment["TERM"] = "dumb"
        // Never inherit a verbose logging configuration that might record request content.
        environment["RUST_LOG"] = "off"
        return environment
    }
}
