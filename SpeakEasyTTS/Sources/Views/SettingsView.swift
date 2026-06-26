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

            VoiceSettingsTab()
                .environment(appState)
                .tabItem {
                    Label("Voices", systemImage: "person.wave.2")
                }

            ShortcutsTab()
                .environment(appState)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
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
