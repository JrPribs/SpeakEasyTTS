// SettingsView.swift
// Settings/Preferences window

import SwiftUI

/// Settings window for configuring TTS preferences
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .environment(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            DictationSettingsTab()
                .environment(appState)
                .tabItem {
                    Label("Dictation", systemImage: "mic")
                }

            VoiceSettingsTab()
                .environment(appState)
                .tabItem {
                    Label("Voices", systemImage: "person.wave.2")
                }

            ReadbackSettingsTab()
                .environment(appState)
                .tabItem {
                    Label("Readback", systemImage: "speaker.wave.2")
                }

            ShortcutsTab()
                .environment(appState)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            PermissionsSettingsTab()
                .environment(appState)
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }

            AISettingsTab()
                .environment(appState)
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

#if canImport(PreviewsMacros)
#Preview {
    SettingsView()
        .environment(AppState.shared)
}
#endif
