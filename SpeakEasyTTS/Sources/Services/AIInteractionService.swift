// AIInteractionService.swift
// Provider-neutral AI hooks for optional interaction summaries.

import Foundation

protocol AIInteractionService {
    func completePrompt(_ request: AIPromptRequest) async throws -> AIPromptResponse
    func summarizeReadback(_ request: AIReadbackSummaryRequest) async throws -> AIReadbackSummaryResponse
}

struct AIPromptRequest: Codable, Equatable, Hashable {
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

struct AIPromptResponse: Codable, Equatable, Hashable {
    var text: String
    var conversationID: String?
    var modelName: String?

    init(
        text: String,
        conversationID: String? = nil,
        modelName: String? = nil
    ) {
        self.text = text
        self.conversationID = conversationID
        self.modelName = modelName
    }
}

struct AIReadbackSummaryRequest: Codable, Equatable, Hashable {
    var readbackRequest: ReadbackRequest
    var deterministicText: String

    init(
        readbackRequest: ReadbackRequest,
        deterministicText: String
    ) {
        self.readbackRequest = readbackRequest
        self.deterministicText = deterministicText
    }
}

struct AIReadbackSummaryResponse: Codable, Equatable, Hashable {
    var summaryText: String

    init(summaryText: String) {
        self.summaryText = summaryText
    }
}

struct AIProviderBackedInteractionService: AIInteractionService {
    private let provider: AIProvider

    init(provider: AIProvider) {
        self.provider = provider
    }

    func completePrompt(_ request: AIPromptRequest) async throws -> AIPromptResponse {
        let response = try await provider.complete(AIProviderRequest(
            prompt: request.prompt,
            selectedText: request.selectedText,
            appContext: request.appContext,
            conversationID: request.conversationID,
            metadata: request.metadata
        ))
        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AIProviderError.invalidResponse("AI provider returned an empty response.")
        }

        return AIPromptResponse(
            text: text,
            conversationID: response.conversationID,
            modelName: response.modelName
        )
    }

    func summarizeReadback(_ request: AIReadbackSummaryRequest) async throws -> AIReadbackSummaryResponse {
        let response = try await completePrompt(AIPromptRequest(
            prompt: "Summarize this text for spoken readback. Preserve tasks, blockers, commands, files, and decisions.",
            selectedText: request.deterministicText,
            appContext: request.readbackRequest.source.appContext,
            metadata: [
                "mode": "readback-summary",
                "profile": request.readbackRequest.profile.rawValue,
                "detailLevel": request.readbackRequest.detailLevel.rawValue
            ]
        ))

        return AIReadbackSummaryResponse(summaryText: response.text)
    }
}
