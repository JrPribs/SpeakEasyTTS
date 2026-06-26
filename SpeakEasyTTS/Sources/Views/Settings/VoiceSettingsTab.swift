import AppKit
import SwiftUI

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
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Accessibility_SpeakingTab") {
            NSWorkspace.shared.open(url)
        }
    }
}

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
