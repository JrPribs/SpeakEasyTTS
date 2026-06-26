import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct TextSourceServiceTests {
    @Test
    func manualTextResolvesWithManualSource() {
        let service = TextSourceService()
        let result = resolveSynchronously(.manualText("Read this"), service: service)

        #expect(result == .success(TextSourceResult(
            text: "Read this",
            source: InteractionSource(kind: .manualText, text: "Read this")
        )))
    }

    @Test
    func emptyManualTextReturnsSourceSpecificError() {
        let service = TextSourceService()
        let result = resolveSynchronously(.manualText("   "), service: service)

        #expect(result == .failure(.emptyManualText))
    }

    @Test
    func clipboardTextResolvesWithClipboardSource() {
        let service = TextSourceService(clipboardText: { "Clipboard text" })
        let result = resolveSynchronously(.clipboard, service: service)

        #expect(result == .success(TextSourceResult(
            text: "Clipboard text",
            source: InteractionSource(kind: .clipboard, text: "Clipboard text")
        )))
    }

    @Test
    func missingClipboardTextReturnsClipboardError() {
        let service = TextSourceService(clipboardText: { nil })
        let result = resolveSynchronously(.clipboard, service: service)

        #expect(result == .failure(.clipboardUnavailable))
    }

    @Test
    func selectedTextResolvesWithSelectedTextSource() {
        let service = TextSourceService(selectedText: { completion in
            completion("Selected text")
        })
        let result = resolveSynchronously(.selectedText, service: service)

        #expect(result == .success(TextSourceResult(
            text: "Selected text",
            source: InteractionSource(kind: .selectedText, text: "Selected text")
        )))
    }

    @Test
    func deferredSelectedTextCompletionStillResolves() {
        var selectedTextCompletion: ((String?) -> Void)?
        let service = TextSourceService(selectedText: { completion in
            selectedTextCompletion = completion
        })

        var resolved: Result<TextSourceResult, TextSourceError>?
        service.resolve(.selectedText) { result in
            resolved = result
        }
        #expect(resolved == nil)

        selectedTextCompletion?("Deferred selection")

        #expect(resolved == .success(TextSourceResult(
            text: "Deferred selection",
            source: InteractionSource(kind: .selectedText, text: "Deferred selection")
        )))
    }

    @Test
    func missingSelectedTextReturnsSelectedTextError() {
        let service = TextSourceService(selectedText: { completion in
            completion(nil)
        })
        let result = resolveSynchronously(.selectedText, service: service)

        #expect(result == .failure(.selectedTextUnavailable))
    }

    @Test
    func whitespaceSelectedTextReturnsSelectedTextError() {
        let service = TextSourceService(selectedText: { completion in
            completion("   ")
        })
        let result = resolveSynchronously(.selectedText, service: service)

        #expect(result == .failure(.selectedTextUnavailable))
    }

    @Test
    func whitespaceClipboardTextReturnsClipboardError() {
        let service = TextSourceService(clipboardText: { "\n\t" })
        let result = resolveSynchronously(.clipboard, service: service)

        #expect(result == .failure(.clipboardUnavailable))
    }

    @Test
    func recentPlanReadsAndPreprocessesPlanText() {
        let url = URL(fileURLWithPath: "/tmp/recent-plan.md")
        let service = TextSourceService(
            recentPlanURL: { url },
            readPlan: { requestedURL in
                requestedURL == url ? "# Plan" : nil
            },
            preprocessPlan: { markdown in
                "Processed \(markdown)"
            }
        )
        let result = resolveSynchronously(.recentClaudePlan, service: service)

        #expect(result == .success(TextSourceResult(
            text: "Processed # Plan",
            source: InteractionSource(kind: .file, text: "Processed # Plan", url: url)
        )))
    }

    @Test
    func pickedPlanFileReadsAndPreprocessesPlanText() {
        let url = URL(fileURLWithPath: "/tmp/picked-plan.md")
        let service = TextSourceService(
            readPlan: { requestedURL in
                requestedURL == url ? "Raw plan" : nil
            },
            preprocessPlan: { markdown in
                "Spoken \(markdown)"
            }
        )
        let result = resolveSynchronously(.claudePlanFile(url), service: service)

        #expect(result == .success(TextSourceResult(
            text: "Spoken Raw plan",
            source: InteractionSource(kind: .file, text: "Spoken Raw plan", url: url)
        )))
    }

    @Test
    func productionPlanReaderUsesReadbackPipelinePlanSummary() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("plan.md")
        try """
        # Plan

        ```swift
        let value = "summarized"
        ```
        """.write(to: url, atomically: true, encoding: .utf8)

        let service = TextSourceService(
            clipboardService: ClipboardService(),
            claudeCodeService: ClaudeCodeService(),
            readbackPipeline: ReadbackPipeline()
        )
        let result = resolveSynchronously(.claudePlanFile(url), service: service)
        let resolved = try result.get()

        #expect(resolved.text.contains("Plan."))
        #expect(resolved.text.contains("Swift code block, 1 line. Symbols: value."))
        #expect(!resolved.text.contains("summarized"))
        #expect(resolved.source == InteractionSource(kind: .file, text: resolved.text, url: url))
    }

    @Test
    func missingRecentPlanReturnsRecentPlanError() {
        let service = TextSourceService(recentPlanURL: { nil })
        let result = resolveSynchronously(.recentClaudePlan, service: service)

        #expect(result == .failure(.recentPlanUnavailable))
    }

    @Test
    func whitespaceProcessedPlanTextReturnsPlanFileError() {
        let url = URL(fileURLWithPath: "/tmp/blank-plan.md")
        let service = TextSourceService(
            readPlan: { _ in "Raw plan" },
            preprocessPlan: { _ in "   " }
        )
        let result = resolveSynchronously(.claudePlanFile(url), service: service)

        #expect(result == .failure(.planFileUnreadable(url)))
    }

    @Test
    func unreadablePlanFileReturnsFileSpecificError() {
        let url = URL(fileURLWithPath: "/tmp/missing-plan.md")
        let service = TextSourceService(readPlan: { _ in nil })
        let result = resolveSynchronously(.claudePlanFile(url), service: service)

        #expect(result == .failure(.planFileUnreadable(url)))
        #expect(TextSourceError.planFileUnreadable(url).localizedDescription.contains("missing-plan.md"))
    }

    @Test
    func focusedTextFieldReturnsUnavailableUntilSupported() {
        let service = TextSourceService()
        let result = resolveSynchronously(.focusedTextField, service: service)

        #expect(result == .failure(.focusedTextUnavailable))
    }

    private func resolveSynchronously(
        _ request: TextSourceRequest,
        service: TextSourceService
    ) -> Result<TextSourceResult, TextSourceError> {
        var resolved: Result<TextSourceResult, TextSourceError>?
        service.resolve(request) { result in
            resolved = result
        }

        return resolved ?? .failure(.focusedTextUnavailable)
    }
}
