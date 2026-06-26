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
    private let conversationStore: ConversationStore?

    init(
        provider: AIProvider,
        conversationStore: ConversationStore? = nil
    ) {
        self.provider = provider
        self.conversationStore = conversationStore
    }

    func completePrompt(_ request: AIPromptRequest) async throws -> AIPromptResponse {
        let useHistory = shouldUseConversationHistory(for: request)
        let session = useHistory ? conversationStore?.loadSession() : nil
        AppLog.ai.info("AI prompt requested; mode=\(request.metadata["mode"] ?? "unknown"), history=\(useHistory)")
        let response = try await provider.complete(AIProviderRequest(
            prompt: promptText(for: request, history: session?.turns ?? []),
            selectedText: request.selectedText,
            appContext: request.appContext,
            conversationID: request.conversationID ?? session?.id.uuidString,
            metadata: request.metadata
        ))
        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            AppLog.ai.error("AI provider returned empty response")
            throw AIProviderError.invalidResponse("AI provider returned an empty response.")
        }

        if useHistory {
            conversationStore?.appendTurn(
                prompt: request.prompt,
                response: text,
                modelName: response.modelName,
                to: session
            )
        }

        AppLog.ai.info("AI prompt completed; responseCharacters=\(text.count), model=\(response.modelName ?? "unknown")")
        return AIPromptResponse(
            text: text,
            conversationID: response.conversationID ?? session?.id.uuidString,
            modelName: response.modelName
        )
    }

    func summarizeReadback(_ request: AIReadbackSummaryRequest) async throws -> AIReadbackSummaryResponse {
        AppLog.ai.info("AI readback summary requested; deterministicCharacters=\(request.deterministicText.count)")
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

    private func shouldUseConversationHistory(for request: AIPromptRequest) -> Bool {
        request.metadata["mode"] == InteractionMode.askAI.rawValue
            && conversationStore?.isHistoryEnabled() == true
    }

    private func promptText(for request: AIPromptRequest, history: [ConversationTurn]) -> String {
        guard !history.isEmpty else {
            return request.prompt
        }

        let turns = history.map { turn in
            """
            User: \(turn.prompt)
            Assistant: \(turn.response)
            """
        }.joined(separator: "\n\n")

        return """
        Conversation history:
        \(turns)

        Current prompt:
        \(request.prompt)
        """
    }
}
