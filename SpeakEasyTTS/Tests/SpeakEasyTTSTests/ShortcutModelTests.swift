import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct ShortcutModelTests {
    @Test
    func defaultShortcutPreferencesRoundTripThroughCodable() throws {
        let data = try JSONEncoder().encode(ShortcutPreferences.default)
        let decoded = try JSONDecoder().decode(ShortcutPreferences.self, from: data)

        #expect(decoded == .default)
    }

    @Test
    func defaultsMatchCurrentGlobalHotkeys() {
        let defaults = ShortcutPreferences.default

        #expect(defaults.dictation.action == .toggleDictation)
        #expect(defaults.dictation.shortcut.keyCode == KeyCodeDisplayName.d)
        #expect(defaults.dictation.shortcut.modifiers == .option)
        #expect(defaults.dictation.shortcut.displayName == "Option+D / ⌥D")
        #expect(defaults.dictation.triggerMode == .toggle)

        #expect(defaults.readSelection.action == .readSelection)
        #expect(defaults.readSelection.shortcut.keyCode == KeyCodeDisplayName.s)
        #expect(defaults.readSelection.shortcut.modifiers == .option)
        #expect(defaults.readSelection.shortcut.displayName == "Option+S / ⌥S")
        #expect(defaults.readSelection.triggerMode == nil)
    }

    @Test
    func shortcutCanRepresentHoldAndLatchTriggerModes() {
        let holdDefinition = ShortcutDefinition(
            action: .toggleDictation,
            shortcut: KeyboardShortcut(keyCode: KeyCodeDisplayName.d, modifiers: .option),
            triggerMode: .holdToRecord
        )
        let latchDefinition = ShortcutDefinition(
            action: .toggleDictation,
            shortcut: KeyboardShortcut(keyCode: KeyCodeDisplayName.d, modifiers: .option),
            triggerMode: .holdWithSpaceLatch
        )

        #expect(holdDefinition.triggerMode == .holdToRecord)
        #expect(latchDefinition.triggerMode == .holdWithSpaceLatch)
    }

    @Test
    func displayNamesAreStableForKnownAndUnknownKeys() {
        let optionSpace = KeyboardShortcut(keyCode: KeyCodeDisplayName.space, modifiers: .option)
        let commandTab = KeyboardShortcut(keyCode: KeyCodeDisplayName.tab, modifiers: .command)
        let commandShiftUnknown = KeyboardShortcut(keyCode: 123, modifiers: [.command, .shift])

        #expect(optionSpace.displayName == "Option+Space / ⌥Space")
        #expect(commandTab.displayName == "Command+Tab / ⌘Tab")
        #expect(commandShiftUnknown.displayName == "Shift+Command+Key 123 / ⇧⌘Key 123")
    }

    @Test
    func shortcutMatchingIgnoresStoredDisplayName() {
        let first = KeyboardShortcut(keyCode: KeyCodeDisplayName.d, modifiers: .option)
        let second = KeyboardShortcut(keyCode: KeyCodeDisplayName.d, modifiers: .option, displayName: "Custom")

        #expect(first.matches(second))
        #expect(first != second)
    }

    @Test
    func hotkeyDefinitionsUseStoredShortcutPreferences() {
        var preferences = ShortcutPreferences.default
        preferences.dictation.shortcut = KeyboardShortcut(keyCode: KeyCodeDisplayName.space, modifiers: [.control, .option])
        preferences.readSelection.shortcut = KeyboardShortcut(keyCode: KeyCodeDisplayName.s, modifiers: [.command])

        let definitions = HotkeyManager.hotkeyDefinitions(from: preferences)

        #expect(definitions == [
            HotkeyManager.HotkeyDefinition(
                action: .readSelection,
                shortcut: preferences.readSelection.shortcut,
                triggerMode: nil
            ),
            HotkeyManager.HotkeyDefinition(
                action: .toggleDictation,
                shortcut: preferences.dictation.shortcut,
                triggerMode: .toggle
            )
        ])
    }

    @Test
    func holdToRecordDefinitionsPreserveTriggerMode() {
        var preferences = ShortcutPreferences.default
        preferences.dictation.triggerMode = .holdToRecord

        let definitions = HotkeyManager.hotkeyDefinitions(from: preferences)

        #expect(definitions == [
            HotkeyManager.HotkeyDefinition(
                action: .readSelection,
                shortcut: preferences.readSelection.shortcut,
                triggerMode: nil
            ),
            HotkeyManager.HotkeyDefinition(
                action: .toggleDictation,
                shortcut: preferences.dictation.shortcut,
                triggerMode: .holdToRecord
            )
        ])
        #expect(HotkeyManager.requiresAuxiliaryMonitoring(for: preferences))
    }

    @Test
    func toggleModeDoesNotRequireAuxiliaryMonitoring() {
        let preferences = ShortcutPreferences.default

        #expect(!HotkeyManager.requiresAuxiliaryMonitoring(for: preferences))
        #expect(HotkeyManager.hotkeyDefinitions(from: preferences).contains(
            HotkeyManager.HotkeyDefinition(
                action: .toggleDictation,
                shortcut: preferences.dictation.shortcut,
                triggerMode: .toggle
            )
        ))
    }

    @Test
    func hotkeyCommandsMapPressAndReleaseByTriggerMode() {
        let readSelection = HotkeyManager.HotkeyDefinition(
            action: .readSelection,
            shortcut: ShortcutPreferences.default.readSelection.shortcut,
            triggerMode: nil
        )
        let toggleDictation = HotkeyManager.HotkeyDefinition(
            action: .toggleDictation,
            shortcut: ShortcutPreferences.default.dictation.shortcut,
            triggerMode: .toggle
        )
        let holdDictation = HotkeyManager.HotkeyDefinition(
            action: .toggleDictation,
            shortcut: ShortcutPreferences.default.dictation.shortcut,
            triggerMode: .holdToRecord
        )
        let latchDictation = HotkeyManager.HotkeyDefinition(
            action: .toggleDictation,
            shortcut: ShortcutPreferences.default.dictation.shortcut,
            triggerMode: .holdWithSpaceLatch
        )

        #expect(HotkeyManager.command(for: readSelection, eventKind: .pressed) == .readSelection)
        #expect(HotkeyManager.command(for: readSelection, eventKind: .released) == nil)
        #expect(HotkeyManager.command(for: toggleDictation, eventKind: .pressed) == .toggleDictation)
        #expect(HotkeyManager.command(for: toggleDictation, eventKind: .released) == nil)
        #expect(HotkeyManager.command(for: holdDictation, eventKind: .pressed) == .startHoldDictation(canLatch: false))
        #expect(HotkeyManager.command(for: holdDictation, eventKind: .released) == .finishHoldDictation)
        #expect(HotkeyManager.command(for: latchDictation, eventKind: .pressed) == .startHoldDictation(canLatch: true))
        #expect(HotkeyManager.command(for: latchDictation, eventKind: .released) == .finishHoldDictation)
    }

    @Test
    func nilDictationTriggerModeFallsBackToToggleCommand() {
        let legacyDictation = HotkeyManager.HotkeyDefinition(
            action: .toggleDictation,
            shortcut: ShortcutPreferences.default.dictation.shortcut,
            triggerMode: nil
        )

        #expect(HotkeyManager.command(for: legacyDictation, eventKind: .pressed) == .toggleDictation)
        #expect(HotkeyManager.command(for: legacyDictation, eventKind: .released) == nil)
    }

    @Test
    func spaceLatchIsAcceptedOnlyForLatchMode() {
        var latchPreferences = ShortcutPreferences.default
        latchPreferences.dictation.triggerMode = .holdWithSpaceLatch

        var holdPreferences = ShortcutPreferences.default
        holdPreferences.dictation.triggerMode = .holdToRecord

        let plainSpace = KeyboardShortcut(keyCode: KeyCodeDisplayName.space, modifiers: [])
        let modifiedSpace = KeyboardShortcut(
            keyCode: KeyCodeDisplayName.space,
            modifiers: latchPreferences.dictation.shortcut.modifiers
        )
        let wrongKey = KeyboardShortcut(keyCode: KeyCodeDisplayName.d, modifiers: [])

        #expect(HotkeyManager.requiresAuxiliaryMonitoring(for: latchPreferences))
        #expect(HotkeyManager.shouldLatchFromAuxiliaryShortcut(plainSpace, shortcuts: latchPreferences))
        #expect(HotkeyManager.shouldLatchFromAuxiliaryShortcut(modifiedSpace, shortcuts: latchPreferences))
        #expect(!HotkeyManager.shouldLatchFromAuxiliaryShortcut(wrongKey, shortcuts: latchPreferences))
        #expect(!HotkeyManager.shouldLatchFromAuxiliaryShortcut(plainSpace, shortcuts: holdPreferences))
    }
}
