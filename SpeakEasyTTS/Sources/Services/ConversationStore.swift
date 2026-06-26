// ConversationStore.swift
// Lightweight local persistence for Ask AI conversation history.

import Foundation

struct ConversationTurn: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var prompt: String
    var response: String
    var modelName: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        prompt: String,
        response: String,
        modelName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.prompt = prompt
        self.response = response
        self.modelName = modelName
        self.createdAt = createdAt
    }
}

struct ConversationSession: Codable, Equatable, Hashable {
    var id: UUID
    var turns: [ConversationTurn]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        turns: [ConversationTurn] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.turns = turns
        self.updatedAt = updatedAt
    }
}

final class ConversationStore {
    static let sessionStorageKey = "com.speakeasy.ai-conversation.session"
    static let historyEnabledKey = "com.speakeasy.ai-conversation.history-enabled"

    private let defaults: UserDefaults
    private let maxTurns: Int
    private let now: () -> Date
    private let makeID: () -> UUID

    init(
        defaults: UserDefaults = .standard,
        maxTurns: Int = 20,
        now: @escaping () -> Date = { Date() },
        makeID: @escaping () -> UUID = { UUID() }
    ) {
        self.defaults = defaults
        self.maxTurns = max(1, maxTurns)
        self.now = now
        self.makeID = makeID
    }

    func isHistoryEnabled() -> Bool {
        defaults.bool(forKey: Self.historyEnabledKey)
    }

    func setHistoryEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.historyEnabledKey)
    }

    func loadSession() -> ConversationSession {
        guard let data = defaults.data(forKey: Self.sessionStorageKey),
              let session = try? JSONDecoder().decode(ConversationSession.self, from: data) else {
            return ConversationSession(id: makeID(), updatedAt: now())
        }

        return session
    }

    @discardableResult
    func appendTurn(
        prompt: String,
        response: String,
        modelName: String?,
        to existingSession: ConversationSession? = nil
    ) -> ConversationSession {
        var session = existingSession ?? loadSession()
        let turn = ConversationTurn(
            id: makeID(),
            prompt: prompt,
            response: response,
            modelName: modelName,
            createdAt: now()
        )
        session.turns.append(turn)
        if session.turns.count > maxTurns {
            session.turns = Array(session.turns.suffix(maxTurns))
        }
        session.updatedAt = turn.createdAt
        saveSession(session)
        return session
    }

    func clearHistory() {
        let emptySession = ConversationSession(id: makeID(), updatedAt: now())
        saveSession(emptySession)
    }

    private func saveSession(_ session: ConversationSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }

        defaults.set(data, forKey: Self.sessionStorageKey)
    }
}
