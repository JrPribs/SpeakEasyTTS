// AppLog.swift
// Lightweight runtime logging categories.

import Foundation
import OSLog

enum AppLog {
    struct Category {
        private let logger: Logger

        init(_ category: String) {
            logger = Logger(subsystem: AppLog.subsystem, category: category)
        }

        func debug(_ message: String) {
            logger.debug("\(message, privacy: .public)")
        }

        func info(_ message: String) {
            logger.info("\(message, privacy: .public)")
        }

        func warning(_ message: String) {
            logger.warning("\(message, privacy: .public)")
        }

        func error(_ message: String) {
            logger.error("\(message, privacy: .public)")
        }
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.speakeasy.tts"

    static let app = Category("app")
    static let permissions = Category("permissions")
    static let dictation = Category("dictation")
    static let shortcuts = Category("shortcuts")
    static let readback = Category("readback")
    static let ai = Category("ai")
    static let insertion = Category("insertion")
    static let tts = Category("tts")
}
