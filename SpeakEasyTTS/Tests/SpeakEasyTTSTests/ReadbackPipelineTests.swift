import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct ReadbackPipelineTests {
    @Test
    func profilesRepresentReadbackModes() {
        #expect(Set(ReadbackProfile.allCases) == [
            .raw,
            .cleanProse,
            .technicalResponse,
            .planSummary,
            .taskList
        ])
    }

    @Test
    func defaultRequestPreservesExistingReadbackBehavior() {
        let request = ReadbackRequest(
            source: InteractionSource(kind: .selectedText, text: "# Heading"),
            text: "# Heading"
        )

        #expect(request.profile == .raw)
        #expect(request.detailLevel == .standard)
        #expect(request.processingOptions == .preserveInput)
        #expect(ReadbackPipeline().process(request).spokenText == "# Heading")
    }

    @Test
    func profileDefaultsDescribeProcessingBehavior() {
        let expectations: [ReadbackProfile: (ReadbackDetailLevel, ReadbackProcessingOptions)] = [
            .raw: (.standard, .preserveInput),
            .cleanProse: (.standard, ReadbackProcessingOptions(
                normalizeMarkdown: true,
                summarizeCodeBlocks: false,
                preserveTaskStructure: false
            )),
            .technicalResponse: (.standard, ReadbackProcessingOptions(
                normalizeMarkdown: true,
                summarizeCodeBlocks: true,
                preserveTaskStructure: true
            )),
            .planSummary: (.concise, ReadbackProcessingOptions(
                normalizeMarkdown: true,
                summarizeCodeBlocks: true,
                preserveTaskStructure: true
            )),
            .taskList: (.concise, ReadbackProcessingOptions(
                normalizeMarkdown: true,
                summarizeCodeBlocks: false,
                preserveTaskStructure: true
            ))
        ]

        for profile in ReadbackProfile.allCases {
            let expected = expectations[profile]

            #expect(profile.defaultDetailLevel == expected?.0)
            #expect(profile.defaultProcessingOptions == expected?.1)
        }
    }

    @Test
    func requestCanOverrideDetailAndProcessingOptions() {
        let options = ReadbackProcessingOptions(
            normalizeMarkdown: false,
            summarizeCodeBlocks: true,
            preserveTaskStructure: true
        )
        let request = ReadbackRequest(
            source: InteractionSource(kind: .file, text: "Plan"),
            text: "Plan",
            profile: .planSummary,
            detailLevel: .detailed,
            processingOptions: options
        )

        #expect(request.profile == .planSummary)
        #expect(request.detailLevel == .detailed)
        #expect(request.processingOptions == options)
    }

    @Test
    func processingOptionsDoNotRequestAISummaryByDefault() {
        let options = ReadbackProcessingOptions(
            normalizeMarkdown: true,
            summarizeCodeBlocks: true,
            preserveTaskStructure: true
        )

        #expect(!options.requestAISummary)
    }

    @Test
    func pipelineReturnsRequestMetadataWithSpokenText() {
        let request = ReadbackRequest(
            source: InteractionSource(kind: .clipboard, text: "Clipboard text"),
            text: "Clipboard text",
            profile: .cleanProse
        )
        let result = ReadbackPipeline().process(request)

        #expect(result.request == request)
        #expect(result.spokenText == "Clipboard text")
    }

    @Test
    func normalizesMarkdownStructureForSpeech() {
        let markdown = """
        # Title

        ## Overview

        ### Details
        - Bullet with `inlineCode`
        * Second [link](https://example.com)
        1. Run `swift test`
        2) Open Sources/Core/AppState.swift
        - [x] Complete **done**
        - [ ] Pending item
        > quoted *text*
        > and file Sources/Services/TextSourceService.swift

        | File | Status |
        | --- | --- |
        | Sources/Core/AppState.swift | Updated |
        """

        let spoken = normalize(markdown)

        #expect(spoken == """
        Title.

        Section: Overview.

        Sub-section: Details.
        Bullet with inlineCode.
        Second link.
        Step 1: Run swift test.
        Step 2: Open Sources, Core, AppState dot swift.
        Completed: Complete done.
        To do: Pending item.
        Quote: quoted text and file Sources, Services, TextSourceService dot swift.

        Table: File, Status.
        Row 1: Sources, Core, AppState dot swift, Updated.
        """)
    }

    @Test
    func fencedCodeBlocksBecomeSpokenPlaceholders() {
        let markdown = """
        Before.

        ```swift
        let value = "not spoken"
        print(value)
        ```

        ```
        raw block
        ```

        After.
        """

        let spoken = normalize(markdown)

        #expect(spoken == """
        Before.

        swift code block omitted.

        Code block omitted.

        After.
        """)
        #expect(!spoken.contains("not spoken"))
        #expect(!spoken.contains("raw block"))
    }

    @Test
    func fencedCodeBlocksIncludeDeterministicSummaries() {
        let markdown = """
        ```
        $ swift test
        git status --short
        ```

        ```bash
        swift test
        git status --short
        ```

        ```swift
        struct ReadbackPipeline {
            func process() {}
        }
        ```

        ```swift
        extension AppState {
            func toggleDictation() {}
        }
        ```

        ```diff
        diff --git a/Sources/Core/ReadbackPipeline.swift b/Sources/Core/ReadbackPipeline.swift
        --- a/Sources/Core/ReadbackPipeline.swift
        +++ b/Sources/Core/ReadbackPipeline.swift
        @@ -1 +1 @@
        ```

        ```json
        {
          "path": "Sources/Core/AppState.swift",
          "ok": true
        }
        ```

        ```yaml
        path: Sources/Core/AppState.swift
        ```

        ```markdown
        # Plan
        Sources/Core/AppState.swift
        ```
        """

        let spoken = summarize(markdown)

        #expect(spoken.contains("Shell commands block, 2 lines. Commands: swift test, git status."))
        #expect(spoken.contains("Bash shell commands block, 2 lines. Commands: swift test, git status."))
        #expect(spoken.contains("Swift code block, 3 lines. Symbols: ReadbackPipeline, process."))
        #expect(spoken.contains("Swift code block, 3 lines. Symbols: AppState, toggleDictation."))
        #expect(spoken.contains("Diff block, 4 lines. Files: Sources, Core, ReadbackPipeline dot swift."))
        #expect(spoken.contains("JSON block, 4 lines. Files: Sources, Core, AppState dot swift."))
        #expect(spoken.contains("YAML config block, 1 line. Files: Sources, Core, AppState dot swift."))
        #expect(spoken.contains("Markdown block, 2 lines. Files: Sources, Core, AppState dot swift."))
    }

    @Test
    func representativeCodexResponseNormalizesWithoutDroppingCodeBlocks() throws {
        let markdown = try String(contentsOf: try fixtureURL("codex-response.md"), encoding: .utf8)
        let spoken = summarize(markdown)

        #expect(spoken.contains("Implementation Notes."))
        #expect(spoken.contains("Quote: Verified in the local SwiftPM package."))
        #expect(spoken.contains("Section: Changed Files."))
        #expect(spoken.contains("SpeakEasyTTS, Sources, Core, ReadbackPipeline dot swift."))
        #expect(spoken.contains("Completed: Add deterministic normalizer."))
        #expect(spoken.contains("To do: Wire summaries later."))
        #expect(spoken.contains("Step 1: Run swift test."))
        #expect(spoken.contains("Table: Area, Status."))
        #expect(spoken.contains("Swift code block, 2 lines. Symbols: value."))
        #expect(!spoken.contains("let value"))
    }

    @Test
    func optionalAISummaryUsesProviderWhenRequested() async {
        let service = StubAIInteractionService(response: AIReadbackSummaryResponse(summaryText: "AI summary."))
        let request = aiSummaryRequest(text: "# Title\n\nBody")
        let result = await ReadbackPipeline(aiInteractionService: service)
            .processWithOptionalSummary(request)

        #expect(result.spokenText == "AI summary.")
        #expect(service.requests == [
            AIReadbackSummaryRequest(
                readbackRequest: request,
                deterministicText: "Title.\n\nBody."
            )
        ])
    }

    @Test
    func optionalAISummaryDoesNotCallProviderUnlessRequested() async {
        let service = StubAIInteractionService(response: AIReadbackSummaryResponse(summaryText: "AI summary."))
        let request = ReadbackRequest(
            source: InteractionSource(kind: .selectedText, text: "# Title"),
            text: "# Title",
            profile: .technicalResponse
        )
        let result = await ReadbackPipeline(aiInteractionService: service)
            .processWithOptionalSummary(request)

        #expect(result.spokenText == "Title.")
        #expect(service.requests.isEmpty)
    }

    @Test
    func optionalAISummaryFallsBackWithoutProvider() async {
        let request = aiSummaryRequest(text: "# Title")
        let result = await ReadbackPipeline().processWithOptionalSummary(request)

        #expect(result.spokenText == "Title.")
    }

    @Test
    func optionalAISummaryFallsBackWhenProviderFailsOrReturnsEmptyText() async {
        let failingService = StubAIInteractionService(error: StubAIError.unavailable)
        let emptyService = StubAIInteractionService(response: AIReadbackSummaryResponse(summaryText: "   "))
        let request = aiSummaryRequest(text: "# Title")

        let failedResult = await ReadbackPipeline(aiInteractionService: failingService)
            .processWithOptionalSummary(request)
        let emptyResult = await ReadbackPipeline(aiInteractionService: emptyService)
            .processWithOptionalSummary(request)

        #expect(failedResult.spokenText == "Title.")
        #expect(emptyResult.spokenText == "Title.")
    }

    private func normalize(_ text: String) -> String {
        let request = ReadbackRequest(
            source: InteractionSource(kind: .selectedText, text: text),
            text: text,
            profile: .cleanProse
        )

        return ReadbackPipeline().process(request).spokenText
    }

    private func summarize(_ text: String) -> String {
        let request = ReadbackRequest(
            source: InteractionSource(kind: .selectedText, text: text),
            text: text,
            profile: .technicalResponse
        )

        return ReadbackPipeline().process(request).spokenText
    }

    private func aiSummaryRequest(text: String) -> ReadbackRequest {
        ReadbackRequest(
            source: InteractionSource(kind: .selectedText, text: text),
            text: text,
            profile: .technicalResponse,
            processingOptions: ReadbackProcessingOptions(
                normalizeMarkdown: true,
                summarizeCodeBlocks: true,
                preserveTaskStructure: true,
                requestAISummary: true
            )
        )
    }

    private func fixtureURL(_ name: String) throws -> URL {
        let fixture = URL(fileURLWithPath: name)
        let resourceName = fixture.deletingPathExtension().lastPathComponent
        let resourceExtension = fixture.pathExtension.isEmpty ? nil : fixture.pathExtension

        if let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: resourceExtension,
            subdirectory: "Fixtures"
        ) {
            return url
        }

        if let url = Bundle.module.url(forResource: resourceName, withExtension: resourceExtension) {
            return url
        }

        throw FixtureError.missingFixture(name)
    }

    private enum FixtureError: Error {
        case missingFixture(String)
    }
}

private final class StubAIInteractionService: AIInteractionService {
    private(set) var requests: [AIReadbackSummaryRequest] = []
    private let response: AIReadbackSummaryResponse?
    private let error: Error?

    init(
        response: AIReadbackSummaryResponse? = nil,
        error: Error? = nil
    ) {
        self.response = response
        self.error = error
    }

    func summarizeReadback(_ request: AIReadbackSummaryRequest) async throws -> AIReadbackSummaryResponse {
        requests.append(request)

        if let error {
            throw error
        }

        return response ?? AIReadbackSummaryResponse(summaryText: "")
    }
}

private enum StubAIError: Error {
    case unavailable
}
