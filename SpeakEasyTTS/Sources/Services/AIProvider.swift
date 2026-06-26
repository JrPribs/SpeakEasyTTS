// AIProvider.swift
// Provider-neutral AI request and response contracts.

import Foundation

protocol AIProvider {
    var id: String { get }
    var displayName: String { get }

    func complete(_ request: AIProviderRequest) async throws -> AIProviderResponse
    func stream(_ request: AIProviderRequest) -> AsyncThrowingStream<AIProviderStreamingEvent, Error>
}

struct AIProviderRequest: Codable, Equatable, Hashable {
    var prompt: String
    var selectedText: String?
    var appContext: AppContext?
    var conversationID: String?
    var metadata: [String: String]

    init(
        prompt: String,
        selectedText: String? = nil,
        appContext: AppContext? = nil,
        conversationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.selectedText = selectedText
        self.appContext = appContext
        self.conversationID = conversationID
        self.metadata = metadata
    }
}

struct AIProviderResponse: Codable, Equatable, Hashable {
    var text: String
    var conversationID: String?
    var modelName: String?
    var finishReason: AIProviderFinishReason?

    init(
        text: String,
        conversationID: String? = nil,
        modelName: String? = nil,
        finishReason: AIProviderFinishReason? = nil
    ) {
        self.text = text
        self.conversationID = conversationID
        self.modelName = modelName
        self.finishReason = finishReason
    }
}

enum AIProviderFinishReason: String, Codable, CaseIterable, Equatable, Hashable {
    case completed
    case lengthLimit
    case cancelled
    case error
}

enum AIProviderStreamingEvent: Codable, Equatable, Hashable {
    case textDelta(String)
    case completed(AIProviderResponse)
    case failed(AIProviderError)
}

enum AIProviderError: Error, Codable, Equatable, Hashable {
    case notConfigured
    case authenticationFailed
    case rateLimited
    case requestFailed(String)
    case invalidResponse(String)
    case streamingUnavailable
    case cancelled
}

extension AIProviderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI provider is not configured."
        case .authenticationFailed:
            return "AI provider authentication failed."
        case .rateLimited:
            return "AI provider rate limit was reached."
        case .requestFailed(let message):
            return message
        case .invalidResponse(let message):
            return message
        case .streamingUnavailable:
            return "AI provider streaming is unavailable."
        case .cancelled:
            return "AI request was cancelled."
        }
    }
}
