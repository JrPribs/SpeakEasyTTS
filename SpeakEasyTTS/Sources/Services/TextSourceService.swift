// TextSourceService.swift
// Resolves user-facing text sources into speakable text plus source metadata.

import Foundation

enum TextSourceRequest: Equatable {
    case manualText(String)
    case clipboard
    case selectedText
    case recentClaudePlan
    case claudePlanFile(URL)
    case focusedTextField
}

struct TextSourceResult: Equatable {
    var text: String
    var source: InteractionSource
}

enum TextSourceError: LocalizedError, Equatable {
    case emptyManualText
    case clipboardUnavailable
    case selectedTextUnavailable
    case recentPlanUnavailable
    case planFileUnreadable(URL)
    case focusedTextUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyManualText:
            return "Manual text is empty."
        case .clipboardUnavailable:
            return "Clipboard is empty or contains non-text content."
        case .selectedTextUnavailable:
            return "No selected text found."
        case .recentPlanUnavailable:
            return "No Claude Code plan files found in ~/.claude/projects/."
        case .planFileUnreadable(let url):
            return "Could not read Claude Code plan file: \(url.lastPathComponent)"
        case .focusedTextUnavailable:
            return "Focused text field content is not available."
        }
    }
}

final class TextSourceService {
    private let clipboardText: () -> String?
    private let selectedText: (@escaping (String?) -> Void) -> Void
    private let recentPlanURL: () -> URL?
    private let readPlan: (URL) -> String?
    private let preprocessPlan: (String) -> String

    init(
        clipboardService: ClipboardService,
        claudeCodeService: ClaudeCodeService
    ) {
        self.clipboardText = { clipboardService.getText() }
        self.selectedText = { completion in
            clipboardService.getSelectedText(completion: completion)
        }
        self.recentPlanURL = { claudeCodeService.findRecentPlan() }
        self.readPlan = { claudeCodeService.readPlan(at: $0) }
        self.preprocessPlan = { claudeCodeService.preprocessForSpeech($0) }
    }

    init(
        clipboardText: @escaping () -> String? = { nil },
        selectedText: @escaping (@escaping (String?) -> Void) -> Void = { completion in completion(nil) },
        recentPlanURL: @escaping () -> URL? = { nil },
        readPlan: @escaping (URL) -> String? = { _ in nil },
        preprocessPlan: @escaping (String) -> String = { $0 }
    ) {
        self.clipboardText = clipboardText
        self.selectedText = selectedText
        self.recentPlanURL = recentPlanURL
        self.readPlan = readPlan
        self.preprocessPlan = preprocessPlan
    }

    func resolve(
        _ request: TextSourceRequest,
        completion: @escaping (Result<TextSourceResult, TextSourceError>) -> Void
    ) {
        switch request {
        case .manualText(let text):
            completion(makeResult(
                text: text,
                source: InteractionSource(kind: .manualText, text: text),
                emptyError: .emptyManualText
            ))
        case .clipboard:
            guard let text = clipboardText() else {
                completion(.failure(.clipboardUnavailable))
                return
            }

            completion(makeResult(
                text: text,
                source: InteractionSource(kind: .clipboard, text: text),
                emptyError: .clipboardUnavailable
            ))
        case .selectedText:
            selectedText { text in
                guard let text else {
                    completion(.failure(.selectedTextUnavailable))
                    return
                }

                completion(self.makeResult(
                    text: text,
                    source: InteractionSource(kind: .selectedText, text: text),
                    emptyError: .selectedTextUnavailable
                ))
            }
        case .recentClaudePlan:
            guard let url = recentPlanURL() else {
                completion(.failure(.recentPlanUnavailable))
                return
            }

            completion(resolvePlanFile(at: url))
        case .claudePlanFile(let url):
            completion(resolvePlanFile(at: url))
        case .focusedTextField:
            completion(.failure(.focusedTextUnavailable))
        }
    }

    private func resolvePlanFile(at url: URL) -> Result<TextSourceResult, TextSourceError> {
        guard let rawText = readPlan(url) else {
            return .failure(.planFileUnreadable(url))
        }

        let processed = preprocessPlan(rawText)
        return makeResult(
            text: processed,
            source: InteractionSource(kind: .file, text: processed, url: url),
            emptyError: .planFileUnreadable(url)
        )
    }

    private func makeResult(
        text: String,
        source: InteractionSource,
        emptyError: TextSourceError
    ) -> Result<TextSourceResult, TextSourceError> {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(emptyError)
        }

        return .success(TextSourceResult(text: text, source: source))
    }
}
