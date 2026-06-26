// ReadbackProcessor.swift
// Pure markdown preprocessing for speech readback

import Foundation

struct ReadbackProcessor {
    /// Preprocess markdown text for natural TTS output.
    func preprocessForSpeech(_ markdown: String) -> String {
        var text = markdown

        text = removeCodeBlocks(text)
        text = convertHeadings(text)
        text = convertBulletLists(text)
        text = cleanInlineFormatting(text)
        text = convertFilePaths(text)
        text = cleanWhitespace(text)

        return text
    }

    /// Remove fenced code blocks and any leftover fence markers.
    private func removeCodeBlocks(_ text: String) -> String {
        // Match ```language\n...\n``` blocks.
        let pattern = "```(\\w+)?\\n[\\s\\S]*?```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        let range = NSRange(text.startIndex..., in: text)
        let result = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")

        return result.replacingOccurrences(of: "``` ", with: "")
            .replacingOccurrences(of: "```", with: "")
    }

    /// Convert markdown headings to spoken form.
    private func convertHeadings(_ text: String) -> String {
        var result = text

        // #### -> Sub-section (handle deepest first).
        let h4Pattern = "(?m)^####\\s+(.+)$"
        if let regex = try? NSRegularExpression(pattern: h4Pattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\nSub-section: $1.\n"
            )
        }

        // ### -> Sub-section.
        let h3Pattern = "(?m)^###\\s+(.+)$"
        if let regex = try? NSRegularExpression(pattern: h3Pattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\nSub-section: $1.\n"
            )
        }

        // ## -> Section.
        let h2Pattern = "(?m)^##\\s+(.+)$"
        if let regex = try? NSRegularExpression(pattern: h2Pattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\nSection: $1.\n"
            )
        }

        // # -> main heading.
        let h1Pattern = "(?m)^#\\s+(.+)$"
        if let regex = try? NSRegularExpression(pattern: h1Pattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "\n\n$1.\n"
            )
        }

        return result
    }

    /// Convert consecutive bullet list items into flowing comma-separated text.
    private func convertBulletLists(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var bulletGroup: [String] = []

        func flushBullets() {
            guard !bulletGroup.isEmpty else { return }
            if bulletGroup.count == 1 {
                result.append(bulletGroup[0] + ".")
            } else {
                var sentence = bulletGroup.dropLast().joined(separator: ", ")
                sentence += ", and " + bulletGroup.last! + "."
                result.append(sentence)
            }
            bulletGroup.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let item = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !item.isEmpty {
                    bulletGroup.append(item)
                }
            } else {
                flushBullets()
                result.append(line)
            }
        }
        flushBullets()

        return result.joined(separator: "\n")
    }

    /// Remove inline formatting markers (backticks, bold, italic).
    private func cleanInlineFormatting(_ text: String) -> String {
        var result = text

        // Remove inline backticks: `code` -> code.
        let backtickPattern = "`([^`]+)`"
        if let regex = try? NSRegularExpression(pattern: backtickPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Remove bold markers: **text** -> text.
        let boldPattern = "\\*\\*([^*]+)\\*\\*"
        if let regex = try? NSRegularExpression(pattern: boldPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Remove italic markers: *text* -> text.
        let italicPattern = "\\*([^*]+)\\*"
        if let regex = try? NSRegularExpression(pattern: italicPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        return result
    }

    /// Convert file paths to spoken form: src/auth/login.ts -> src, auth, login dot ts.
    private func convertFilePaths(_ text: String) -> String {
        // Match paths like word/word/file.ext (at least one slash).
        let pathPattern = "\\b([a-zA-Z0-9_.-]+(?:/[a-zA-Z0-9_.-]+)+)\\b"
        guard let regex = try? NSRegularExpression(pattern: pathPattern) else { return text }

        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        // Process matches in reverse to preserve ranges.
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let path = String(result[range])
            let spoken = speakPath(path)
            result.replaceSubrange(range, with: spoken)
        }

        return result
    }

    /// Convert a single file path to spoken form.
    private func speakPath(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        let spoken = components.map { component -> String in
            if let dotIndex = component.lastIndex(of: ".") {
                let name = component[component.startIndex..<dotIndex]
                let ext = component[component.index(after: dotIndex)...]
                return "\(name) dot \(ext)"
            }
            return component
        }
        return spoken.joined(separator: ", ")
    }

    /// Collapse multiple newlines and trim whitespace.
    private func cleanWhitespace(_ text: String) -> String {
        var result = text

        // Collapse 3+ newlines to 2.
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
