import Foundation

struct ProcessResult: Sendable {
    let stdout: Data
    let stderr: Data
    let exitCode: Int32
    let truncated: Bool
}

/// A one-shot process. Blocking pipe reads and writes always run off the main actor.
/// The lock protects launch/cancellation races; each pipe has one reader.
final class ProcessRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private var timedOut = false
    private var finished = false
    private var stopIO = false

    private var ioStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopIO
    }

    func run(executable: URL, arguments: [String], input: String = "",
             directory: URL? = nil, environment: [String: String] = [:],
             timeout: TimeInterval = 90) async throws -> ProcessResult {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    self.execute(executable: executable, arguments: arguments, input: input,
                                 directory: directory, environment: environment,
                                 timeout: timeout, continuation: continuation)
                }
            }
        } onCancel: {
            self.stop(timeout: false)
        }
    }

    private func execute(executable: URL, arguments: [String], input: String,
                         directory: URL?, environment: [String: String], timeout: TimeInterval,
                         continuation: CheckedContinuation<ProcessResult, Error>) {
        let child = Process()
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        // Default is an empty environment, never implicit parent inheritance.
        guard ProcessPipe.makeNonblocking(stdin.fileHandleForWriting),
              ProcessPipe.makeNonblocking(stdout.fileHandleForReading),
              ProcessPipe.makeNonblocking(stderr.fileHandleForReading) else {
            continuation.resume(throwing: AssistantError.launchFailed)
            return
        }
        // A child that exits before consuming stdin must not deliver SIGPIPE to the app.
        _ = fcntl(stdin.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        child.executableURL = executable
        child.arguments = arguments
        child.currentDirectoryURL = directory
        child.environment = environment
        child.standardInput = stdin
        child.standardOutput = stdout
        child.standardError = stderr

        lock.lock()
        if cancelled {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        process = child
        do { try child.run() } catch {
            finished = true
            lock.unlock()
            continuation.resume(throwing: AssistantError.launchFailed)
            return
        }
        lock.unlock()
        Log.process.info("Subprocess launched")
        let started = Date()
        let out = StreamBuffer(limit: 2_000_000), err = StreamBuffer(limit: 64_000)
        let group = DispatchGroup()
        for (handle, buffer) in [(stdout.fileHandleForReading, out), (stderr.fileHandleForReading, err)] {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                defer { group.leave() }
                buffer.complete = ProcessPipe.drain(handle, stopped: { self.ioStopped }, consume: buffer.append)
            }
        }
        // A separate writer lets cancellation terminate a process that never reads stdin.
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            ProcessPipe.write(Data(input.utf8), to: stdin.fileHandleForWriting, stopped: { self.ioStopped })
            group.leave()
        }
        let timer = DispatchWorkItem { [weak self] in self?.stop(timeout: true) }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
        child.waitUntilExit()
        // A descendant can keep stdout/stderr/stdin open after the direct child
        // exits. Give buffered output a short drain grace, then close our ends.
        // The overall timeout remains armed through draining.
        let pipesCompleted = group.wait(timeout: .now() + 0.5) == .success
        if !pipesCompleted {
            lock.lock()
            stopIO = true
            lock.unlock()
            Log.process.error("Subprocess pipes did not close after exit; output discarded")
        }
        // Workers use only nonblocking IO and 20ms polls; none can wait for a
        // descendant indefinitely. Join before inspecting their buffers.
        group.wait()
        timer.cancel()
        lock.lock()
        finished = true
        process = nil
        let wasCancelled = cancelled, wasTimeout = timedOut
        lock.unlock()
        let duration = Date().timeIntervalSince(started)
        Log.process.info("Subprocess exited status=\(child.terminationStatus) duration=\(duration, format: .fixed(precision: 2))s")
        if wasTimeout { continuation.resume(throwing: AssistantError.timeout) }
        else if wasCancelled { continuation.resume(throwing: CancellationError()) }
        else if !pipesCompleted || !out.complete || !err.complete {
            continuation.resume(throwing: AssistantError.incompleteProcessOutput)
        }
        else {
            continuation.resume(returning: ProcessResult(stdout: out.data, stderr: err.data,
                exitCode: child.terminationStatus, truncated: out.truncated))
        }
    }

    private func stop(timeout: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        if timeout { timedOut = true } else { cancelled = true }
        stopIO = true
        guard let child = process, child.isRunning else { return }
        child.terminate()
        // Codex may take time to shut down its embedded server. Bound that delay.
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self, child] in
            guard let self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            if !self.finished && child.isRunning { kill(child.processIdentifier, SIGKILL) }
        }
    }
}

/// Written by a single reader queue, read only after DispatchGroup synchronization.
private final class StreamBuffer: @unchecked Sendable {
    var data = Data()
    var truncated = false
    var complete = false
    let limit: Int
    init(limit: Int) { self.limit = limit }
    func append(_ chunk: Data) {
        let remaining = max(0, limit - data.count)
        data.append(chunk.prefix(remaining))
        if chunk.count > remaining { truncated = true }
    }
}
