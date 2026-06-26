import SwiftUI

struct ReadbackSettingsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Default Processing") {
                Picker("Default Mode", selection: Binding(
                    get: { appState.settings.readback.defaultProfile },
                    set: { appState.updateDefaultReadbackProfile($0) }
                )) {
                    ForEach(ReadbackProfile.allCases, id: \.self) { profile in
                        Text(profile.displayName).tag(profile)
                    }
                }

                Picker("Detail", selection: Binding(
                    get: { appState.settings.readback.defaultDetailLevel },
                    set: { appState.updateDefaultReadbackDetailLevel($0) }
                )) {
                    ForEach(ReadbackDetailLevel.allCases, id: \.self) { detailLevel in
                        Text(detailLevel.displayName).tag(detailLevel)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Request AI summary when available", isOn: Binding(
                    get: { appState.settings.readback.requestAISummaryByDefault },
                    set: { appState.updateRequestAISummaryByDefault($0) }
                ))

                Text("Raw preserves the source text. Summarized modes use the readback pipeline before speech.")
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
                        Text("Delay")
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
            }

            Section("Speech") {
                HStack {
                    Text("Speed")
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

                Picker("Voice", selection: Binding(
                    get: { appState.selectedVoice?.id ?? "" },
                    set: { id in
                        if let voice = appState.availableVoices.first(where: { $0.id == id }) {
                            appState.selectVoice(voice)
                        }
                    }
                )) {
                    ForEach(appState.availableVoices.filter { $0.language.starts(with: "en") }) { voice in
                        Text(voice.displayName).tag(voice.id)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
