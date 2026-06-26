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
    func representativeCodexResponseNormalizesWithoutDroppingCodeBlocks() throws {
        let markdown = try String(contentsOf: try fixtureURL("codex-response.md"), encoding: .utf8)
        let spoken = normalize(markdown)

        #expect(spoken.contains("Implementation Notes."))
        #expect(spoken.contains("Quote: Verified in the local SwiftPM package."))
        #expect(spoken.contains("Section: Changed Files."))
        #expect(spoken.contains("SpeakEasyTTS, Sources, Core, ReadbackPipeline dot swift."))
        #expect(spoken.contains("Completed: Add deterministic normalizer."))
        #expect(spoken.contains("To do: Wire summaries later."))
        #expect(spoken.contains("Step 1: Run swift test."))
        #expect(spoken.contains("Table: Area, Status."))
        #expect(spoken.contains("swift code block omitted."))
        #expect(!spoken.contains("let value"))
    }

    private func normalize(_ text: String) -> String {
        let request = ReadbackRequest(
            source: InteractionSource(kind: .selectedText, text: text),
            text: text,
            profile: .cleanProse
        )

        return ReadbackPipeline().process(request).spokenText
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
