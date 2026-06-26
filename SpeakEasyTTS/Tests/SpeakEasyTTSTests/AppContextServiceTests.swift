import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct AppContextServiceTests {
    @Test
    func makeContextPreservesApplicationMetadata() {
        let capturedAt = Date(timeIntervalSince1970: 4_000)

        let context = AppContextService.makeContext(
            bundleIdentifier: "com.apple.TextEdit",
            localizedName: "TextEdit",
            processIdentifier: 42,
            capturedAt: capturedAt
        )

        #expect(context.bundleIdentifier == "com.apple.TextEdit")
        #expect(context.appName == "TextEdit")
        #expect(context.processIdentifier == 42)
        #expect(context.capturedAt == capturedAt)
    }

    @Test
    func makeContextFallsBackToBundleIdentifierForMissingName() {
        let context = AppContextService.makeContext(
            bundleIdentifier: "com.example.Editor",
            localizedName: nil,
            processIdentifier: nil,
            capturedAt: Date(timeIntervalSince1970: 4_001)
        )

        #expect(context.appName == "com.example.Editor")
        #expect(context.bundleIdentifier == "com.example.Editor")
        #expect(context.processIdentifier == nil)
    }

    @Test
    func makeContextLabelsMissingMetadataAsUnknownApp() {
        let context = AppContextService.makeContext(
            bundleIdentifier: nil,
            localizedName: nil,
            processIdentifier: nil,
            capturedAt: Date(timeIntervalSince1970: 4_002)
        )

        #expect(context.appName == "Unknown App")
        #expect(context.bundleIdentifier == nil)
        #expect(context.processIdentifier == nil)
    }
}
