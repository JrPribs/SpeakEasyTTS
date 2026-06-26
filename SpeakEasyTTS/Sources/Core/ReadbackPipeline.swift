// ReadbackPipeline.swift
// Coordinates readback request processing before speech synthesis.

import Foundation

struct ReadbackPipeline {
    private let aiInteractionService: AIInteractionService?

    init(aiInteractionService: AIInteractionService? = nil) {
        self.aiInteractionService = aiInteractionService
    }

    func process(_ request: ReadbackRequest) -> ReadbackResult {
        deterministicProcess(request)
    }

    func processWithOptionalSummary(_ request: ReadbackRequest) async -> ReadbackResult {
        let fallback = deterministicProcess(request)
        guard request.processingOptions.requestAISummary,
              let aiInteractionService else {
            return fallback
        }

        do {
            let response = try await aiInteractionService.summarizeReadback(AIReadbackSummaryRequest(
                readbackRequest: request,
                deterministicText: fallback.spokenText
            ))
            let summary = response.summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !summary.isEmpty else {
                return fallback
            }

            return ReadbackResult(request: request, spokenText: summary)
        } catch {
            return fallback
        }
    }

    private func deterministicProcess(_ request: ReadbackRequest) -> ReadbackResult {
        var spokenText = request.text

        if request.processingOptions.normalizeMarkdown {
            spokenText = MarkdownSpeechNormalizer(
                summarizesCodeBlocks: request.processingOptions.summarizeCodeBlocks
            ).normalize(spokenText)
        }

        return ReadbackResult(request: request, spokenText: spokenText)
    }
}

private struct MarkdownSpeechNormalizer {
    var summarizesCodeBlocks: Bool

    func normalize(_ markdown: String) -> String {
        let withoutCodeBlocks = replaceFencedCodeBlocks(in: markdown)
        let lines = withoutCodeBlocks.components(separatedBy: .newlines)
        var output: [String] = []
        var index = 0

        while index < lines.count {
            if let table = parseTable(in: lines, startingAt: index) {
                output.append(contentsOf: table.spokenLines)
                index = table.nextIndex
                continue
            }

            if let quote = parseBlockquote(in: lines, startingAt: index) {
                output.append(quote.spokenLine)
                index = quote.nextIndex
                continue
            }

            output.append(normalizeLine(lines[index]))
            index += 1
        }

        return cleanWhitespace(output.joined(separator: "\n"))
    }

    private func replaceFencedCodeBlocks(in text: String) -> String {
        let pattern = #"```([^\n`]*)\n?([\s\S]*?)```"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }

            let language: String?
            if match.range(at: 1).location != NSNotFound,
               let languageRange = Range(match.range(at: 1), in: result),
               let firstToken = String(result[languageRange])
                .split(whereSeparator: \.isWhitespace)
                .first {
                language = String(firstToken)
            } else {
                language = nil
            }

            let content: String
            if match.range(at: 2).location != NSNotFound,
               let contentRange = Range(match.range(at: 2), in: result) {
                content = String(result[contentRange])
            } else {
                content = ""
            }

            let replacement = summarizesCodeBlocks
                ? summarizeCodeBlock(language: language, content: content)
                : codeBlockPlaceholder(language: language)

            result.replaceSubrange(
                range,
                with: "\n\(replacement)\n"
            )
        }

        return result
    }

    private func codeBlockPlaceholder(language: String?) -> String {
        guard let language,
              !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Code block omitted."
        }

        return "\(language) code block omitted."
    }

    private func summarizeCodeBlock(language: String?, content: String) -> String {
        let lines = codeLines(from: content)
        let kind = codeBlockKind(language: language, lines: lines)
        var parts = ["\(kind.displayName) block, \(lineCountDescription(lines.count))"]

        switch kind {
        case .shell:
            let commands = extractShellCommands(from: lines)
            if !commands.isEmpty {
                parts.append("Commands: \(commands.joined(separator: ", "))")
            }
        case .swift:
            let symbols = extractSwiftSymbols(from: lines)
            if !symbols.isEmpty {
                parts.append("Symbols: \(symbols.joined(separator: ", "))")
            }
        case .diff:
            let files = extractDiffFiles(from: lines)
            if !files.isEmpty {
                parts.append("Files: \(files.joined(separator: ", "))")
            }
        case .json, .config, .markdown, .code:
            let files = extractFilePaths(from: lines)
            if !files.isEmpty {
                parts.append("Files: \(files.joined(separator: ", "))")
            }
        }

        return parts.map(withTerminalPunctuation).joined(separator: " ")
    }

    private func codeLines(from content: String) -> [String] {
        let trimmed = content.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else { return [] }

        return trimmed.components(separatedBy: .newlines)
    }

    private func lineCountDescription(_ count: Int) -> String {
        count == 1 ? "1 line" : "\(count) lines"
    }

    private func codeBlockKind(language: String?, lines: [String]) -> CodeBlockKind {
        if let languageKind = CodeBlockKind(language: language) {
            return languageKind
        }

        if looksLikeDiff(lines) {
            return .diff(nil)
        }
        if looksLikeJSON(lines) {
            return .json(nil)
        }
        if looksLikeShell(lines) {
            return .shell(nil)
        }
        if looksLikeMarkdown(lines) {
            return .markdown(nil)
        }
        if looksLikeConfig(lines) {
            return .config(nil)
        }

        return .code(language)
    }

    private func looksLikeDiff(_ lines: [String]) -> Bool {
        lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("diff --git ")
                || trimmed.hasPrefix("+++ ")
                || trimmed.hasPrefix("--- ")
        }
    }

    private func looksLikeJSON(_ lines: [String]) -> Bool {
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (text.hasPrefix("{") && text.hasSuffix("}"))
            || (text.hasPrefix("[") && text.hasSuffix("]"))
    }

    private func looksLikeShell(_ lines: [String]) -> Bool {
        let commands = extractShellCommands(from: lines)
        return !commands.isEmpty
    }

    private func looksLikeMarkdown(_ lines: [String]) -> Bool {
        lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("# ")
                || trimmed.hasPrefix("## ")
                || trimmed.hasPrefix("- ")
                || trimmed.hasPrefix("* ")
        }
    }

    private func looksLikeConfig(_ lines: [String]) -> Bool {
        lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.contains("=")
                || match(trimmed, pattern: #"^[A-Za-z0-9_.-]+:\s*.+"#) != nil
        }
    }

    private func extractShellCommands(from lines: [String]) -> [String] {
        uniqueValues(lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("#") else {
                return nil
            }

            let commandLine = strippedShellPrompt(from: trimmed)
            let tokens = commandLine
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
            guard let command = tokens.first,
                  isLikelyShellCommand(command) else {
                return nil
            }

            if tokens.count > 1,
               shouldIncludeShellSubcommand(command) {
                return "\(command) \(tokens[1])"
            }

            return command
        })
    }

    private func strippedShellPrompt(from line: String) -> String {
        if line.hasPrefix("$ ") {
            return String(line.dropFirst(2))
        }
        if line.hasPrefix("% ") {
            return String(line.dropFirst(2))
        }

        return line
    }

    private func isLikelyShellCommand(_ command: String) -> Bool {
        [
            "brew",
            "cat",
            "cd",
            "chmod",
            "cp",
            "curl",
            "git",
            "grep",
            "ls",
            "mkdir",
            "mv",
            "node",
            "npm",
            "npx",
            "pnpm",
            "python",
            "python3",
            "rg",
            "rm",
            "swift",
            "xcodebuild",
            "yarn"
        ].contains(command)
    }

    private func shouldIncludeShellSubcommand(_ command: String) -> Bool {
        ["brew", "git", "npm", "pnpm", "swift", "yarn"].contains(command)
    }

    private func extractSwiftSymbols(from lines: [String]) -> [String] {
        uniqueValues(lines.flatMap { line in
            captureMatches(
                in: line,
                pattern: #"\b(?:actor|class|enum|extension|func|let|protocol|struct|var)\s+([A-Za-z_][A-Za-z0-9_]*)"#
            )
        })
    }

    private func extractDiffFiles(from lines: [String]) -> [String] {
        uniqueValues(lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("diff --git ") {
                let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
                return parts.count >= 4 ? stripDiffPrefix(parts[3]) : nil
            }

            if trimmed.hasPrefix("+++ ") || trimmed.hasPrefix("--- ") {
                let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
                guard parts.count >= 2,
                      parts[1] != "/dev/null" else {
                    return nil
                }

                return stripDiffPrefix(parts[1])
            }

            return nil
        })
    }

    private func stripDiffPrefix(_ path: String) -> String {
        if path.hasPrefix("a/") || path.hasPrefix("b/") {
            return String(path.dropFirst(2))
        }

        return path
    }

    private func extractFilePaths(from lines: [String]) -> [String] {
        uniqueValues(lines.flatMap { line in
            captureMatches(in: line, pattern: #"([A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)+)"#)
        })
    }

    private func parseTable(
        in lines: [String],
        startingAt index: Int
    ) -> (spokenLines: [String], nextIndex: Int)? {
        guard index + 1 < lines.count,
              isTableRow(lines[index]),
              isTableSeparator(lines[index + 1]) else {
            return nil
        }

        let header = tableCells(from: lines[index]).map(normalizeInline)
        var rowIndex = index + 2
        var rows: [[String]] = []

        while rowIndex < lines.count, isTableRow(lines[rowIndex]) {
            rows.append(tableCells(from: lines[rowIndex]).map(normalizeInline))
            rowIndex += 1
        }

        var spokenLines = ["Table: \(header.joined(separator: ", "))."]
        for (offset, row) in rows.enumerated() {
            spokenLines.append("Row \(offset + 1): \(row.joined(separator: ", ")).")
        }

        return (spokenLines, rowIndex)
    }

    private func isTableRow(_ line: String) -> Bool {
        line.contains("|")
    }

    private func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(from: line)

        return !cells.isEmpty && cells.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            return trimmed.contains("-")
                && trimmed.allSatisfy { character in
                    character == "-" || character == ":" || character == " "
                }
        }
    }

    private func tableCells(from line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.first == "|" {
            trimmed.removeFirst()
        }
        if trimmed.last == "|" {
            trimmed.removeLast()
        }

        return trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func parseBlockquote(
        in lines: [String],
        startingAt index: Int
    ) -> (spokenLine: String, nextIndex: Int)? {
        guard isBlockquote(lines[index]) else { return nil }

        var quoteLines: [String] = []
        var quoteIndex = index
        while quoteIndex < lines.count, isBlockquote(lines[quoteIndex]) {
            quoteLines.append(stripBlockquoteMarker(from: lines[quoteIndex]))
            quoteIndex += 1
        }

        let quote = quoteLines
            .map(normalizeInline)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return ("Quote: \(withTerminalPunctuation(quote))", quoteIndex)
    }

    private func isBlockquote(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    private func stripBlockquoteMarker(from line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private func normalizeLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }

        if let heading = headingParts(from: trimmed) {
            let text = normalizeInline(heading.text)
            switch heading.level {
            case 1:
                return withTerminalPunctuation(text)
            case 2:
                return "Section: \(withTerminalPunctuation(text))"
            default:
                return "Sub-section: \(withTerminalPunctuation(text))"
            }
        }

        if let checkbox = checkboxParts(from: trimmed) {
            let prefix = checkbox.isCompleted ? "Completed" : "To do"
            return "\(prefix): \(withTerminalPunctuation(normalizeInline(checkbox.text)))"
        }

        if let bulletText = bulletText(from: trimmed) {
            return withTerminalPunctuation(normalizeInline(bulletText))
        }

        if let numbered = numberedParts(from: trimmed) {
            return "Step \(numbered.number): \(withTerminalPunctuation(normalizeInline(numbered.text)))"
        }

        return withTerminalPunctuation(normalizeInline(trimmed))
    }

    private func headingParts(from line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty,
              hashes.count <= 6,
              line.dropFirst(hashes.count).first == " " else {
            return nil
        }

        return (hashes.count, String(line.dropFirst(hashes.count + 1)))
    }

    private func checkboxParts(from line: String) -> (isCompleted: Bool, text: String)? {
        match(line, pattern: #"^[-*+]\s+\[([ xX])\]\s+(.+)$"#).flatMap { captures in
            guard captures.count == 2 else { return nil }
            return (captures[0].lowercased() == "x", captures[1])
        }
    }

    private func bulletText(from line: String) -> String? {
        match(line, pattern: #"^[-*+]\s+(.+)$"#).flatMap { captures in
            captures.first
        }
    }

    private func numberedParts(from line: String) -> (number: String, text: String)? {
        match(line, pattern: #"^([0-9]+)[.)]\s+(.+)$"#).flatMap { captures in
            guard captures.count == 2 else { return nil }
            return (captures[0], captures[1])
        }
    }

    private func normalizeInline(_ text: String) -> String {
        var result = text

        result = replaceMatches(
            in: result,
            pattern: #"\[([^\]]+)\]\(([^)]+)\)"#,
            template: "$1"
        )
        result = replaceMatches(in: result, pattern: #"`([^`]+)`"#, template: "$1")
        result = replaceMatches(in: result, pattern: #"\*\*([^*]+)\*\*"#, template: "$1")
        result = replaceMatches(in: result, pattern: #"__([^_]+)__"#, template: "$1")
        result = replaceMatches(in: result, pattern: #"~~([^~]+)~~"#, template: "$1")
        result = replaceMatches(in: result, pattern: #"\*([^*]+)\*"#, template: "$1")
        result = convertFilePaths(in: result)

        return result.trimmingCharacters(in: .whitespaces)
    }

    private func convertFilePaths(in text: String) -> String {
        let pattern = #"/?[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  !isURLPath(range, in: result) else {
                continue
            }

            let path = String(result[range])
            result.replaceSubrange(range, with: speakPath(path))
        }

        return result
    }

    private func isURLPath(_ range: Range<String.Index>, in text: String) -> Bool {
        let prefixStart = text.index(range.lowerBound, offsetBy: -min(10, text.distance(from: text.startIndex, to: range.lowerBound)))
        let prefix = text[prefixStart..<range.lowerBound]
        return prefix.contains("://")
    }

    private func speakPath(_ path: String) -> String {
        path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .components(separatedBy: "/")
            .filter { !$0.isEmpty }
            .map(speakPathComponent)
            .joined(separator: ", ")
    }

    private func speakPathComponent(_ component: String) -> String {
        guard let dotIndex = component.lastIndex(of: "."),
              dotIndex != component.startIndex,
              dotIndex < component.index(before: component.endIndex) else {
            return component
        }

        let name = component[..<dotIndex]
        let ext = component[component.index(after: dotIndex)...]
        return "\(name) dot \(ext)"
    }

    private func withTerminalPunctuation(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if let last = trimmed.last,
           ".!?".contains(last) {
            return trimmed
        }

        return "\(trimmed)."
    }

    private func cleanWhitespace(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var output: [String] = []
        var previousWasBlank = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !previousWasBlank {
                    output.append("")
                }
                previousWasBlank = true
            } else {
                output.append(trimmed)
                previousWasBlank = false
            }
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func match(_ text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: text) else {
                return nil
            }
            return String(text[range])
        }
    }

    private func captureMatches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else {
                return nil
            }

            return String(text[range])
        }
    }

    private func uniqueValues(_ values: [String], limit: Int = 4) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            guard !seen.contains(value) else { continue }

            seen.insert(value)
            result.append(value)
            if result.count == limit {
                return result
            }
        }

        return result
    }

    private func replaceMatches(
        in text: String,
        pattern: String,
        template: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: template
        )
    }
}

private enum CodeBlockKind: Equatable {
    case shell(String?)
    case swift
    case json(String?)
    case diff(String?)
    case config(String?)
    case markdown(String?)
    case code(String?)

    init?(language: String?) {
        guard let language,
              !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let normalized = language.lowercased()
        switch normalized {
        case "bash", "sh", "shell", "zsh":
            self = .shell(language)
        case "swift":
            self = .swift
        case "json":
            self = .json(language)
        case "diff", "patch":
            self = .diff(language)
        case "env", "ini", "plist", "toml", "yaml", "yml":
            self = .config(language)
        case "md", "markdown":
            self = .markdown(language)
        default:
            self = .code(language)
        }
    }

    var displayName: String {
        switch self {
        case .shell(let language):
            if let language {
                return "\(languageDisplayName(language)) shell commands"
            }
            return "Shell commands"
        case .swift:
            return "Swift code"
        case .json:
            return "JSON"
        case .diff:
            return "Diff"
        case .config(let language):
            if let language {
                return "\(languageDisplayName(language)) config"
            }
            return "Config"
        case .markdown:
            return "Markdown"
        case .code(let language):
            if let language {
                return "\(languageDisplayName(language)) code"
            }
            return "Code"
        }
    }

    private func languageDisplayName(_ language: String) -> String {
        switch language.lowercased() {
        case "bash":
            return "Bash"
        case "sh":
            return "Shell"
        case "zsh":
            return "Z shell"
        case "yaml", "yml":
            return "YAML"
        case "toml":
            return "TOML"
        case "env":
            return "Env"
        case "md":
            return "Markdown"
        default:
            return language
        }
    }
}
