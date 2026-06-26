import Testing
@testable import SpeakEasyTTS

@Suite
struct ReadbackProcessorTests {
    private let processor = ReadbackProcessor()

    @Test
    func convertsHeadingsToSpeechFriendlyLabels() {
        let markdown = """
        # Title
        ## Overview
        ### Details
        #### Deep Dive
        """

        let processed = processor.preprocessForSpeech(markdown)

        #expect(processed == """
        Title.

        Section: Overview.

        Sub-section: Details.

        Sub-section: Deep Dive.
        """)
    }

    @Test
    func convertsConsecutiveBulletsToSentences() {
        let markdown = """
        - First item
        - Second item
        - Third item

        * Single item
        """

        let processed = processor.preprocessForSpeech(markdown)

        #expect(processed == """
        First item, Second item, and Third item.

        Single item.
        """)
    }

    @Test
    func removesInlineFormattingMarkers() {
        let markdown = "Use **bold text**, *italic text*, and `inlineCode`."

        let processed = processor.preprocessForSpeech(markdown)

        #expect(processed == "Use bold text, italic text, and inlineCode.")
    }

    @Test
    func convertsFilePathsToSpokenForm() {
        let markdown = "Read Sources/Core/AppState.swift before src/auth/login.ts."

        let processed = processor.preprocessForSpeech(markdown)

        #expect(processed == "Read Sources, Core, AppState dot swift before src, auth, login dot ts.")
    }

    @Test
    func removesFencedCodeBlocks() {
        let markdown = """
        Before code.
        ```swift
        let value = "not spoken"
        print(value)
        ```
        After code.

        ```
        raw block
        ```
        Done.
        """

        let processed = processor.preprocessForSpeech(markdown)

        #expect(processed == """
        Before code.

        After code.

        Done.
        """)
    }

    @Test
    func processesRepresentativeMarkdownSample() {
        let source = """
        # Launch Plan

        Intro uses **bold text**, *italic notes*, and `inlineCode`.

        ## Files
        Read Sources/Core/AppState.swift before Sources/Services/ClaudeCodeService.swift.

        ### Tasks
        - Keep behavior
        - Add tests
        - Avoid rewrites

        #### Detail
        * One bullet

        ```swift
        let value = "do not speak"
        print(value)
        ```

        After code fence.

        ```
        plain block should also be removed
        ```

        Done.
        """

        let processed = processor.preprocessForSpeech(source)

        #expect(processed == """
        Launch Plan.

        Intro uses bold text, italic notes, and inlineCode.

        Section: Files.
        Read Sources, Core, AppState dot swift before Sources, Services, ClaudeCodeService dot swift.

        Sub-section: Tasks.
        Keep behavior, Add tests, and Avoid rewrites.

        Sub-section: Detail.
        One bullet.

        After code fence.

        Done.
        """)
    }
}
