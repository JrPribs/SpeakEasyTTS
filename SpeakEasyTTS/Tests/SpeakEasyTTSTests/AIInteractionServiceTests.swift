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
