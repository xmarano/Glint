import Foundation

/// An empty per-request directory, not a prompt/response store. Never sweeps other
/// temporary directories; a crashed app may leave its own directory behind.
struct TemporaryWorkspace {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("glint-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
        } catch {
            Log.process.error("Could not create private request workspace")
            throw AssistantError.launchFailed // Do not surface an NSError containing a personal path.
        }
    }

    @discardableResult
    func remove(using removeItem: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) -> Bool {
        do { try removeItem(url); return true }
        catch {
            // No error interpolation: NSError may contain paths or child-created names.
            Log.process.error("Private request workspace cleanup failed; local temporary data may remain")
            return false
        }
    }
}
