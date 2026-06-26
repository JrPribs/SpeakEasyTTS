import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct AIInteractionServiceTests {
    @Test
    func askVoicePromptBuildsProviderRequestWithPromptAppContextAndModeMetadata() async throws {
        let provider = StubAIProvider(response: AIProviderResponse(
            text: " Answer ",
            conversationID: "conversation-2",
            modelName: "test-model",
            finishReason: .completed
        ))
        let service = AIProviderBackedInteractionService(provider: provider)
        let appContext = AppContext(
            bundleIdentifier: "com.example.Editor",
            appName: "Editor",
            processIdentifier: 123,
            capturedAt: Date(timeIntervalSince1970: 1_000)
        )

        let response = try await service.completePrompt(AIPromptRequest(
            prompt: "What should I do?",
            selectedText: "Selected text",
            appContext: appContext,
            conversationID: "conversation-1",
            metadata: ["mode": "askAI"]
        ))

        #expect(response == AIPromptResponse(
            text: "Answer",
            conversationID: "conversation-2",
            modelName: "test-model"
        ))
        #expect(provider.requests == [
            AIProviderRequest(
                prompt: "What should I do?",
                selectedText: "Selected text",
                appContext: appContext,
                conversationID: "conversation-1",
                metadata: ["mode": "askAI"]
            )
        ])
    }

    @Test
    func askVoicePromptPropagatesNotConfiguredWithoutFallback() async {
        let provider = StubAIProvider(error: AIProviderError.notConfigured)
        let service = AIProviderBackedInteractionService(provider: provider)

        do {
            _ = try await service.completePrompt(AIPromptRequest(prompt: "Hello"))
            Issue.record("Expected provider error to propagate.")
        } catch let error as AIProviderError {
            #expect(error == .notConfigured)
        } catch {
            Issue.record("Expected AIProviderError.notConfigured, got \(error).")
        }
    }

    @Test
    func askVoicePromptRejectsEmptyProviderResponse() async {
        let provider = StubAIProvider(response: AIProviderResponse(text: "   "))
        let service = AIProviderBackedInteractionService(provider: provider)

        do {
            _ = try await service.completePrompt(AIPromptRequest(prompt: "Hello"))
            Issue.record("Expected empty provider response to throw.")
        } catch let error as AIProviderError {
            #expect(error.localizedDescription == "AI provider returned an empty response.")
        } catch {
            Issue.record("Expected AIProviderError.invalidResponse, got \(error).")
        }
    }

    @Test
    func summarizeReadbackUsesProviderPromptAndMetadata() async throws {
        let provider = StubAIProvider(response: AIProviderResponse(text: "Summary."))
        let service = AIProviderBackedInteractionService(provider: provider)
        let appContext = AppContext(appName: "Editor")
        let readbackRequest = ReadbackRequest(
            source: InteractionSource(kind: .selectedText, text: "Text", appContext: appContext),
            text: "Text",
            profile: .technicalResponse,
            detailLevel: .detailed
        )

        let response = try await service.summarizeReadback(AIReadbackSummaryRequest(
            readbackRequest: readbackRequest,
            deterministicText: "Normalized text."
        ))

        #expect(response == AIReadbackSummaryResponse(summaryText: "Summary."))
        #expect(provider.requests.first?.selectedText == "Normalized text.")
        #expect(provider.requests.first?.appContext == appContext)
        #expect(provider.requests.first?.metadata == [
            "mode": "readback-summary",
            "profile": "technicalResponse",
            "detailLevel": "detailed"
        ])
    }

    @Test
    func askVoicePromptIncludesEnabledConversationHistoryAndPersistsTurn() async throws {
        let harness = try ConversationHarness()
        harness.store.setHistoryEnabled(true)
        harness.store.appendTurn(prompt: "First question", response: "First answer", modelName: "old-model")
        let provider = StubAIProvider(response: AIProviderResponse(
            text: "Follow-up answer.",
            conversationID: "provider-conversation",
            modelName: "new-model"
        ))
        let service = AIProviderBackedInteractionService(
            provider: provider,
            conversationStore: harness.store
        )

        _ = try await service.completePrompt(AIPromptRequest(
            prompt: "Follow up",
            metadata: ["mode": "askAI"]
        ))

        let providerRequest = try #require(provider.requests.first)
        let sessionID = harness.store.loadSession().id.uuidString
        #expect(providerRequest.prompt.contains("Conversation history:"))
        #expect(providerRequest.prompt.contains("User: First question"))
        #expect(providerRequest.prompt.contains("Assistant: First answer"))
        #expect(providerRequest.prompt.contains("Current prompt:\nFollow up"))
        #expect(providerRequest.conversationID == sessionID)

        let turns = harness.store.loadSession().turns
        #expect(turns.map(\.prompt) == ["First question", "Follow up"])
        #expect(turns.last?.response == "Follow-up answer.")
        #expect(turns.last?.modelName == "new-model")
    }

    @Test
    func askVoicePromptDoesNotUseOrAppendHistoryWhenDisabled() async throws {
        let harness = try ConversationHarness()
        harness.store.appendTurn(prompt: "Previous", response: "Previous answer", modelName: nil)
        let provider = StubAIProvider(response: AIProviderResponse(text: "Fresh answer."))
        let service = AIProviderBackedInteractionService(
            provider: provider,
            conversationStore: harness.store
        )

        _ = try await service.completePrompt(AIPromptRequest(
            prompt: "Fresh prompt",
            metadata: ["mode": "askAI"]
        ))

        #expect(provider.requests.first?.prompt == "Fresh prompt")
        #expect(harness.store.loadSession().turns.map(\.prompt) == ["Previous"])
    }

    @Test
    func askVoicePromptReturnsLocalConversationIDWhenProviderDoesNotReturnOne() async throws {
        let harness = try ConversationHarness()
        harness.store.setHistoryEnabled(true)
        let provider = StubAIProvider(response: AIProviderResponse(text: "Answer."))
        let service = AIProviderBackedInteractionService(
            provider: provider,
            conversationStore: harness.store
        )

        let response = try await service.completePrompt(AIPromptRequest(
            prompt: "Question",
            metadata: ["mode": "askAI"]
        ))

        #expect(response.conversationID == harness.store.loadSession().id.uuidString)
    }

    @Test
    func askVoicePromptDoesNotAppendHistoryWhenProviderFails() async throws {
        let harness = try ConversationHarness()
        harness.store.setHistoryEnabled(true)
        let service = AIProviderBackedInteractionService(
            provider: StubAIProvider(error: AIProviderError.rateLimited),
            conversationStore: harness.store
        )

        do {
            _ = try await service.completePrompt(AIPromptRequest(
                prompt: "Question",
                metadata: ["mode": "askAI"]
            ))
            Issue.record("Expected provider error to throw.")
        } catch {
            #expect(harness.store.loadSession().turns.isEmpty)
        }
    }

    @Test
    func askVoicePromptDoesNotAppendHistoryWhenProviderReturnsEmptyResponse() async throws {
        let harness = try ConversationHarness()
        harness.store.setHistoryEnabled(true)
        let service = AIProviderBackedInteractionService(
            provider: StubAIProvider(response: AIProviderResponse(text: "   ")),
            conversationStore: harness.store
        )

        do {
            _ = try await service.completePrompt(AIPromptRequest(
                prompt: "Question",
                metadata: ["mode": "askAI"]
            ))
            Issue.record("Expected empty response to throw.")
        } catch {
            #expect(harness.store.loadSession().turns.isEmpty)
        }
    }

    @Test
    func readbackSummaryDoesNotUseOrAppendConversationHistory() async throws {
        let harness = try ConversationHarness()
        harness.store.setHistoryEnabled(true)
        harness.store.appendTurn(prompt: "Previous", response: "Previous answer", modelName: nil)
        let provider = StubAIProvider(response: AIProviderResponse(text: "Summary."))
        let service = AIProviderBackedInteractionService(
            provider: provider,
            conversationStore: harness.store
        )

        _ = try await service.summarizeReadback(AIReadbackSummaryRequest(
            readbackRequest: ReadbackRequest(
                source: InteractionSource(kind: .aiResponse, text: "Response"),
                text: "Response",
                profile: .technicalResponse
            ),
            deterministicText: "Normalized response."
        ))

        #expect(provider.requests.first?.prompt == "Summarize this text for spoken readback. Preserve tasks, blockers, commands, files, and decisions.")
        #expect(harness.store.loadSession().turns.map(\.prompt) == ["Previous"])
    }
}

private final class StubAIProvider: AIProvider {
    let id = "stub"
    let displayName = "Stub"

    private(set) var requests: [AIProviderRequest] = []
    private let response: AIProviderResponse?
    private let error: Error?

    init(
        response: AIProviderResponse? = nil,
        error: Error? = nil
    ) {
        self.response = response
        self.error = error
    }

    func complete(_ request: AIProviderRequest) async throws -> AIProviderResponse {
        requests.append(request)

        if let error {
            throw error
        }

        return response ?? AIProviderResponse(text: "")
    }

    func stream(_ request: AIProviderRequest) -> AsyncThrowingStream<AIProviderStreamingEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

private final class ConversationHarness {
    let suiteName: String
    let defaults: UserDefaults
    let store: ConversationStore

    init() throws {
        suiteName = "AIInteractionServiceTests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        store = ConversationStore(
            defaults: defaults,
            now: { Date(timeIntervalSince1970: 5_000) },
            makeID: { UUID(uuidString: "00000000-0000-0000-0000-000000000005")! }
        )
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
