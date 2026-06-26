import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct ConversationStoreTests {
    @Test
    func historyIsDisabledByDefaultWithEmptySession() throws {
        let harness = try StoreHarness()

        #expect(!harness.store.isHistoryEnabled())
        #expect(harness.store.loadSession().turns.isEmpty)
    }

    @Test
    func historyEnabledSettingPersists() throws {
        let harness = try StoreHarness()

        harness.store.setHistoryEnabled(true)

        let reloaded = ConversationStore(defaults: harness.defaults)
        #expect(reloaded.isHistoryEnabled())
    }

    @Test
    func appendTurnPersistsBoundedSession() throws {
        let harness = try StoreHarness(maxTurns: 2)

        harness.store.appendTurn(prompt: "one", response: "first", modelName: "model-a")
        harness.store.appendTurn(prompt: "two", response: "second", modelName: "model-b")
        harness.store.appendTurn(prompt: "three", response: "third", modelName: "model-c")

        let turns = ConversationStore(defaults: harness.defaults).loadSession().turns
        #expect(turns.map(\.prompt) == ["two", "three"])
        #expect(turns.map(\.response) == ["second", "third"])
        #expect(turns.map(\.modelName) == ["model-b", "model-c"])
    }

    @Test
    func clearHistoryRemovesTurnsButPreservesEnabledSetting() throws {
        let harness = try StoreHarness()
        harness.store.setHistoryEnabled(true)
        harness.store.appendTurn(prompt: "question", response: "answer", modelName: nil)

        harness.store.clearHistory()

        #expect(harness.store.loadSession().turns.isEmpty)
        #expect(harness.store.isHistoryEnabled())
    }

    @Test
    func clearHistoryRemovesPriorPromptAndResponseFromStorage() throws {
        let harness = try StoreHarness()
        harness.store.appendTurn(prompt: "sensitive prompt", response: "sensitive answer", modelName: nil)

        harness.store.clearHistory()

        let rawData = try #require(harness.defaults.data(forKey: ConversationStore.sessionStorageKey))
        let rawJSON = try #require(String(data: rawData, encoding: .utf8))
        #expect(!rawJSON.contains("sensitive prompt"))
        #expect(!rawJSON.contains("sensitive answer"))
    }
}

private final class StoreHarness {
    let suiteName: String
    let defaults: UserDefaults
    let store: ConversationStore

    init(maxTurns: Int = 20) throws {
        suiteName = "ConversationStoreTests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        store = ConversationStore(
            defaults: defaults,
            maxTurns: maxTurns,
            now: { Date(timeIntervalSince1970: 4_000) },
            makeID: { UUID(uuidString: "00000000-0000-0000-0000-000000000004")! }
        )
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
