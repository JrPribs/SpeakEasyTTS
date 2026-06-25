// MenuBarView.swift
// Main menu bar dropdown interface

import SwiftUI

/// Main menu bar view shown when clicking the status bar icon
struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings
    @ObservedObject private var overlayController = FloatingOverlayController.shared
    @State private var inputText: String = ""
    @State private var showingVoicePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with status
            headerSection
            
            Divider()

            // Speech-to-text dictation
            dictationSection

            Divider()
            
            // Quick text input
            quickInputSection
            
            Divider()
            
            // Playback controls (when playing/paused)
            if appState.playbackState != .idle {
                playbackSection
                Divider()
            }
            
            // Voice selection
            voiceSection
            
            Divider()
            
            // Speed control
            speedSection
            
            Divider()
            
            // Claude Code plan reading
            claudePlanSection

            Divider()

            // Actions
            actionsSection
            
            Divider()
            
            // Footer
            footerSection
        }
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Image(systemName: headerIcon)
                .font(.title2)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("SpeakEasy Flow")
                    .font(.headline)
                
                Text(headerStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let voice = appState.selectedVoice {
                Text(voice.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
    }

    private var headerIcon: String {
        appState.dictationState == .idle ? appState.playbackState.systemImage : appState.dictationState.systemImage
    }

    private var headerStatusText: String {
        appState.dictationState == .idle ? appState.playbackState.displayName : appState.dictationState.displayName
    }

    // MARK: - Dictation Section

    private var dictationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Verbatim Dictation", systemImage: appState.dictationState.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(appState.dictationState == .recording ? .red : .secondary)

                Spacer()

                Text("⌥D")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.tertiaryLabelColor).opacity(0.2))
                    .cornerRadius(4)
            }

            HStack(spacing: 8) {
                Button {
                    appState.toggleDictation()
                } label: {
                    Label(
                        appState.dictationState == .idle ? "Start" : "Stop & Insert",
                        systemImage: appState.dictationState == .idle ? "mic.fill" : "stop.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if appState.dictationState != .idle {
                    Button("Cancel") {
                        appState.cancelDictation()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if appState.dictationState == .authorizing {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Spacer()
            }

            if !appState.dictationTranscript.isEmpty {
                Text(appState.dictationTranscript)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Quick Input Section
    
    private var quickInputSection: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Enter text to speak...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                
                Button {
                    if !inputText.isEmpty {
                        appState.speak(inputText)
                    }
                } label: {
                    Image(systemName: "play.fill")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.isEmpty)
            }
            
            HStack(spacing: 12) {
                Button("Read Clipboard") {
                    appState.speakFromClipboard()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Read Selection") {
                    appState.speakSelectedText()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Text("⌥S")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.tertiaryLabelColor).opacity(0.2))
                    .cornerRadius(4)
            }

            if let error = appState.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        appState.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(6)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)
            }
        }
        .padding()
    }
    
    // MARK: - Playback Section
    
    private var playbackSection: some View {
        VStack(spacing: 8) {
            // Progress bar
            if let progress = appState.progress {
                VStack(spacing: 4) {
                    ProgressView(value: progress.progress)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        Text(formatTime(progress.elapsedTime))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if let remaining = progress.estimatedRemainingTime {
                            Text("-\(formatTime(remaining))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Playback controls
            HStack(spacing: 16) {
                Spacer()
                
                Button {
                    appState.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                Button {
                    appState.togglePlayPause()
                } label: {
                    Image(systemName: appState.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            
            // Current word highlight
            if let progress = appState.progress, !progress.currentWord.isEmpty {
                Text("\"\(progress.currentWord)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
    }
    
    // MARK: - Voice Section
    
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Voice")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Picker("", selection: Binding(
                    get: { appState.selectedVoice?.id ?? "" },
                    set: { id in
                        if let voice = appState.availableVoices.first(where: { $0.id == id }) {
                            appState.selectVoice(voice)
                        }
                    }
                )) {
                    ForEach(appState.availableVoices.filter { $0.language.starts(with: "en") }) { voice in
                        Text(voice.displayName)
                            .tag(voice.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 180)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Speed Section
    
    private var speedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Speed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(appState.settings.rateDisplayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            
            Slider(
                value: Binding(
                    get: { Double(appState.settings.rate) },
                    set: { appState.updateRate(Float($0)) }
                ),
                in: 0.1...1.0,
                step: 0.1
            )
            
            HStack {
                Text("Slower")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Faster")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        VStack(spacing: 4) {
            Button {
                openInputWindow()
            } label: {
                HStack {
                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                    Text("Open Text Input Window")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)
            
            Button {
                overlayController.toggle()
            } label: {
                HStack {
                    Image(systemName: overlayController.isVisible ? "pip.fill" : "pip")
                    Text(overlayController.isVisible ? "Hide Floating Widget" : "Show Floating Widget")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)
            
            Button {
                openSettingsWindow()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                    Spacer()
                    Text("⌘,")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
    
    // MARK: - Claude Plan Section

    private var claudePlanSection: some View {
        VStack(spacing: 4) {
            Button {
                appState.speakRecentClaudePlan()
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("Read Recent Plan")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)

            Button {
                appState.speakClaudePlanFromPicker()
            } label: {
                HStack {
                    Image(systemName: "folder")
                    Text("Open Plan File...")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Footer Section
    
    private var footerSection: some View {
        HStack {
            Text("v1.0.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func openInputWindow() {
        // Use NSApp to open the window
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "input-window" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Open via SwiftUI's openWindow environment action
            appState.showInputWindow()
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func openSettingsWindow() {
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }
}

#if canImport(PreviewsMacros)
#Preview {
    MenuBarView()
        .environment(AppState.shared)
}
#endif
