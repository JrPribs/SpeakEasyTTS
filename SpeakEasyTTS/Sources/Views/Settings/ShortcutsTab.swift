import SwiftUI

struct ShortcutsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Global Shortcuts") {
                ShortcutRecorderRow(
                    title: "Read Selected Text",
                    shortcut: appState.settings.shortcuts.readSelection.shortcut,
                    onRecord: { saveShortcut($0, for: .readSelection) },
                    onReset: { resetShortcut(for: .readSelection) }
                )

                ShortcutRecorderRow(
                    title: "Toggle Dictation",
                    shortcut: appState.settings.shortcuts.dictation.shortcut,
                    onRecord: { saveShortcut($0, for: .toggleDictation) },
                    onReset: { resetShortcut(for: .toggleDictation) }
                )

                Text("Function/Globe capture depends on Mac hardware and system settings. Use Command, Option, or Control with a regular key for reliable hold shortcuts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Playback Controls") {
                HStack {
                    Text("Play/Pause")
                    Spacer()
                    KeyboardShortcutView(shortcut: "Space")
                }

                HStack {
                    Text("Stop")
                    Spacer()
                    KeyboardShortcutView(shortcut: "Esc")
                }
            }

        }
        .formStyle(.grouped)
        .padding()
    }

    private func saveShortcut(_ shortcut: KeyboardShortcut, for action: ShortcutTriggerAction) -> String? {
        if let validationMessage = validationMessage(for: shortcut, replacing: action) {
            return validationMessage
        }

        var preferences = appState.settings.shortcuts
        switch action {
        case .readSelection:
            preferences.readSelection.shortcut = shortcut
        case .toggleDictation:
            preferences.dictation.shortcut = shortcut
        }
        appState.updateShortcutPreferences(preferences)
        return nil
    }

    private func resetShortcut(for action: ShortcutTriggerAction) {
        var preferences = appState.settings.shortcuts
        switch action {
        case .readSelection:
            preferences.readSelection = .defaultReadSelection
        case .toggleDictation:
            preferences.dictation = .defaultDictation
        }
        appState.updateShortcutPreferences(preferences)
    }

    private func validationMessage(for shortcut: KeyboardShortcut, replacing action: ShortcutTriggerAction) -> String? {
        ShortcutValidator.validationMessage(
            for: shortcut,
            replacing: action,
            preferences: appState.settings.shortcuts
        )
    }
}

struct KeyboardShortcutView: View {
    let shortcut: String

    var body: some View {
        Text(shortcut)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.tertiaryLabelColor).opacity(0.2))
            .cornerRadius(4)
    }
}
