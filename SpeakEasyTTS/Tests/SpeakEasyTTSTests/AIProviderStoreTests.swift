import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct AIProviderStoreTests {
    @Test
    func defaultStatusIsNotConfiguredWithKeychainStorage() throws {
        let harness = try StoreHarness()

        #expect(harness.store.loadStatus() == .notConfigured)
        #expect(harness.store.loadStatus().credentialStorage == .defaultKeychain)
    }

    @Test
    func configuredStatusPersistsWithoutSecretMaterial() throws {
        let harness = try StoreHarness()

        harness.store.markConfigured(providerID: "openai")

        let reloaded = AIProviderStore(defaults: harness.defaults).loadStatus()
        let rawJSON = try harness.rawStoredJSON()

        #expect(reloaded == AIProviderStatus(state: .configured, providerID: "openai"))
        #expect(rawJSON.contains("configured"))
        #expect(rawJSON.contains("keychain"))
        #expect(!rawJSON.localizedCaseInsensitiveContains("apiKey"))
        #expect(!rawJSON.localizedCaseInsensitiveContains("secret"))
        #expect(!rawJSON.contains("sk-"))
    }

    @Test
    func errorStatusPersistsUserVisibleMessage() throws {
        let harness = try StoreHarness()

        harness.store.markError(providerID: "openai", message: "Credential missing.")

        #expect(AIProviderStore(defaults: harness.defaults).loadStatus() == AIProviderStatus(
            state: .error,
            providerID: "openai",
            message: "Credential missing."
        ))
    }

    @Test
    func resetClearsPersistedStatus() throws {
        let harness = try StoreHarness()
        harness.store.markConfigured(providerID: "openai")

        harness.store.reset()

        #expect(harness.defaults.data(forKey: AIProviderStore.storageKey) == nil)
        #expect(harness.store.loadStatus() == .notConfigured)
    }
}

private final class StoreHarness {
    let suiteName: String
    let defaults: UserDefaults
    let store: AIProviderStore

    init() throws {
        suiteName = "AIProviderStoreTests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        store = AIProviderStore(defaults: defaults)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func rawStoredJSON() throws -> String {
        let data = try #require(defaults.data(forKey: AIProviderStore.storageKey))
        return try #require(String(data: data, encoding: .utf8))
    }
}
