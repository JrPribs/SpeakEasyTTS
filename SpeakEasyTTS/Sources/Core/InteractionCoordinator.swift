// InteractionCoordinator.swift
// Tracks high-level interaction sessions while existing services perform work.

import Foundation

final class InteractionCoordinator {
    private(set) var activeSession: InteractionSession?
    var onSessionChange: ((InteractionSession?) -> Void)?

    private let makeID: () -> UUID
    private let now: () -> Date

    init(
        makeID: @escaping () -> UUID = { UUID() },
        now: @escaping () -> Date = { Date() }
    ) {
        self.makeID = makeID
        self.now = now
    }

    func startDictation(
        triggerState: DictationTriggerState,
        performStart: () -> Void
    ) {
        let date = now()
        emit(InteractionSession(
            id: makeID(),
            mode: .dictateVerbatim,
            state: .preparing,
            triggerState: triggerState,
            source: InteractionSource(kind: .microphone),
            destination: InteractionDestination(kind: .targetApp, writeMode: .insert),
            createdAt: date,
            updatedAt: date
        ))

        performStart()
    }

    func updateDictationState(
        _ dictationState: DictationState,
        triggerState: DictationTriggerState,
        transcript: String
    ) {
        guard activeSession?.mode == .dictateVerbatim,
              activeSession?.state.isTerminal == false else {
            return
        }

        switch dictationState {
        case .idle:
            return
        case .authorizing:
            updateActiveSession { session in
                session.state = .preparing
                session.triggerState = triggerState
                session.transcript = transcript
            }
        case .recording:
            updateActiveSession { session in
                session.state = .recording
                session.triggerState = triggerState
                session.transcript = transcript
            }
        }
    }

    func updateDictationTranscript(_ transcript: String) {
        guard activeSession?.mode == .dictateVerbatim,
              activeSession?.state.isTerminal == false else {
            return
        }

        updateActiveSession { session in
            session.transcript = transcript
        }
    }

    func updateDictationTriggerState(_ triggerState: DictationTriggerState) {
        guard activeSession?.mode == .dictateVerbatim,
              activeSession?.state.isTerminal == false else {
            return
        }

        updateActiveSession { session in
            session.triggerState = triggerState
        }
    }

    func finishDictation(
        transcript: String,
        performStopAndInsert: () -> Void
    ) {
        guard activeSession?.mode == .dictateVerbatim,
              activeSession?.state.isTerminal == false else {
            performStopAndInsert()
            return
        }

        updateActiveSession { session in
            session.state = .inserting
            session.triggerState = .inactive
            session.transcript = transcript
        }

        performStopAndInsert()
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
