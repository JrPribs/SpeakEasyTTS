// InteractionCoordinator.swift
// Tracks high-level interaction sessions while existing services perform work.

import Foundation

final class InteractionCoordinator {
    struct DictationDependencies {
        var playbackState: () -> PlaybackState
        var stopPlayback: () -> Void
        var trackTargetApp: () -> Void
        var startDictation: () -> Void
        var stopDictation: () -> Void
        var insertText: (_ text: String, _ completion: @escaping (Bool) -> Void) -> Void
    }

    private(set) var activeSession: InteractionSession?
    private(set) var dictationState: DictationState = .idle
    private(set) var dictationTriggerState: DictationTriggerState = .inactive
    private(set) var dictationTranscript: String = ""

    var onSessionChange: ((InteractionSession?) -> Void)?
    var onDictationStateChange: ((DictationState) -> Void)?
    var onDictationTriggerStateChange: ((DictationTriggerState) -> Void)?
    var onDictationTranscriptChange: ((String) -> Void)?
    var onDictationErrorMessageChange: ((String?) -> Void)?

    private let makeID: () -> UUID
    private let now: () -> Date
    private var hasInsertedCurrentDictation = false

    init(
        makeID: @escaping () -> UUID = { UUID() },
        now: @escaping () -> Date = { Date() }
    ) {
        self.makeID = makeID
        self.now = now
    }

    /// Toggle native speech-to-text dictation. Completed text is pasted into the last focused app.
    func toggleDictation(dependencies: DictationDependencies) {
        setDictationTriggerState(.inactive, syncSession: false)

        switch dictationState {
        case .idle:
            startDictation(dependencies: dependencies)
        case .authorizing, .recording:
            stopDictationAndInsert(dependencies: dependencies)
        }
    }

    /// Start verbatim dictation without AI rewriting or cleanup.
    func startDictation(dependencies: DictationDependencies) {
        guard dictationState == .idle else { return }

        setDictationTranscript("")
        hasInsertedCurrentDictation = false
        setDictationErrorMessage(nil)

        let date = now()
        emit(InteractionSession(
            id: makeID(),
            mode: .dictateVerbatim,
            state: .preparing,
            triggerState: dictationTriggerState,
            source: InteractionSource(kind: .microphone),
            destination: InteractionDestination(kind: .targetApp, writeMode: .insert),
            createdAt: date,
            updatedAt: date
        ))

        if dependencies.playbackState() != .idle {
            dependencies.stopPlayback()
        }

        dependencies.trackTargetApp()
        dependencies.startDictation()
    }

    /// Stop dictation and insert the captured transcript into the focused app.
    func stopDictationAndInsert(dependencies: DictationDependencies) {
        let textToInsert = dictationTranscript
        setDictationTriggerState(.inactive, syncSession: false)

        guard activeSession?.mode == .dictateVerbatim,
              activeSession?.state.isTerminal == false else {
            dependencies.stopDictation()
            insertDictatedText(textToInsert, dependencies: dependencies)
            return
        }

        updateActiveSession { session in
            session.state = .inserting
            session.triggerState = .inactive
            session.transcript = textToInsert
        }

        dependencies.stopDictation()
        insertDictatedText(textToInsert, dependencies: dependencies)
    }

    func beginHoldDictation(canLatch: Bool, dependencies: DictationDependencies) {
        if dictationTriggerState == .latched {
            stopDictationAndInsert(dependencies: dependencies)
            return
        }

        guard dictationState == .idle else { return }

        setDictationTriggerState(.holding(canLatch: canLatch, isLatched: false))
        startDictation(dependencies: dependencies)
    }

    func latchHoldDictation() {
        guard dictationState != .idle else { return }

        if case .holding(true, let isLatched) = dictationTriggerState {
            setDictationTriggerState(.holding(canLatch: true, isLatched: !isLatched))
        }
    }

    /// Finish a hold-to-record session. If release happens during authorization, cancel without inserting.
    func finishHoldDictation(dependencies: DictationDependencies) {
        if case .latched = dictationTriggerState {
            return
        }

        if case .holding(_, true) = dictationTriggerState {
            setDictationTriggerState(.latched)
            return
        }

        guard case .holding = dictationTriggerState else { return }
        setDictationTriggerState(.inactive, syncSession: false)

        switch dictationState {
        case .recording:
            stopDictationAndInsert(dependencies: dependencies)
        case .authorizing:
            cancelDictation(dependencies: dependencies)
        case .idle:
            break
        }
    }

    /// Stop dictation without inserting text.
    func cancelDictation(dependencies: DictationDependencies) {
        setDictationTriggerState(.inactive, syncSession: false)
        cancelActiveSession(
            message: "Dictation cancelled.",
            performCancel: {
                dependencies.stopDictation()
            }
        )
        setDictationTranscript("")
        hasInsertedCurrentDictation = false
    }

    func handleDictationStateChange(_ state: DictationState) {
        setDictationState(state)

        guard activeSession?.mode == .dictateVerbatim,
              activeSession?.state.isTerminal == false else {
            return
        }

        switch state {
        case .idle:
            return
        case .authorizing:
            updateActiveSession { session in
                session.state = .preparing
                session.triggerState = dictationTriggerState
                session.transcript = dictationTranscript
            }
        case .recording:
            updateActiveSession { session in
                session.state = .recording
                session.triggerState = dictationTriggerState
                session.transcript = dictationTranscript
            }
        }
    }

    func handleDictationTranscript(
        _ transcript: String,
        isFinal: Bool,
        dependencies: DictationDependencies
    ) {
        guard activeSession?.mode == .dictateVerbatim,
              activeSession?.state.isTerminal == false else {
            return
        }

        setDictationTranscript(transcript)

        if isFinal {
            insertDictatedText(transcript, dependencies: dependencies)
        }
    }

    func handleDictationError(_ message: String) {
        setDictationErrorMessage(message)
        setDictationState(.idle)
        setDictationTriggerState(.inactive)
        failActiveSession(
            reason: .serviceError,
            message: message
        )
    }

    func beginReadback(
        source: InteractionSource,
        text: String,
        performReadback: (String) -> Void
    ) {
        let date = now()
        emit(InteractionSession(
            id: makeID(),
            mode: .readback,
            state: .preparing,
            source: source,
            destination: .speech,
            generatedText: text,
            createdAt: date,
            updatedAt: date
        ))

        performReadback(text)

        if activeSession?.mode == .readback,
           activeSession?.state == .preparing {
            updateActiveSession { session in
                session.state = .reading
            }
        }
    }

    func updatePlaybackState(_ playbackState: PlaybackState) {
        guard activeSession?.mode == .readback,
              activeSession?.state.isTerminal == false else {
            return
        }

        switch playbackState {
        case .idle:
            if activeSession?.state == .reading {
                completeActiveSession()
            }
        case .playing, .paused:
            updateActiveSession { session in
                session.state = .reading
            }
        }
    }

    func cancelActiveSession(
        reason: InteractionCancellationReason = .userRequested,
        message: String? = nil,
        discardsPendingText: Bool = true,
        performCancel: () -> Void
    ) {
        guard activeSession?.state.isTerminal == false else {
            performCancel()
            return
        }

        updateActiveSession { session in
            session.state = .cancelled
            session.triggerState = .inactive
            session.cancellation = InteractionCancellation(
                reason: reason,
                message: message,
                discardsPendingText: discardsPendingText
            )
        }

        performCancel()
    }

    func failActiveSession(
        reason: InteractionFailureReason,
        message: String,
        recoverySuggestion: String? = nil
    ) {
        guard activeSession?.state.isTerminal == false else { return }

        updateActiveSession { session in
            session.state = .failed
            session.triggerState = .inactive
            session.failure = InteractionFailure(
                reason: reason,
                message: message,
                recoverySuggestion: recoverySuggestion
            )
        }
    }

    func completeActiveSession(
        transcript: String? = nil,
        generatedText: String? = nil
    ) {
        guard activeSession?.state.isTerminal == false else { return }

        updateActiveSession { session in
            session.state = .completed
            session.triggerState = .inactive
            if let transcript {
                session.transcript = transcript
            }
            if let generatedText {
                session.generatedText = generatedText
            }
        }
    }

    private func insertDictatedText(
        _ text: String,
        dependencies: DictationDependencies
    ) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            let message = "No dictation text captured."
            setDictationErrorMessage(message)
            failActiveSession(
                reason: .emptyInput,
                message: message
            )
            return
        }

        guard !hasInsertedCurrentDictation else { return }

        hasInsertedCurrentDictation = true
        dependencies.insertText(normalized) { [weak self] didInsert in
            guard let self else { return }

            if didInsert {
                self.setDictationTranscript(normalized)
                self.completeActiveSession(transcript: normalized)
            } else {
                let message = "Could not insert dictated text. Click into a text field and try again."
                self.setDictationErrorMessage(message)
                self.hasInsertedCurrentDictation = false
                self.failActiveSession(
                    reason: .destinationUnavailable,
                    message: message
                )
            }
        }
    }

    private func setDictationState(_ state: DictationState) {
        guard dictationState != state else { return }

        dictationState = state
        onDictationStateChange?(state)
    }

    private func setDictationTriggerState(
        _ triggerState: DictationTriggerState,
        syncSession: Bool = true
    ) {
        guard dictationTriggerState != triggerState else { return }

        dictationTriggerState = triggerState
        onDictationTriggerStateChange?(triggerState)

        if syncSession {
            updateActiveDictationSession { session in
                session.triggerState = triggerState
            }
        }
    }

    private func setDictationTranscript(_ transcript: String) {
        guard dictationTranscript != transcript else { return }

        dictationTranscript = transcript
        onDictationTranscriptChange?(transcript)
        updateActiveDictationSession { session in
            session.transcript = transcript
        }
    }

    private func setDictationErrorMessage(_ message: String?) {
        onDictationErrorMessageChange?(message)
    }

    private func updateActiveDictationSession(_ update: (inout InteractionSession) -> Void) {
        guard activeSession?.mode == .dictateVerbatim,
              activeSession?.state.isTerminal == false else {
            return
        }

        updateActiveSession(update)
    }

    private func updateActiveSession(_ update: (inout InteractionSession) -> Void) {
        guard var session = activeSession else { return }

        update(&session)
        session.updatedAt = now()
        emit(session)
    }

    private func emit(_ session: InteractionSession?) {
        activeSession = session
        onSessionChange?(session)
    }
}
