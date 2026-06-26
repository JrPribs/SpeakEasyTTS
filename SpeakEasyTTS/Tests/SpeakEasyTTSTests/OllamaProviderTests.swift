import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct OllamaProviderTests {
    @Test
    func completeBuildsChatRequestAndParsesResponse() async throws {
        let transport = MockOllamaTransport(response: .success(OllamaHTTPResponse(
            statusCode: 200,
            data: Data("""
            {
              "model": "test-model",
              "message": {
                "role": "assistant",
                "content": "Here is the answer."
              },
              "done": true,
              "done_reason": "stop"
            }
            """.utf8)
        )))
        let provider = OllamaProvider(
            configuration: OllamaProviderConfiguration(
                baseURL: URL(string: "http://localhost:11434")!,
                model: "test-model"
            ),
            transport: transport
        )
        let appContext = AppContext(
            bundleIdentifier: "com.example.Editor",
            appName: "Editor",
            processIdentifier: 123,
            capturedAt: Date(timeIntervalSince1970: 1_000)
        )

        let response = try await provider.complete(AIProviderRequest(
            prompt: "Summarize this",
            selectedText: "Selected text",
            appContext: appContext,
            conversationID: "conversation-1",
            metadata: ["mode": "summary", "tone": "direct"]
        ))

        #expect(response == AIProviderResponse(
            text: "Here is the answer.",
            conversationID: "conversation-1",
            modelName: "test-model",
            finishReason: .completed
        ))

        let request = try #require(transport.sentRequests.first)
        #expect(request.url?.absoluteString == "http://localhost:11434/api/chat")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

        let body = try requestBody(from: request)
        #expect(body["model"] as? String == "test-model")
        #expect(body["stream"] as? Bool == false)

        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.count == 2)
        #expect(messages.first?["role"] as? String == "system")
        #expect(messages.last?["role"] as? String == "user")

        let userContent = try #require(messages.last?["content"] as? String)
        #expect(userContent.contains("Prompt:\nSummarize this"))
        #expect(userContent.contains("Selected text:\nSelected text"))
        #expect(userContent.contains("App context:\nApp: Editor"))
        #expect(userContent.contains("Bundle ID: com.example.Editor"))
        #expect(userContent.contains("Process ID: 123"))
        #expect(userContent.contains("Conversation ID:\nconversation-1"))
        #expect(userContent.contains("mode: summary"))
        #expect(userContent.contains("tone: direct"))
    }

    @Test
    func completeAddsBearerTokenWhenCredentialIsConfigured() async throws {
        let transport = MockOllamaTransport(response: .success(OllamaHTTPResponse(
            statusCode: 200,
            data: Data("""
            {
              "model": "test-model",
              "message": {
                "role": "assistant",
                "content": "Authenticated response."
              },
              "done": true
            }
            """.utf8)
        )))
        let provider = OllamaProvider(
            configuration: OllamaProviderConfiguration(
                baseURL: URL(string: "http://localhost:11434")!,
                model: "test-model",
                requiresAuthentication: true
            ),
            transport: transport,
            credentialProvider: { "test-token" }
        )

        _ = try await provider.complete(AIProviderRequest(prompt: "Hello"))

        #expect(transport.sentRequests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    @Test
    func baseURLWithTrailingSlashBuildsSingleChatEndpointAndPreservesTaggedModel() async throws {
        let transport = MockOllamaTransport(response: .success(OllamaHTTPResponse(
            statusCode: 200,
            data: Data("""
            {
              "model": "llama3.2:latest",
              "message": {
                "role": "assistant",
                "content": "Ready."
              },
              "done": true
            }
            """.utf8)
        )))
        let provider = OllamaProvider(
            configuration: OllamaProviderConfiguration(
                baseURL: URL(string: "http://localhost:11434/")!,
                model: "llama3.2:latest"
            ),
            transport: transport
        )

        _ = try await provider.complete(AIProviderRequest(prompt: "Hello"))

        let request = try #require(transport.sentRequests.first)
        let body = try requestBody(from: request)
        #expect(request.url?.absoluteString == "http://localhost:11434/api/chat")
        #expect(body["model"] as? String == "llama3.2:latest")
    }

    @Test
    func missingCredentialThrowsNotConfiguredAndDoesNotCallTransport() async {
        let transport = MockOllamaTransport(response: .success(OllamaHTTPResponse(
            statusCode: 200,
            data: Data()
        )))
        let provider = OllamaProvider(
            configuration: OllamaProviderConfiguration(
                baseURL: URL(string: "http://localhost:11434")!,
                model: "test-model",
                requiresAuthentication: true
            ),
            transport: transport,
            credentialProvider: { nil }
        )

        do {
            _ = try await provider.complete(AIProviderRequest(prompt: "Hello"))
            Issue.record("Expected missing credentials to throw.")
        } catch let error as AIProviderError {
            #expect(error == .notConfigured)
        } catch {
            Issue.record("Expected AIProviderError.notConfigured, got \(error).")
        }

        #expect(transport.sentRequests.isEmpty)
    }

    @Test
    func httpErrorsMapToUserVisibleProviderErrors() async {
        let transport = MockOllamaTransport(response: .success(OllamaHTTPResponse(
            statusCode: 500,
            data: Data(#"{"error":"model is not available"}"#.utf8)
        )))
        let provider = OllamaProvider(
            configuration: OllamaProviderConfiguration(model: "test-model"),
            transport: transport
        )

        do {
            _ = try await provider.complete(AIProviderRequest(prompt: "Hello"))
            Issue.record("Expected failed HTTP response to throw.")
        } catch let error as AIProviderError {
            #expect(error.localizedDescription == "Ollama request failed (500): model is not available")
        } catch {
            Issue.record("Expected AIProviderError.requestFailed, got \(error).")
        }
    }

    @Test
    func invalidSuccessfulResponseThrowsUserVisibleProviderError() async {
        let transport = MockOllamaTransport(response: .success(OllamaHTTPResponse(
            statusCode: 200,
            data: Data(#"{"model":"test-model","done":true}"#.utf8)
        )))
        let provider = OllamaProvider(
            configuration: OllamaProviderConfiguration(model: "test-model"),
            transport: transport
        )

        do {
            _ = try await provider.complete(AIProviderRequest(prompt: "Hello"))
            Issue.record("Expected invalid response to throw.")
        } catch let error as AIProviderError {
            #expect(error.localizedDescription == "Ollama response did not include assistant text.")
        } catch {
            Issue.record("Expected AIProviderError.invalidResponse, got \(error).")
        }
    }

    @Test
    func streamBuildsStreamingRequestAndEmitsDeltasAndCompletion() async throws {
        let transport = MockOllamaTransport(
            response: .success(OllamaHTTPResponse(statusCode: 200, data: Data())),
            streamEvents: [
                .responseStatus(200),
                .line(#"{"model":"test-model","message":{"role":"assistant","content":"Hel"},"done":false}"#),
                .line(#"{"model":"test-model","message":{"role":"assistant","content":"lo"},"done":false}"#),
                .line(#"{"model":"test-model","done":true,"done_reason":"stop"}"#)
            ]
        )
        let provider = OllamaProvider(
            configuration: OllamaProviderConfiguration(model: "test-model"),
            transport: transport
        )

        var events: [AIProviderStreamingEvent] = []
        for try await event in provider.stream(AIProviderRequest(
            prompt: "Hello",
            conversationID: "conversation-1"
        )) {
            events.append(event)
        }

        #expect(events == [
            .textDelta("Hel"),
            .textDelta("lo"),
            .completed(AIProviderResponse(
                text: "Hello",
                conversationID: "conversation-1",
                modelName: "test-model",
                finishReason: .completed
            ))
        ])

        let request = try #require(transport.sentRequests.first)
        let body = try requestBody(from: request)
        #expect(body["stream"] as? Bool == true)
    }

    @Test
    func streamYieldsFailedEventForProviderErrorLine() async throws {
        let transport = MockOllamaTransport(
            response: .success(OllamaHTTPResponse(statusCode: 200, data: Data())),
            streamEvents: [
                .responseStatus(200),
                .line(#"{"error":"model is not available"}"#)
            ]
        )
        let provider = OllamaProvider(
            configuration: OllamaProviderConfiguration(model: "test-model"),
            transport: transport
        )

        var events: [AIProviderStreamingEvent] = []
        for try await event in provider.stream(AIProviderRequest(prompt: "Hello")) {
            events.append(event)
        }

        #expect(events == [.failed(.requestFailed("model is not available"))])
    }

    private func requestBody(from request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class MockOllamaTransport: OllamaHTTPTransport, @unchecked Sendable {
    private(set) var sentRequests: [URLRequest] = []

    var response: Result<OllamaHTTPResponse, Error>
    var streamEvents: [OllamaHTTPStreamEvent]
    var streamError: Error?

    init(
        response: Result<OllamaHTTPResponse, Error>,
        streamEvents: [OllamaHTTPStreamEvent] = [],
        streamError: Error? = nil
    ) {
        self.response = response
        self.streamEvents = streamEvents
        self.streamError = streamError
    }

    func send(_ request: URLRequest) async throws -> OllamaHTTPResponse {
        sentRequests.append(request)
        return try response.get()
    }

    func stream(_ request: URLRequest) -> AsyncThrowingStream<OllamaHTTPStreamEvent, Error> {
        sentRequests.append(request)
        return AsyncThrowingStream { continuation in
            for event in streamEvents {
                continuation.yield(event)
            }

            if let streamError {
                continuation.finish(throwing: streamError)
            } else {
                continuation.finish()
            }
        }
    }
}
