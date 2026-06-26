// InteractionSession.swift
// Models for voice interaction lifecycle state.

import Foundation

enum InteractionMode: String, Codable, CaseIterable, Equatable, Hashable {
    case dictateVerbatim
    case readback
    case askAI
    case transformText

    var displayName: String {
        switch self {
        case .dictateVerbatim:
            return "Dictate"
        case .readback:
            return "Read Back"
        case .askAI:
            return "Ask AI"
        case .transformText:
            return "Transform Text"
        }
    }
}

enum InteractionState: String, Codable, CaseIterable, Equatable, Hashable {
    case idle
    case preparing
    case recording
    case transcribing
    case processing
    case awaitingUserReview
    case inserting
    case reading
    case completed
    case failed
    case cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        case .idle, .preparing, .recording, .transcribing, .processing, .awaitingUserReview, .inserting, .reading:
            return false
        }
    }

    var canCancel: Bool {
        switch self {
        case .preparing, .recording, .transcribing, .processing, .awaitingUserReview, .inserting, .reading:
            return true
        case .idle, .completed, .failed, .cancelled:
            return false
        }
    }
}

struct AppContext: Codable, Equatable, Hashable {
    var bundleIdentifier: String?
    var appName: String
    var processIdentifier: Int32?
    var capturedAt: Date

    init(
        bundleIdentifier: String? = nil,
        appName: String,
        processIdentifier: Int32? = nil,
        capturedAt: Date = Date()
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.processIdentifier = processIdentifier
        self.capturedAt = capturedAt
    }
}

enum InteractionSourceKind: String, Codable, CaseIterable, Equatable, Hashable {
    case none
    case microphone
    case selectedText
    case clipboard
    case focusedTextField
    case manualText
    case file
    case aiResponse
}

struct InteractionSource: Codable, Equatable, Hashable {
    var kind: InteractionSourceKind
    var text: String?
    var url: URL?
    var appContext: AppContext?

    static let none = InteractionSource(kind: .none)

    init(
        kind: InteractionSourceKind,
        text: String? = nil,
        url: URL? = nil,
        appContext: AppContext? = nil
    ) {
        self.kind = kind
        self.text = text
        self.url = url
        self.appContext = appContext
    }
}

enum InteractionDestinationKind: String, Codable, CaseIterable, Equatable, Hashable {
    case none
    case targetApp
    case clipboard
    case reviewPanel
    case speech
}

enum TextWriteMode: String, Codable, CaseIterable, Equatable, Hashable {
    case insert
    case replaceSelection
    case append
}

struct InteractionDestination: Codable, Equatable, Hashable {
    var kind: InteractionDestinationKind
    var appContext: AppContext?
    var writeMode: TextWriteMode?

    static let none = InteractionDestination(kind: .none)
    static let speech = InteractionDestination(kind: .speech)
    static let reviewPanel = InteractionDestination(kind: .reviewPanel)

    init(
        kind: InteractionDestinationKind,
        appContext: AppContext? = nil,
        writeMode: TextWriteMode? = nil
    ) {
        self.kind = kind
        self.appContext = appContext
        self.writeMode = writeMode
    }
}

enum InteractionCancellationReason: String, Codable, CaseIterable, Equatable, Hashable {
    case userRequested
    case superseded
}

struct InteractionCancellation: Codable, Equatable, Hashable {
    var reason: InteractionCancellationReason
    var message: String?
    var discardsPendingText: Bool

    init(
        reason: InteractionCancellationReason,
        message: String? = nil,
        discardsPendingText: Bool = true
    ) {
        self.reason = reason
        self.message = message
        self.discardsPendingText = discardsPendingText
    }
}

struct InteractionFailure: Codable, Equatable, Hashable {
    var reason: InteractionFailureReason
    var message: String
    var recoverySuggestion: String?

    init(
        reason: InteractionFailureReason,
        message: String,
        recoverySuggestion: String? = nil
    ) {
        self.reason = reason
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }
}

enum InteractionFailureReason: String, Codable, CaseIterable, Equatable, Hashable {
    case emptyInput
    case sourceUnavailable
    case destinationUnavailable
    case permissionDenied
    case providerUnavailable
    case serviceError
}

struct InteractionSession: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var mode: InteractionMode
    var state: InteractionState
    var targetApp: AppContext?
    var triggerState: DictationTriggerState
    var source: InteractionSource
    var destination: InteractionDestination
    var transcript: String
    var generatedText: String?
    var failure: InteractionFailure?
    var cancellation: InteractionCancellation?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        mode: InteractionMode,
        state: InteractionState = .idle,
        targetApp: AppContext? = nil,
        triggerState: DictationTriggerState = .inactive,
        source: InteractionSource = .none,
        destination: InteractionDestination = .none,
        transcript: String = "",
        generatedText: String? = nil,
        failure: InteractionFailure? = nil,
        cancellation: InteractionCancellation? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.mode = mode
        self.state = state
        self.targetApp = targetApp
        self.triggerState = triggerState
        self.source = source
        self.destination = destination
        self.transcript = transcript
        self.generatedText = generatedText
        self.failure = failure
        self.cancellation = cancellation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var canCancel: Bool {
        state.canCancel
    }
}
