// ClaudeCodeService.swift
// Finding and preprocessing Claude Code plan files for TTS

import Foundation

/// Service for reading and preprocessing Claude Code plan files
final class ClaudeCodeService {
    private let readbackProcessor: ReadbackProcessor

    init(readbackProcessor: ReadbackProcessor = ReadbackProcessor()) {
        self.readbackProcessor = readbackProcessor
    }

    /// Find the most recent Claude Code plan/conversation file
    func findRecentPlan() -> URL? {
        let fm = FileManager.default
        let claudeDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        let projectsDir = claudeDir.appendingPathComponent("projects")

        guard fm.fileExists(atPath: projectsDir.path) else { return nil }

        // Recursively find .md files under ~/.claude/projects/
        var bestFile: URL?
        var bestDate: Date = .distantPast

        guard let enumerator = fm.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }
            if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = values.contentModificationDate,
               modDate > bestDate {
                bestDate = modDate
                bestFile = fileURL
            }
        }

        return bestFile
    }

    /// Read a plan file and return the raw content
    func readPlan(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    /// Preprocess markdown plan text for natural TTS output
    func preprocessForSpeech(_ markdown: String) -> String {
        readbackProcessor.preprocessForSpeech(markdown)
    }
}
