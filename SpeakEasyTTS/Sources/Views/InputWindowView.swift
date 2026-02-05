// InputWindowView.swift
// Floating window for manual text input

import SwiftUI

/// Floating window for entering text to be spoken
/// Can be opened via menu bar or hotkey
struct InputWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText: String = ""
    @State private var isExpanded: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            titleBar
            
            // Main content
            VStack(spacing: 12) {
                // Text input area
                textInputArea
                
                // Playback controls (when playing)
                if appState.playbackState != .idle {
                    playbackControls
                }
                
                // Quick settings
                quickSettings
                
                // Action buttons
                actionButtons
            }
            .padding()
        }
        .frame(width: isExpanded ? 500 : 400, height: isExpanded ? 400 : 280)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    // MARK: - Title Bar
    
    private var titleBar: some View {
        HStack {
            // Window controls
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .onTapGesture {
                        dismiss()
                    }
                
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 12, height: 12)
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .onTapGesture {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
            }
            
            Spacer()
            
            Text("SpeakEasy - Text Input")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(appState.playbackState.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }
    
    private var statusColor: Color {
        switch appState.playbackState {
        case .idle: return .gray
        case .playing: return .green
        case .paused: return .orange
        }
    }
    
    // MARK: - Text Input Area
    
    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Enter text to speak:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(inputText.count) characters")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            TextEditor(text: $inputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .focused($isTextFieldFocused)
                .frame(minHeight: isExpanded ? 200 : 100)
        }
    }
    
    // MARK: - Playback Controls
    
    private var playbackControls: some View {
        VStack(spacing: 8) {
            // Progress bar
            if let progress = appState.progress {
                ProgressView(value: progress.progress)
                    .progressViewStyle(.linear)
            }
            
            // Control buttons
            HStack(spacing: 20) {
                Button {
                    appState.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                Button {
                    appState.togglePlayPause()
                } label: {
                    Image(systemName: appState.playbackState == .playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                
                // Placeholder for symmetry
                Color.clear
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Quick Settings
    
    private var quickSettings: some View {
        HStack(spacing: 16) {
            // Voice picker
            HStack(spacing: 4) {
                Image(systemName: "person.wave.2")
                    .foregroundStyle(.secondary)
                
                Picker("", selection: Binding(
                    get: { appState.selectedVoice?.id ?? "" },
                    set: { id in
                        if let voice = appState.availableVoices.first(where: { $0.id == id }) {
                            appState.selectVoice(voice)
                        }
                    }
                )) {
                    ForEach(appState.availableVoices.filter { $0.language.starts(with: "en") }.prefix(10)) { voice in
                        Text(voice.name).tag(voice.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 120)
            }
            
            Divider()
                .frame(height: 20)
            
            // Speed slider
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .foregroundStyle(.secondary)
                
                Slider(
                    value: Binding(
                        get: { Double(appState.settings.rate) },
                        set: { appState.updateRate(Float($0)) }
                    ),
                    in: 0.1...1.0
                )
                .frame(width: 80)
                
                Text(appState.settings.rateDisplayString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 35)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Paste from Clipboard") {
                if let text = NSPasteboard.general.string(forType: .string) {
                    inputText = text
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            Button("Clear") {
                inputText = ""
                appState.stop()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            Spacer()
            
            Button {
                if !inputText.isEmpty {
                    appState.speak(inputText)
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Speak")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(inputText.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}

// MARK: - Visual Effect View

/// NSVisualEffectView wrapper for SwiftUI
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    InputWindowView()
        .environment(AppState.shared)
}
