import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct SettingsTests {
    @Test
    func legacyDefaultEdgePlaybackMigratesToNative() {
        let legacySettings = makeSettings(
            selectedVoiceId: "en-US-GuyNeural",
            ttsEngine: .edgeTTS
        )

        let migratedSettings = SettingsStore.migratedPlaybackSettings(
            legacySettings,
            edgeTTSAvailable: true
        )

        var expectedSettings = legacySettings
        expectedSettings.ttsEngine = .native
        expectedSettings.selectedVoiceId = nil

        #expect(migratedSettings == expectedSettings)
    }

    @Test
    func explicitEdgePlaybackSettingsArePreservedWhenEdgeTTSIsAvailable() {
        let explicitSettings = makeSettings(
            selectedVoiceId: "en-US-AriaNeural",
            ttsEngine: .edgeTTS
        )

        let migratedSettings = SettingsStore.migratedPlaybackSettings(
            explicitSettings,
            edgeTTSAvailable: true
        )

        #expect(migratedSettings == explicitSettings)
    }

    @Test
    func loadingMigratedSettingsPersistsMigrationInInjectedDefaults() throws {
        let suiteName = "SettingsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        let legacySettings = makeSettings(
            selectedVoiceId: "en-US-GuyNeural",
            ttsEngine: .edgeTTS
        )
        store.saveSettings(legacySettings)

        let migratedSettings = store.loadMigratedSettings(edgeTTSAvailable: true)
        let persistedSettings = store.loadSettings()

        #expect(migratedSettings.ttsEngine == .native)
        #expect(migratedSettings.selectedVoiceId == nil)
        #expect(persistedSettings == migratedSettings)
    }

    private func makeSettings(
        selectedVoiceId: String?,
        ttsEngine: SpeechSettings.TTSEngine
    ) -> SpeechSettings {
        SpeechSettings(
            selectedVoiceId: selectedVoiceId,
            rate: 0.65,
            pitch: 1.2,
            volume: 0.7,
            ttsEngine: ttsEngine,
            autoReadOnSelection: true,
            autoReadDelay: 1.4
        )
    }
}
