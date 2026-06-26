// SettingsView.swift
// Settings/Preferences window

import SwiftUI

/// Settings window for configuring TTS preferences
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        TabView {
            // General Settings
            GeneralSettingsTab()
                .environment(appState)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            // Voice Settings
            VoiceSettingsTab()
                .environment(appState)
                .tabItem {
                    Label("Voices", systemImage: "person.wave.2")
                }
            
            // Shortcuts
            ShortcutsTab()
                .environment(appState)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
            
            // About
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {
    @Environment(AppState.self) private var appState
    @State private var launchAtLogin: Bool = false
    @State private var showInDock: Bool = false
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Show in Dock", isOn: $showInDock)
            }

            Section("Dictation") {
                HStack {
                    Text("Mode")
                    Spacer()
                    Label("Verbatim", systemImage: "text.quote")
                        .foregroundStyle(.secondary)
                }

                Text("Dictation inserts the recognized words directly, with no AI rewrite or cleanup step.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("TTS Engine") {
                Picker("Engine", selection: Binding(
                    get: { appState.settings.ttsEngine },
                    set: { newValue in
                        appState.switchEngine(newValue)
                    }
                )) {
                    ForEach(SpeechSettings.TTSEngine.allCases, id: \.self) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text(appState.settings.ttsEngine.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Auto-Read") {
                Toggle("Auto-read selected text", isOn: Binding(
                    get: { appState.settings.autoReadOnSelection },
                    set: { appState.updateAutoReadOnSelection($0) }
                ))
                
                if appState.settings.autoReadOnSelection {
                    HStack {
                        Text("Delay before reading")
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { appState.settings.autoReadDelay },
                                set: { appState.updateAutoReadDelay($0) }
                            ),
                            in: 0.3...2.0,
                            step: 0.1
                        )
                        .frame(width: 150)
                        
                        Text(String(format: "%.1fs", appState.settings.autoReadDelay))
                            .frame(width: 40)
                            .monospacedDigit()
                    }
                }
                
                Text("When enabled, text will automatically be read aloud after selection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Playback") {
                HStack {
                    Text("Default Speed")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { Double(appState.settings.rate) },
                            set: { appState.updateRate(Float($0)) }
                        ),
                        in: 0.1...1.0
                    )
                    .frame(width: 200)
                    
                    Text(appState.settings.rateDisplayString)
                        .frame(width: 45)
                        .monospacedDigit()
                }
                
                HStack {
                    Text("Pitch")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { Double(appState.settings.pitch) },
                            set: { appState.updatePitch(Float($0)) }
                        ),
                        in: 0.5...2.0
                    )
                    .frame(width: 200)
                    
                    Text(String(format: "%.1f", appState.settings.pitch))
                        .frame(width: 45)
                        .monospacedDigit()
                }
                
                HStack {
                    Text("Volume")
                    Spacer()
                    Slider(
                        value: Binding(
                            get: { Double(appState.settings.volume) },
                            set: { appState.updateVolume(Float($0)) }
                        ),
                        in: 0.0...1.0
                    )
                    .frame(width: 200)
                    
                    Text(String(format: "%.0f%%", appState.settings.volume * 100))
                        .frame(width: 45)
                        .monospacedDigit()
                }
            }
            
            Section {
                Button("Reset to Defaults") {
                    appState.resetSettings()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Voice Settings Tab

struct VoiceSettingsTab: View {
    @Environment(AppState.self) private var appState
    @State private var searchText: String = ""
    @State private var selectedLanguage: String = "en"
    @State private var previewingVoice: Voice?
    
    private var filteredVoices: [Voice] {
        appState.availableVoices.filter { voice in
            let matchesLanguage = selectedLanguage.isEmpty || voice.language.starts(with: selectedLanguage)
            let matchesSearch = searchText.isEmpty || 
                voice.name.localizedCaseInsensitiveContains(searchText)
            return matchesLanguage && matchesSearch
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filters
            HStack {
                TextField("Search voices...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Language", selection: $selectedLanguage) {
                    Text("All Languages").tag("")
                    Text("English").tag("en")
                    Text("Spanish").tag("es")
                    Text("French").tag("fr")
                    Text("German").tag("de")
                    Text("Chinese").tag("zh")
                    Text("Japanese").tag("ja")
                }
                .frame(width: 150)
            }
            .padding()
            
            // Voice list
            List(filteredVoices, selection: Binding(
                get: { appState.selectedVoice?.id },
                set: { id in
                    if let id = id,
                       let voice = appState.availableVoices.first(where: { $0.id == id }) {
                        appState.selectVoice(voice)
                    }
                }
            )) { voice in
                VoiceRow(
                    voice: voice,
                    isSelected: voice.id == appState.selectedVoice?.id,
                    isPreviewing: voice.id == previewingVoice?.id,
                    onPreview: {
                        previewVoice(voice)
                    }
                )
                .tag(voice.id)
            }
            
            // Footer
            HStack {
                Text("\(filteredVoices.count) voices available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Download More Voices...") {
                    openVoiceSettings()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding()
        }
    }
    
    private func previewVoice(_ voice: Voice) {
        previewingVoice = voice
        appState.voiceManager.previewVoice(voice) {
            DispatchQueue.main.async {
                previewingVoice = nil
            }
        }
    }
    
    private func openVoiceSettings() {
        // Open System Settings > Accessibility > Spoken Content
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Accessibility_SpeakingTab") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Voice Row

struct VoiceRow: View {
    let voice: Voice
    let isSelected: Bool
    let isPreviewing: Bool
    let onPreview: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(voice.name)
                        .fontWeight(isSelected ? .semibold : .regular)
                    
                    if voice.quality != .default {
                        Text(voice.quality.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(voice.quality == .premium ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(voice.language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                onPreview()
            } label: {
                if isPreviewing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "play.circle")
                }
            }
            .buttonStyle(.plain)
            .disabled(isPreviewing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shortcuts Tab

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

                Picker("Dictation Mode", selection: Binding(
                    get: { appState.settings.shortcuts.dictation.triggerMode ?? .toggle },
                    set: { appState.updateDictationTriggerMode($0) }
                )) {
                    Text(DictationTriggerMode.toggle.displayName).tag(DictationTriggerMode.toggle)
                    Text(DictationTriggerMode.holdToRecord.displayName).tag(DictationTriggerMode.holdToRecord)
                }
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
            
            Section("Accessibility") {
                HStack {
                    Text("Status")
                    Spacer()
                    if appState.hasAccessibilityPermissions {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not Granted", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                
                Text("Global shortcuts, text selection detection, and dictation insertion require Accessibility permissions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Open Accessibility Settings") {
                    appState.openAccessibilitySettings()
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
        let hasPrimaryModifier = shortcut.modifiers.contains(.command)
            || shortcut.modifiers.contains(.option)
            || shortcut.modifiers.contains(.control)
        guard hasPrimaryModifier else {
            return "Use Command, Option, or Control."
        }

        if shortcut.keyCode == KeyCodeDisplayName.escape {
            return "Escape is reserved."
        }

        let preferences = appState.settings.shortcuts
        switch action {
        case .readSelection:
            if shortcut.matches(preferences.dictation.shortcut) {
                return "Already used by Dictation."
            }
        case .toggleDictation:
            if shortcut.matches(preferences.readSelection.shortcut) {
                return "Already used by Read Selected Text."
            }
        }

        return nil
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

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "mic.and.signal.meter.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            
            Text("SpeakEasy Flow")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("A lightweight menu bar app for dictation and text-to-speech")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Divider()
                .frame(width: 200)
            
            VStack(spacing: 8) {
                Text("Features:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    FeatureRow(icon: "mic.fill", text: "Verbatim dictation (⌥D)")
                    FeatureRow(icon: "keyboard", text: "Read selected text (⌥S)")
                    FeatureRow(icon: "doc.on.clipboard", text: "Read from clipboard")
                    FeatureRow(icon: "text.cursor", text: "Read selected text")
                    FeatureRow(icon: "waveform", text: "Auto-read on selection")
                    FeatureRow(icon: "person.wave.2", text: "Multiple voice options")
                    FeatureRow(icon: "speedometer", text: "Adjustable speed")
                }
            }
            
            Spacer()
            
            Text("© 2024 SpeakEasy")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.blue)
            Text(text)
                .font(.caption)
        }
    }
}

#if canImport(PreviewsMacros)
#Preview {
    SettingsView()
        .environment(AppState.shared)
}
#endif
