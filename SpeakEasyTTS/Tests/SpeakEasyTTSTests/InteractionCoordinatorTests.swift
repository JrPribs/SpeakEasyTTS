import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct InteractionCoordinatorTests {
    @Test
    func dictationSessionEmitsPreparingRecordingInsertingAndCompletedStates() {
        let coordinator = makeCoordinator()
        var emittedSessions: [InteractionSession] = []
        var didStart = false
        var didStop = false
        coordinator.onSessionChange = { session in
            if let session {
                emittedSessions.append(session)
            }
        }

        coordinator.startDictation(triggerState: .holding(canLatch: true, isLatched: false)) {
            didStart = true
        }
        coordinator.updateDictationState(
            .recording,
            triggerState: .holding(canLatch: true, isLatched: false),
            transcript: "hello"
        )
        coordinator.finishDictation(transcript: "hello") {
            didStop = true
        }
        coordinator.completeActiveSession(transcript: "hello")

        #expect(didStart)
        #expect(didStop)
        #expect(emittedSessions.map(\.state) == [.preparing, .recording, .inserting, .completed])
        #expect(emittedSessions.last?.mode == .dictateVerbatim)
        #expect(emittedSessions.last?.source.kind == .microphone)
        #expect(emittedSessions.last?.destination.kind == .targetApp)
        #expect(emittedSessions.last?.destination.writeMode == .insert)
        #expect(emittedSessions.last?.transcript == "hello")
    }

    @Test
    func readbackSessionDelegatesSpeechAndCompletesWhenPlaybackReturnsIdle() {
        let coordinator = makeCoordinator()
        var emittedStates: [InteractionState] = []
        var spokenText: String?
        coordinator.onSessionChange = { session in
            if let session {
                emittedStates.append(session.state)
            }
        }

        coordinator.beginReadback(
            source: InteractionSource(kind: .selectedText, text: "Selected response"),
            text: "Selected response"
        ) { text in
            spokenText = text
        }
        coordinator.updatePlaybackState(.playing)
        coordinator.updatePlaybackState(.idle)

        #expect(spokenText == "Selected response")
        #expect(emittedStates == [.preparing, .reading, .reading, .completed])
        #expect(coordinator.activeSession?.mode == .readback)
        #expect(coordinator.activeSession?.source.kind == .selectedText)
        #expect(coordinator.activeSession?.destination == .speech)
    }

    @Test
    func cancellingActiveSessionDelegatesCleanupAndEmitsCancelledState() {
        let coordinator = makeCoordinator()
        var didCancel = false

        coordinator.startDictation(triggerState: .inactive) {}
        coordinator.cancelActiveSession(message: "Cancelled by user.") {
            didCancel = true
        }

        #expect(didCancel)
        #expect(coordinator.activeSession?.state == .cancelled)
        #expect(coordinator.activeSession?.cancellation?.reason == .userRequested)
        #expect(coordinator.activeSession?.cancellation?.message == "Cancelled by user.")
        #expect(coordinator.activeSession?.triggerState == .inactive)
    }

    @Test
    func cancellationWinsOverSynchronousCleanupCallbacks() {
        let coordinator = makeCoordinator()

        coordinator.beginReadback(
            source: InteractionSource(kind: .manualText, text: "Stop this"),
            text: "Stop this"
        ) { _ in }
        coordinator.cancelActiveSession(message: "Speech stopped.") {
            coordinator.updatePlaybackState(.idle)
        }

        #expect(coordinator.activeSession?.state == .cancelled)
        #expect(coordinator.activeSession?.cancellation?.message == "Speech stopped.")
    }

    @Test
    func dictationTriggerStateCanUpdateWithoutTranscriptChange() {
        let coordinator = makeCoordinator()

        coordinator.startDictation(triggerState: .holding(canLatch: true, isLatched: false)) {}
        coordinator.updateDictationState(
            .recording,
            triggerState: .holding(canLatch: true, isLatched: false),
            transcript: ""
        )
        coordinator.updateDictationTriggerState(.holding(canLatch: true, isLatched: true))
        coordinator.updateDictationTriggerState(.latched)

        #expect(coordinator.activeSession?.state == .recording)
        #expect(coordinator.activeSession?.triggerState == .latched)
    }

    @Test
    func failingActiveSessionEmitsFailureContext() {
        let coordinator = makeCoordinator()

        coordinator.beginReadback(
            source: InteractionSource(kind: .clipboard, text: "Clipboard text"),
            text: "Clipboard text"
        ) { _ in }
        coordinator.failActiveSession(
            reason: .serviceError,
            message: "Speech service failed.",
            recoverySuggestion: "Try another voice."
        )

        #expect(coordinator.activeSession?.state == .failed)
        #expect(coordinator.activeSession?.failure?.reason == .serviceError)
        #expect(coordinator.activeSession?.failure?.message == "Speech service failed.")
        #expect(coordinator.activeSession?.failure?.recoverySuggestion == "Try another voice.")
    }

    private func makeCoordinator() -> InteractionCoordinator {
        InteractionCoordinator(
            makeID: { UUID(uuidString: "00000000-0000-0000-0000-000000000003")! },
            now: { Date(timeIntervalSince1970: 3_000) }
        )
    }
}
