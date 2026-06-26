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
        let commandShiftUnknown = KeyboardShortcut(keyCode: 123, modifiers: [.command, .shift])

        #expect(optionSpace.displayName == "Option+Space / ⌥Space")
        #expect(commandShiftUnknown.displayName == "Shift+Command+Key 123 / ⇧⌘Key 123")
    }
}
