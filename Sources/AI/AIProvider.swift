import Foundation

protocol AIProvider: Sendable {
    func ask(_ prompt: String) async throws -> String
}

enum AssistantError: Error, LocalizedError {
    case unavailable, invalidExecutable, timeout, outputTooLarge, invalidResponse, emptyResponse
    case processFailed(Int32, String)
    case launchFailed, clipboardFailed, incompleteProcessOutput

    var errorDescription: String? {
        switch self {
        case .unavailable: "Codex unavailable. Choose the executable in Settings, then run Test Codex."
        case .invalidExecutable: "The configured Codex path is not an executable file."
        case .timeout: "Codex timed out after 90 seconds. Check your connection and try again."
        case .outputTooLarge: "Codex output exceeded the memory limit. Try a smaller request."
        case .invalidResponse: "Codex returned an incomplete or unsupported JSON event stream. Update Codex and retry."
        case .emptyResponse: "Codex returned an empty answer."
        case let .processFailed(code, hint): "Codex exited with status \(code). \(hint)"
        case .launchFailed: "Could not launch Codex. Check the executable path and file permissions."
        case .clipboardFailed: "The answer could not be written to the clipboard."
        case .incompleteProcessOutput: "Codex did not close its output cleanly. Try again or choose a standalone Codex executable."
        }
    }

    var shortMessage: String {
        switch self {
        case .unavailable, .invalidExecutable, .launchFailed: "Codex unavailable"
        case .timeout: "Request timed out"
        case .clipboardFailed: "Copy failed"
        default: "Request failed"
        }
    }
}
