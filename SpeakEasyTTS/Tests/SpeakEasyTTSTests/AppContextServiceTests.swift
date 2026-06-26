import Foundation
import AppKit
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

    @Test
    func targetResolutionUsesFocusedExternalApplication() {
        let currentApp = NSRunningApplication.current
        let service = AppContextService(
            frontmostApplication: { currentApp },
            currentBundleIdentifier: { "com.example.SpeakEasyTest" },
            now: { Date(timeIntervalSince1970: 4_003) }
        )

        let resolution = service.resolveTargetApplicationForTextInsertion()

        guard case .focused(let application, let context) = resolution else {
            Issue.record("Expected focused target resolution")
            return
        }

        #expect(ObjectIdentifier(application) == ObjectIdentifier(currentApp))
        #expect(context.processIdentifier == currentApp.processIdentifier)
        #expect(!resolution!.isRecoverableFallback)
    }

    @Test
    func targetResolutionFallsBackToRecoverableLastExternalApplication() {
        let currentApp = NSRunningApplication.current
        var currentBundleIdentifier = "com.example.OtherApp"
        let service = AppContextService(
            frontmostApplication: { currentApp },
            currentBundleIdentifier: { currentBundleIdentifier },
            now: { Date(timeIntervalSince1970: 4_004) }
        )
        service.trackFrontmostApp()

        currentBundleIdentifier = currentApp.bundleIdentifier ?? "com.example.SpeakEasy"
        let resolution = service.resolveTargetApplicationForTextInsertion()

        guard case .recoverable(let application, let context) = resolution else {
            Issue.record("Expected recoverable target resolution")
            return
        }

        #expect(ObjectIdentifier(application) == ObjectIdentifier(currentApp))
        #expect(context.processIdentifier == currentApp.processIdentifier)
        #expect(resolution!.isRecoverableFallback)
    }

    @Test
    func targetResolutionReturnsNilWithoutFocusedOrRecoverableExternalApplication() {
        let currentApp = NSRunningApplication.current
        let service = AppContextService(
            frontmostApplication: { currentApp },
            currentBundleIdentifier: { currentApp.bundleIdentifier },
            now: { Date(timeIntervalSince1970: 4_005) }
        )

        #expect(service.resolveTargetApplicationForTextInsertion() == nil)
    }
}
