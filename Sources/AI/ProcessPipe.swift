import Foundation
import Darwin

/// Poll only the parent's pipe ends. Nonblocking IO plus a short poll interval lets
/// cancellation stop readers/writers even if a descendant retains the other ends.
enum ProcessPipe {
    static func makeNonblocking(_ handle: FileHandle) -> Bool {
        let fd = handle.fileDescriptor
        let flags = fcntl(fd, F_GETFL)
        return flags >= 0 && fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0
    }

    static func drain(_ handle: FileHandle, stopped: () -> Bool, consume: (Data) -> Void) -> Bool {
        defer { try? handle.close() }
        let fd = handle.fileDescriptor
        var bytes = [UInt8](repeating: 0, count: 16_384)
        while !stopped() {
            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, 20)
            if ready < 0 { if errno == EINTR { continue }; return false }
            if ready == 0 { continue }
            let count = Darwin.read(fd, &bytes, bytes.count)
            if count == 0 { return true }
            if count < 0 {
                if errno == EAGAIN || errno == EINTR { continue }
                return false
            }
            consume(Data(bytes.prefix(count)))
        }
        return false
    }

    static func write(_ input: Data, to handle: FileHandle, stopped: () -> Bool) {
        defer { try? handle.close() }
        let fd = handle.fileDescriptor
        input.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count && !stopped() {
                var descriptor = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
                let ready = poll(&descriptor, 1, 20)
                if ready < 0 { if errno == EINTR { continue }; return }
                if ready == 0 { continue }
                let count = Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), min(16_384, bytes.count - offset))
                if count < 0 {
                    if errno == EAGAIN || errno == EINTR { continue }
                    return // EPIPE: the child exited without consuming all input.
                }
                if count == 0 { return }
                offset += count
            }
        }
    }
}
