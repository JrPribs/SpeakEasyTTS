import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct InteractionCoordinatorTests {
    @Test
    func toggleFromIdleStartsDictationInOrder() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness(playbackState: .playing)
        var emittedSessions: [InteractionSession] = []
        coordinator.onSessionChange = { session in
            if let session {
                emittedSessions.append(session)
                harness.events.append("session:\(session.state.rawValue)")
            }
        }

        coordinator.toggleDictation(dependencies: harness.dependencies())

        #expect(harness.events == [
            "trackTargetApp",
            "session:preparing",
            "stopPlayback",
            "startDictation"
        ])
        #expect(emittedSessions.first?.mode == .dictateVerbatim)
        #expect(emittedSessions.first?.targetApp == harness.targetContext)
        #expect(emittedSessions.first?.source.kind == .microphone)
        #expect(emittedSessions.first?.source.appContext == harness.targetContext)
        #expect(emittedSessions.first?.destination.kind == .targetApp)
        #expect(emittedSessions.first?.destination.appContext == harness.targetContext)
        #expect(emittedSessions.first?.destination.writeMode == .insert)
        #expect(coordinator.dictationTranscript == "")
    }

    @Test
    func toggleFromRecordingStopsAndInsertsTranscriptSnapshot() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness()
        var emittedStates: [InteractionState] = []
        coordinator.onSessionChange = { session in
            if let session {
                emittedStates.append(session.state)
                harness.events.append("session:\(session.state.rawValue)")
            }
        }

        coordinator.toggleDictation(dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.handleDictationTranscript(
            "hello",
            isFinal: false,
            dependencies: harness.dependencies()
        )
        coordinator.toggleDictation(dependencies: harness.dependencies())

        #expect(harness.insertedTexts == ["hello"])
        #expect(harness.insertedDestinations.first?.appContext == harness.targetContext)
        #expect(Array(harness.events.suffix(4)) == [
            "session:inserting",
            "stopDictation",
            "insert:hello",
            "session:completed"
        ])
        #expect(emittedStates.contains(.inserting))
        #expect(coordinator.activeSession?.state == .completed)
        #expect(coordinator.activeSession?.transcript == "hello")
        #expect(coordinator.activeSession?.destination.appContext == harness.targetContext)
    }

    @Test
    func naturalFinalTranscriptInsertsOnceAndCompletes() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness()

        coordinator.toggleDictation(dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.handleDictationTranscript(
            "final text",
            isFinal: true,
            dependencies: harness.dependencies()
        )

        #expect(harness.insertedTexts == ["final text"])
        #expect(coordinator.activeSession?.state == .completed)
        #expect(coordinator.activeSession?.transcript == "final text")
    }

    @Test
    func explicitStopThenLateFinalTranscriptDoesNotInsertTwice() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness()

        coordinator.toggleDictation(dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.handleDictationTranscript(
            "hello",
            isFinal: false,
            dependencies: harness.dependencies()
        )
        coordinator.stopDictationAndInsert(dependencies: harness.dependencies())
        coordinator.handleDictationTranscript(
            "hello",
            isFinal: true,
            dependencies: harness.dependencies()
        )

        #expect(harness.insertedTexts == ["hello"])
        #expect(coordinator.activeSession?.state == .completed)
    }

    @Test
    func cancelThenLateFinalTranscriptDoesNotInsertOrComplete() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness()

        coordinator.toggleDictation(dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.handleDictationTranscript(
            "cancel this",
            isFinal: false,
            dependencies: harness.dependencies()
        )
        coordinator.cancelDictation(dependencies: harness.dependencies())
        coordinator.handleDictationTranscript(
            "cancel this",
            isFinal: true,
            dependencies: harness.dependencies()
        )

        #expect(harness.insertedTexts.isEmpty)
        #expect(coordinator.activeSession?.state == .cancelled)
        #expect(coordinator.dictationTranscript == "")
    }

    @Test
    func stopAfterTerminalDictationSessionDoesNotInsertStaleTranscript() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness()

        coordinator.toggleDictation(dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.handleDictationTranscript(
            "stale text",
            isFinal: false,
            dependencies: harness.dependencies()
        )
        coordinator.cancelDictation(dependencies: harness.dependencies())
        coordinator.stopDictationAndInsert(dependencies: harness.dependencies())

        #expect(harness.insertedTexts.isEmpty)
        #expect(coordinator.activeSession?.state == .cancelled)
        #expect(coordinator.dictationState == .idle)
    }

    @Test
    func delayedInsertionCompletionAfterCancellationDoesNotCompleteSession() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness(completesInsertImmediately: false)

        coordinator.toggleDictation(dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.handleDictationTranscript(
            "pending insert",
            isFinal: false,
            dependencies: harness.dependencies()
        )
        coordinator.stopDictationAndInsert(dependencies: harness.dependencies())

        #expect(coordinator.activeSession?.state == .inserting)

        coordinator.cancelDictation(dependencies: harness.dependencies())
        harness.completeNextInsert(didInsert: true)

        #expect(harness.insertedTexts == ["pending insert"])
        #expect(coordinator.activeSession?.state == .cancelled)
        #expect(coordinator.dictationState == .idle)
    }

    @Test
    func dictationErrorClearsRecoverableStateAndAllowsRestart() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness()
        var errorMessages: [String?] = []
        coordinator.onDictationErrorMessageChange = { message in
            errorMessages.append(message)
        }

        coordinator.beginHoldDictation(canLatch: true, dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.handleDictationTranscript(
            "do not keep",
            isFinal: false,
            dependencies: harness.dependencies()
        )
        coordinator.handleDictationError("Microphone failed.")

        #expect(coordinator.activeSession?.state == .failed)
        #expect(coordinator.activeSession?.failure?.reason == .serviceError)
        #expect(coordinator.dictationState == .idle)
        #expect(coordinator.dictationTriggerState == .inactive)
        #expect(coordinator.dictationTranscript == "")
        #expect(errorMessages.contains { $0 == "Microphone failed." })

        coordinator.toggleDictation(dependencies: harness.dependencies())

        #expect(coordinator.activeSession?.state == .preparing)
        #expect(coordinator.activeSession?.failure == nil)
        #expect(errorMessages.last == nil)
    }

    @Test
    func holdLatchPromotesOnReleaseAndStopsOnNextHoldPress() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness()

        coordinator.beginHoldDictation(canLatch: true, dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.handleDictationTranscript(
            "latched text",
            isFinal: false,
            dependencies: harness.dependencies()
        )

        coordinator.latchHoldDictation()
        #expect(coordinator.dictationTriggerState == .holding(canLatch: true, isLatched: true))

        coordinator.latchHoldDictation()
        #expect(coordinator.dictationTriggerState == .holding(canLatch: true, isLatched: false))

        coordinator.latchHoldDictation()
        coordinator.finishHoldDictation(dependencies: harness.dependencies())

        #expect(coordinator.dictationTriggerState == .latched)
        #expect(harness.insertedTexts.isEmpty)
        #expect(coordinator.activeSession?.state == .recording)

        coordinator.beginHoldDictation(canLatch: true, dependencies: harness.dependencies())

        #expect(harness.insertedTexts == ["latched text"])
        #expect(coordinator.activeSession?.state == .completed)
    }

    @Test
    func holdReleaseWhileAuthorizingCancelsWithoutInsertion() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness()

        coordinator.beginHoldDictation(canLatch: false, dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.authorizing)
        coordinator.finishHoldDictation(dependencies: harness.dependencies())

        #expect(harness.insertedTexts.isEmpty)
        #expect(harness.events.contains("stopDictation"))
        #expect(coordinator.activeSession?.state == .cancelled)
        #expect(coordinator.dictationTriggerState == .inactive)
    }

    @Test
    func emptyTranscriptFailsWithoutCallingInsert() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness()
        var errorMessages: [String?] = []
        coordinator.onDictationErrorMessageChange = { message in
            errorMessages.append(message)
        }

        coordinator.toggleDictation(dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.stopDictationAndInsert(dependencies: harness.dependencies())

        #expect(harness.insertedTexts.isEmpty)
        #expect(coordinator.activeSession?.state == .failed)
        #expect(coordinator.activeSession?.failure?.reason == .emptyInput)
        #expect(errorMessages.contains { $0 == "No dictation text captured." })
    }

    @Test
    func insertionFailureEmitsDestinationFailureAndCanStartNewSession() {
        let coordinator = makeCoordinator()
        let harness = DictationHarness(insertResults: [false, true])

        coordinator.toggleDictation(dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.handleDictationTranscript(
            "first",
            isFinal: false,
            dependencies: harness.dependencies()
        )
        coordinator.stopDictationAndInsert(dependencies: harness.dependencies())

        #expect(harness.insertedTexts == ["first"])
        #expect(coordinator.activeSession?.state == .failed)
        #expect(coordinator.activeSession?.failure?.reason == .destinationUnavailable)

        coordinator.handleDictationStateChange(.idle)
        coordinator.toggleDictation(dependencies: harness.dependencies())
        coordinator.handleDictationStateChange(.recording)
        coordinator.handleDictationTranscript(
            "second",
            isFinal: false,
            dependencies: harness.dependencies()
        )
        coordinator.stopDictationAndInsert(dependencies: harness.dependencies())

        #expect(harness.insertedTexts == ["first", "second"])
        #expect(coordinator.activeSession?.state == .completed)
        #expect(coordinator.activeSession?.transcript == "second")
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

        coordinator.beginReadback(
            source: InteractionSource(kind: .manualText, text: "Cancel this"),
            text: "Cancel this"
        ) { _ in }
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

private final class DictationHarness {
    let targetContext = AppContext(
        bundleIdentifier: "com.example.Target",
        appName: "Target",
        processIdentifier: 456,
        capturedAt: Date(timeIntervalSince1970: 3_100)
    )
    var playbackState: PlaybackState
    var events: [String] = []
    var insertedTexts: [String] = []
    var insertedDestinations: [InteractionDestination] = []
    private var insertResults: [Bool]
    private var pendingInsertCompletions: [(Result<InteractionDestination, InteractionCoordinator.TextInsertionFailure>) -> Void] = []
    private let completesInsertImmediately: Bool

    init(
        playbackState: PlaybackState = .idle,
        insertResults: [Bool] = [true],
        completesInsertImmediately: Bool = true
    ) {
        self.playbackState = playbackState
        self.insertResults = insertResults
        self.completesInsertImmediately = completesInsertImmediately
    }

    func dependencies() -> InteractionCoordinator.DictationDependencies {
        InteractionCoordinator.DictationDependencies(
            playbackState: { [self] in
                playbackState
            },
            stopPlayback: { [self] in
                events.append("stopPlayback")
                playbackState = .idle
            },
            trackTargetApp: { [self] in
                events.append("trackTargetApp")
                return targetContext
            },
            startDictation: { [self] in
                events.append("startDictation")
            },
            stopDictation: { [self] in
                events.append("stopDictation")
            },
            insertText: { [self] text, destination, completion in
                events.append("insert:\(text)")
                insertedTexts.append(text)
                insertedDestinations.append(destination)
                let resolvedDestination = InteractionDestination(
                    kind: destination.kind,
                    appContext: targetContext,
                    writeMode: destination.writeMode
                )
                if completesInsertImmediately {
                    if nextInsertResult() {
                        completion(.success(resolvedDestination))
                    } else {
                        completion(.failure(InteractionCoordinator.TextInsertionFailure(
                            message: "Could not insert dictated text. Click into a text field and try again."
                        )))
                    }
                } else {
                    pendingInsertCompletions.append(completion)
                }
            }
        )
    }

    func completeNextInsert(didInsert: Bool) {
        guard !pendingInsertCompletions.isEmpty else { return }

        let completion = pendingInsertCompletions.removeFirst()
        if didInsert {
            completion(.success(InteractionDestination(
                kind: .targetApp,
                appContext: targetContext,
                writeMode: .insert
            )))
        } else {
            completion(.failure(InteractionCoordinator.TextInsertionFailure(
                message: "Could not insert dictated text. Click into a text field and try again."
            )))
        }
    }

    private func nextInsertResult() -> Bool {
        guard !insertResults.isEmpty else { return true }

        return insertResults.removeFirst()
    }
}
