import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct AIProviderTests {
    @Test
    func requestEncodesPromptSelectedTextAppContextAndConversationID() throws {
        let appContext = AppContext(
            bundleIdentifier: "com.example.Editor",
            appName: "Editor",
            processIdentifier: 123,
            capturedAt: Date(timeIntervalSince1970: 1_000)
        )
        let request = AIProviderRequest(
            prompt: "Summarize this",
            selectedText: "Selected text",
            appContext: appContext,
            conversationID: "conversation-1",
            metadata: ["mode": "summary"]
        )

        let decoded = try roundTrip(request)

        #expect(decoded == request)
        #expect(decoded.prompt == "Summarize this")
        #expect(decoded.selectedText == "Selected text")
        #expect(decoded.appContext == appContext)
        #expect(decoded.conversationID == "conversation-1")
        #expect(decoded.metadata == ["mode": "summary"])
    }

    @Test
    func responseEncodesConversationAndFinishMetadata() throws {
        let response = AIProviderResponse(
            text: "Answer",
            conversationID: "conversation-1",
            modelName: "test-model",
            finishReason: .completed
        )

        let decoded = try roundTrip(response)

        #expect(decoded == response)
    }

    @Test
    func streamingEventsEncodeDeltasCompletionAndFailures() throws {
        let events: [AIProviderStreamingEvent] = [
            .textDelta("Hello"),
            .completed(AIProviderResponse(
                text: "Hello world",
                conversationID: "conversation-1",
                finishReason: .completed
            )),
            .failed(.rateLimited)
        ]

        let decoded = try roundTrip(events)

        #expect(decoded == events)
    }

    @Test
    func providerErrorDescriptionsAreUserReadable() {
        #expect(AIProviderError.notConfigured.localizedDescription == "AI provider is not configured.")
        #expect(AIProviderError.streamingUnavailable.localizedDescription == "AI provider streaming is unavailable.")
        #expect(AIProviderError.requestFailed("Network failed.").localizedDescription == "Network failed.")
    }

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
