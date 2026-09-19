import OSLog

enum Log {
    static let app = Logger(subsystem: "com.glint.assistant", category: "app")
    static let process = Logger(subsystem: "com.glint.assistant", category: "process")
    static let shortcut = Logger(subsystem: "com.glint.assistant", category: "shortcut")
}
