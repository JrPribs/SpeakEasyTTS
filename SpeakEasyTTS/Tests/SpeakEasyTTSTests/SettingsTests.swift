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

    @Test
    func legacySettingsWithoutShortcutsDecodeWithShortcutDefaults() throws {
        let legacyJSON = """
        {
          "selectedVoiceId": "com.apple.voice.compact.en-US.Samantha",
          "rate": 0.5,
          "pitch": 1.0,
          "volume": 1.0,
          "ttsEngine": "Native (macOS)",
          "autoReadOnSelection": false,
          "autoReadDelay": 0.8
        }
        """
        let data = try #require(legacyJSON.data(using: .utf8))

        let settings = try JSONDecoder().decode(SpeechSettings.self, from: data)

        #expect(settings.shortcuts == .default)
        #expect(settings.readback == .default)
    }

    @Test
    func shortcutSettingsPersistAndReloadFromInjectedDefaults() throws {
        let suiteName = "SettingsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        var settings = SpeechSettings.default
        settings.shortcuts.dictation = ShortcutDefinition(
            action: .toggleDictation,
            shortcut: KeyboardShortcut(keyCode: KeyCodeDisplayName.space, modifiers: [.control, .option]),
            triggerMode: .holdWithSpaceLatch
        )
        settings.shortcuts.readSelection = ShortcutDefinition(
            action: .readSelection,
            shortcut: KeyboardShortcut(keyCode: KeyCodeDisplayName.s, modifiers: [.command, .shift]),
            triggerMode: nil
        )

        store.saveSettings(settings)
        let reloadedSettings = store.loadSettings()

        #expect(reloadedSettings.shortcuts == settings.shortcuts)
    }

    @Test
    func dictationTriggerModesPersistAndReloadFromInjectedDefaults() throws {
        for mode in DictationTriggerMode.allCases {
            let suiteName = "SettingsTests-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defaults.removePersistentDomain(forName: suiteName)
            defer {
                defaults.removePersistentDomain(forName: suiteName)
            }

            let store = SettingsStore(defaults: defaults)
            var settings = SpeechSettings.default
            settings.shortcuts.dictation.triggerMode = mode

            store.saveSettings(settings)

            #expect(store.loadSettings().shortcuts.dictation.triggerMode == mode)
        }
    }

    @Test
    func readbackPreferencesPersistAndReloadFromInjectedDefaults() throws {
        let suiteName = "SettingsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        var settings = SpeechSettings.default
        settings.readback = ReadbackPreferences(
            defaultProfile: .technicalResponse,
            defaultDetailLevel: .detailed,
            requestAISummaryByDefault: true
        )

        store.saveSettings(settings)

        #expect(store.loadSettings().readback == settings.readback)
        #expect(store.loadSettings().readback.processingOptions == ReadbackProcessingOptions(
            normalizeMarkdown: true,
            summarizeCodeBlocks: true,
            preserveTaskStructure: true,
            requestAISummary: true
        ))
    }

    @Test
    func resetSettingsRestoresDefaultShortcuts() throws {
        let suiteName = "SettingsTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        var settings = SpeechSettings.default
        settings.shortcuts.dictation.triggerMode = .holdToRecord
        store.saveSettings(settings)

        store.resetSettings()

        #expect(store.loadSettings().shortcuts == .default)
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
