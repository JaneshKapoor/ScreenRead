import OSLog

/// Thin wrapper over `os.Logger` so log lines show up in Console.app under the
/// `com.JaneshKapoor.ScreenRead` subsystem — useful when debugging a build that
/// runs as a background agent with no window to print into.
enum Log {
    private static let logger = Logger(subsystem: "com.JaneshKapoor.ScreenRead", category: "app")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
