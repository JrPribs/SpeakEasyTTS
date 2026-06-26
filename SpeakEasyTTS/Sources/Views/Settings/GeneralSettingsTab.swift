import SwiftUI

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
