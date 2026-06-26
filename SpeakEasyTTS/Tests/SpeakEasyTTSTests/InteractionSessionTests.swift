import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct InteractionSessionTests {
    @Test
    func sessionStatesExposeTerminalAndCancellationSemantics() {
        #expect(!InteractionState.idle.canCancel)
        #expect(InteractionState.recording.canCancel)
        #expect(InteractionState.processing.canCancel)
        #expect(InteractionState.awaitingUserReview.canCancel)
        #expect(InteractionState.reading.canCancel)

        #expect(!InteractionState.recording.isTerminal)
        #expect(InteractionState.completed.isTerminal)
        #expect(InteractionState.failed.isTerminal)
        #expect(InteractionState.cancelled.isTerminal)
    }

    @Test
    func verbatimDictationSessionRepresentsTargetedInsertion() {
        let capturedAt = Date(timeIntervalSince1970: 1_000)
        let targetApp = AppContext(
            bundleIdentifier: "com.apple.TextEdit",
            appName: "TextEdit",
            processIdentifier: 42,
            capturedAt: capturedAt
        )

        let session = InteractionSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            mode: .dictateVerbatim,
            state: .recording,
            targetApp: targetApp,
            triggerState: .holding(canLatch: true, isLatched: false),
            source: InteractionSource(kind: .microphone, appContext: targetApp),
            destination: InteractionDestination(kind: .targetApp, appContext: targetApp, writeMode: .insert),
            transcript: "hello world",
            createdAt: capturedAt,
            updatedAt: capturedAt
        )

        #expect(session.mode == .dictateVerbatim)
        #expect(session.canCancel)
        #expect(session.triggerState == .holding(canLatch: true, isLatched: false))
        #expect(session.source.kind == .microphone)
        #expect(session.destination.kind == .targetApp)
        #expect(session.destination.writeMode == .insert)
        #expect(session.destination.appContext == targetApp)
        #expect(session.transcript == "hello world")
        #expect(session.generatedText == nil)
    }

    @Test
    func readbackSessionRepresentsSelectedTextPlayback() {
        let selectedText = "Read this selected response."
        let sourceApp = AppContext(appName: "Codex")
        let session = InteractionSession(
            mode: .readback,
            state: .reading,
            source: InteractionSource(
                kind: .selectedText,
                text: selectedText,
                appContext: sourceApp
            ),
            destination: .speech
        )

        #expect(session.mode == .readback)
        #expect(session.source.text == selectedText)
        #expect(session.source.appContext == sourceApp)
        #expect(session.destination == .speech)
        #expect(session.canCancel)
    }

    @Test
    func aiTransformSessionCanWaitForUserReviewBeforeInsertion() {
        let targetApp = AppContext(appName: "Mail")
        let session = InteractionSession(
            mode: .transformText,
            state: .awaitingUserReview,
            targetApp: targetApp,
            source: InteractionSource(kind: .selectedText, text: "draft reply", appContext: targetApp),
            destination: InteractionDestination(kind: .targetApp, appContext: targetApp, writeMode: .replaceSelection),
            transcript: "make this friendlier",
            generatedText: "Thanks for the update. I will take a look."
        )

        #expect(session.mode == .transformText)
        #expect(session.state == .awaitingUserReview)
        #expect(session.destination.writeMode == .replaceSelection)
        #expect(session.generatedText != nil)
        #expect(session.canCancel)
    }

    @Test
    func failedAndCancelledSessionsCarryRecoverableContext() {
        let failure = InteractionFailure(
            reason: .permissionDenied,
            message: "Microphone permission is missing.",
            recoverySuggestion: "Open Privacy and Security settings."
        )
        let failedSession = InteractionSession(
            mode: .dictateVerbatim,
            state: .failed,
            failure: failure
        )
        let cancellation = InteractionCancellation(
            reason: .userRequested,
            message: "Stopped before inserting text."
        )
        let cancelledSession = InteractionSession(
            mode: .dictateVerbatim,
            state: .cancelled,
            cancellation: cancellation
        )

        #expect(failedSession.failure == failure)
        #expect(failedSession.state.isTerminal)
        #expect(!failedSession.canCancel)

        #expect(cancelledSession.cancellation == cancellation)
        #expect(cancelledSession.state.isTerminal)
        #expect(!cancelledSession.canCancel)
    }

    @Test
    func sessionModelsRoundTripThroughCodable() throws {
        let session = InteractionSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            mode: .readback,
            state: .processing,
            source: InteractionSource(
                kind: .file,
                url: URL(fileURLWithPath: "/tmp/plan.md")
            ),
            destination: .speech,
            createdAt: Date(timeIntervalSince1970: 2_000),
            updatedAt: Date(timeIntervalSince1970: 2_001)
        )

        let data = try JSONEncoder().encode(session)
        let decodedSession = try JSONDecoder().decode(InteractionSession.self, from: data)

        #expect(decodedSession == session)
    }
}
