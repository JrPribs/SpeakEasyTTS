import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct OverlayInteractionStatusTests {
    @Test
    func responseReadyStateOverridesSelectionAndPlayback() {
        let session = InteractionSession(
            mode: .askAI,
            state: .awaitingUserReview,
            targetApp: AppContext(appName: "Notes"),
            generatedText: "Use this response."
        )

        let status = OverlayInteractionStatus.resolve(
            hasAccessibilityPermissions: true,
            hasSelection: true,
            isAutoReading: false,
            dictationState: .idle,
            triggerState: .inactive,
            playbackState: .playing,
            activeSession: session
        )

        #expect(status.kind == .aiResponseReady)
        #expect(status.title == "Response Ready")
        #expect(status.badgeText == "READY")
        #expect(status.systemImageName == "text.bubble.fill")
    }

    @Test
    func processingAskAIStateIsVisible() {
        let session = InteractionSession(
            mode: .askAI,
            state: .processing,
            transcript: "Explain this error."
        )

        let status = OverlayInteractionStatus.resolve(
            hasAccessibilityPermissions: true,
            hasSelection: false,
            isAutoReading: false,
            dictationState: .idle,
            triggerState: .inactive,
            playbackState: .idle,
            activeSession: session
        )

        #expect(status.kind == .aiProcessing)
        #expect(status.badgeText == "AI")
        #expect(status.helpText == "Cancel AI response")
    }

    @Test
    func latchedDictationStateIsVisibleBeforePlainRecording() {
        let status = OverlayInteractionStatus.resolve(
            hasAccessibilityPermissions: true,
            hasSelection: false,
            isAutoReading: false,
            dictationState: .recording,
            triggerState: .latched,
            playbackState: .idle,
            activeSession: nil
        )

        #expect(status.kind == .latchedDictation)
        #expect(status.badgeText == "PIN")
        #expect(status.helpText == "Stop latched dictation and insert text")
    }

    @Test
    func accessibilityWarningHasHighestPriority() {
        let session = InteractionSession(
            mode: .askAI,
            state: .awaitingUserReview,
            generatedText: "Ready"
        )

        let status = OverlayInteractionStatus.resolve(
            hasAccessibilityPermissions: false,
            hasSelection: true,
            isAutoReading: true,
            dictationState: .recording,
            triggerState: .latched,
            playbackState: .playing,
            activeSession: session
        )

        #expect(status.kind == .noAccess)
        #expect(status.badgeText == "LOCK")
        #expect(status.systemImageName == "lock.fill")
    }
}
