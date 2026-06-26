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
}
