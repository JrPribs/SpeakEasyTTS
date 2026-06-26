// OllamaProvider.swift
// Local Ollama adapter behind the provider-neutral AIProvider contract.

import Foundation

struct OllamaProviderConfiguration: Equatable, Hashable {
    var baseURL: URL
    var model: String
    var requiresAuthentication: Bool

    init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        model: String = "llama3.2",
        requiresAuthentication: Bool = false
    ) {
        self.baseURL = baseURL
        self.model = model
        self.requiresAuthentication = requiresAuthentication
    }
}

struct OllamaHTTPResponse: Equatable {
    var statusCode: Int
    var data: Data
}

enum OllamaHTTPStreamEvent: Equatable {
    case responseStatus(Int)
    case line(String)
}

protocol OllamaHTTPTransport {
    func send(_ request: URLRequest) async throws -> OllamaHTTPResponse
    func stream(_ request: URLRequest) -> AsyncThrowingStream<OllamaHTTPStreamEvent, Error>
}

struct URLSessionOllamaHTTPTransport: OllamaHTTPTransport {
    func send(_ request: URLRequest) async throws -> OllamaHTTPResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse("Ollama returned a non-HTTP response.")
        }

        return OllamaHTTPResponse(statusCode: httpResponse.statusCode, data: data)
    }

    func stream(_ request: URLRequest) -> AsyncThrowingStream<OllamaHTTPStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIProviderError.invalidResponse("Ollama returned a non-HTTP response.")
                    }

                    continuation.yield(.responseStatus(httpResponse.statusCode))
                    for try await line in bytes.lines {
                        continuation.yield(.line(line))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

struct OllamaProvider: AIProvider {
    let id = "ollama"
    let displayName = "Ollama"

    private let configuration: OllamaProviderConfiguration
    private let transport: OllamaHTTPTransport
    private let credentialProvider: () -> String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: OllamaProviderConfiguration = OllamaProviderConfiguration(),
        transport: OllamaHTTPTransport = URLSessionOllamaHTTPTransport(),
        credentialProvider: @escaping () -> String? = { nil }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.credentialProvider = credentialProvider
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func complete(_ request: AIProviderRequest) async throws -> AIProviderResponse {
        do {
            let urlRequest = try makeURLRequest(for: request, stream: false)
            let response = try await transport.send(urlRequest)
            try validate(statusCode: response.statusCode, data: response.data)
            let decoded = try decodeResponse(response.data)

            if let error = decoded.error, !error.isEmpty {
                throw AIProviderError.requestFailed(error)
            }

            guard let text = decoded.message?.content, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIProviderError.invalidResponse("Ollama response did not include assistant text.")
            }

            return AIProviderResponse(
                text: text,
                conversationID: request.conversationID,
                modelName: decoded.model ?? configuration.model,
                finishReason: finishReason(from: decoded.doneReason, done: decoded.done)
            )
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.requestFailed(error.localizedDescription)
        }
    }

    func stream(_ request: AIProviderRequest) -> AsyncThrowingStream<AIProviderStreamingEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try makeURLRequest(for: request, stream: true)
                    var fullText = ""
                    var completed = false
                    var lastModelName: String?
                    var lastFinishReason: AIProviderFinishReason?

                    for try await event in transport.stream(urlRequest) {
                        switch event {
                        case .responseStatus(let statusCode):
                            try validate(statusCode: statusCode, data: Data())
                        case .line(let line):
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { continue }

                            let decoded = try decodeResponse(Data(trimmed.utf8))
                            if let error = decoded.error, !error.isEmpty {
                                throw AIProviderError.requestFailed(error)
                            }

                            if let delta = decoded.message?.content, !delta.isEmpty {
                                fullText += delta
                                continuation.yield(.textDelta(delta))
                            }

                            lastModelName = decoded.model ?? lastModelName
                            lastFinishReason = finishReason(from: decoded.doneReason, done: decoded.done)

                            if decoded.done {
                                completed = true
                                continuation.yield(.completed(AIProviderResponse(
                                    text: fullText,
                                    conversationID: request.conversationID,
                                    modelName: lastModelName ?? configuration.model,
                                    finishReason: lastFinishReason
                                )))
                            }
                        }
                    }

                    if !completed, !fullText.isEmpty {
                        continuation.yield(.completed(AIProviderResponse(
                            text: fullText,
                            conversationID: request.conversationID,
                            modelName: lastModelName ?? configuration.model,
                            finishReason: lastFinishReason
                        )))
                    }

                    continuation.finish()
                } catch {
                    continuation.yield(.failed(providerError(from: error)))
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func makeURLRequest(for request: AIProviderRequest, stream: Bool) throws -> URLRequest {
        if configuration.requiresAuthentication {
            guard let credential = credentialProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !credential.isEmpty else {
                throw AIProviderError.notConfigured
            }
        }

        var endpoint = configuration.baseURL
        endpoint.appendPathComponent("api")
        endpoint.appendPathComponent("chat")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let credential = credentialProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !credential.isEmpty {
            urlRequest.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
        }

        let payload = OllamaChatRequest(
            model: configuration.model,
            messages: [
                OllamaChatMessage(
                    role: "system",
                    content: "You are a concise assistant for macOS voice workflows."
                ),
                OllamaChatMessage(
                    role: "user",
                    content: userContent(for: request)
                )
            ],
            stream: stream
        )
        urlRequest.httpBody = try encoder.encode(payload)
        return urlRequest
    }

    private func userContent(for request: AIProviderRequest) -> String {
        var sections = ["Prompt:\n\(request.prompt)"]

        if let selectedText = request.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !selectedText.isEmpty {
            sections.append("Selected text:\n\(selectedText)")
        }

        if let appContext = request.appContext {
            var contextLines = ["App: \(appContext.appName)"]
            if let bundleIdentifier = appContext.bundleIdentifier {
                contextLines.append("Bundle ID: \(bundleIdentifier)")
            }
            if let processIdentifier = appContext.processIdentifier {
                contextLines.append("Process ID: \(processIdentifier)")
            }
            sections.append("App context:\n\(contextLines.joined(separator: "\n"))")
        }

        if let conversationID = request.conversationID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !conversationID.isEmpty {
            sections.append("Conversation ID:\n\(conversationID)")
        }

        if !request.metadata.isEmpty {
            let metadata = request.metadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            sections.append("Metadata:\n\(metadata)")
        }

        return sections.joined(separator: "\n\n")
    }

    private func validate(statusCode: Int, data: Data) throws {
        guard (200..<300).contains(statusCode) else {
            throw httpError(statusCode: statusCode, data: data)
        }
    }

    private func httpError(statusCode: Int, data: Data) -> AIProviderError {
        switch statusCode {
        case 401, 403:
            return .authenticationFailed
        case 429:
            return .rateLimited
        default:
            let message = (try? decoder.decode(OllamaErrorResponse.self, from: data).error)
                ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
            return .requestFailed("Ollama request failed (\(statusCode)): \(message)")
        }
    }

    private func decodeResponse(_ data: Data) throws -> OllamaChatResponse {
        do {
            return try decoder.decode(OllamaChatResponse.self, from: data)
        } catch {
            throw AIProviderError.invalidResponse("Ollama response was invalid.")
        }
    }

    private func finishReason(from doneReason: String?, done: Bool) -> AIProviderFinishReason? {
        guard done else { return nil }

        switch doneReason {
        case "length":
            return .lengthLimit
        case "unload":
            return .cancelled
        case "error":
            return .error
        default:
            return .completed
        }
    }

    private func providerError(from error: Error) -> AIProviderError {
        if let providerError = error as? AIProviderError {
            return providerError
        }

        return .requestFailed(error.localizedDescription)
    }
}

private struct OllamaChatRequest: Encodable {
    var model: String
    var messages: [OllamaChatMessage]
    var stream: Bool
}

private struct OllamaChatMessage: Codable, Equatable {
    var role: String
    var content: String
}

private struct OllamaChatResponse: Decodable {
    var model: String?
    var message: OllamaChatMessage?
    var done: Bool
    var doneReason: String?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case model
        case message
        case done
        case doneReason = "done_reason"
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        message = try container.decodeIfPresent(OllamaChatMessage.self, forKey: .message)
        done = try container.decodeIfPresent(Bool.self, forKey: .done) ?? false
        doneReason = try container.decodeIfPresent(String.self, forKey: .doneReason)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}

private struct OllamaErrorResponse: Decodable {
    var error: String
}
