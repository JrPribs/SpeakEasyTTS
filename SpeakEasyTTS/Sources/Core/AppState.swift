// AppState.swift
// Central state management for SpeakEasyTTS

import SwiftUI
import AVFoundation
import Combine

/// Central application state using the new @Observable macro
/// Manages speech playback, settings, and voice selection
@Observable
final class AppState {
    // MARK: - Singleton
    static let shared = AppState()
    
    // MARK: - Published State
    var playbackState: PlaybackState = .idle
    var currentText: String = ""
    var settings: SpeechSettings
    var availableVoices: [Voice] = []
    var selectedVoice: Voice?
    var progress: SpeechProgress?
    var errorMessage: String?
    var isInputWindowVisible: Bool = false
    
    // MARK: - Services
    var speechService: SpeechService
    private var nativeSpeechService: NativeSpeechService
    private var edgeTTSService: EdgeTTSService
    let settingsStore: SettingsStore
    let voiceManager: VoiceManager
    let clipboardService: ClipboardService
    
    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Initialize settings first to know which engine to use
        let store = SettingsStore()
        let loadedSettings = store.loadSettings()
        
        // Initialize both speech services
        let native = NativeSpeechService()
        let edge = EdgeTTSService()
        
        // Store services
        self.settingsStore = store
        self.voiceManager = VoiceManager()
        self.clipboardService = ClipboardService()
        self.settings = loadedSettings
        self.nativeSpeechService = native
        self.edgeTTSService = edge
        
        // Use the appropriate service based on settings
        if loadedSettings.ttsEngine == .edgeTTS {
            self.speechService = edge
        } else {
            self.speechService = native
        }
        
        // Load available voices based on engine
        loadVoices()
        
        // Set up speech service delegate
        setupSpeechServiceCallbacks()
        
        // Restore selected voice
        if let voiceId = settings.selectedVoiceId,
           let voice = availableVoices.first(where: { $0.id == voiceId }) {
            selectedVoice = voice
        } else {
            // Default to first English voice
            selectedVoice = availableVoices.first { $0.language.starts(with: "en") }
        }
    }
    
    // MARK: - Voice Management
    
    /// Load all available voices based on current TTS engine
    func loadVoices() {
        if settings.ttsEngine == .edgeTTS {
            // Load Edge TTS neural voices
            availableVoices = EdgeTTSService.availableVoices.map { edgeVoice in
                Voice(
                    id: edgeVoice.id,
                    name: "\(edgeVoice.name) (Neural)",
                    language: edgeVoice.language,
                    quality: .enhanced
                )
            }
        } else {
            // Load native macOS voices
            availableVoices = voiceManager.discoverVoices()
        }
    }
    
    /// Switch TTS engine and reload voices
    func switchEngine(_ engine: SpeechSettings.TTSEngine) {
        settings.ttsEngine = engine
        
        // Switch the active speech service
        if engine == .edgeTTS {
            speechService = edgeTTSService
        } else {
            speechService = nativeSpeechService
        }
        
        // Reload voices for the new engine
        loadVoices()
        
        // Select first available voice
        selectedVoice = availableVoices.first { $0.language.starts(with: "en") }
        if let voice = selectedVoice {
            settings.selectedVoiceId = voice.id
        }
        
        // Set up callbacks for new service
        setupSpeechServiceCallbacks()
        
        saveSettings()
    }
    
    /// Select a voice and save preference
    func selectVoice(_ voice: Voice) {
        selectedVoice = voice
        settings.selectedVoiceId = voice.id
        saveSettings()
    }
    
    // MARK: - Playback Control
    
    /// Start speaking the given text
    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "No text to speak"
            return
        }
        
        currentText = text
        errorMessage = nil
        
        let request = SpeechRequest(
            text: text,
            voice: selectedVoice,
            settings: settings,
            source: .manualInput
        )
        
        speechService.speak(request)
        playbackState = .playing
    }
    
    /// Speak text from clipboard
    func speakFromClipboard() {
        if let text = clipboardService.getText() {
            speak(text)
        } else {
            errorMessage = "Clipboard is empty or contains non-text content"
        }
    }
    
    /// Speak selected text from any application
    func speakSelectedText() {
        // First, copy selected text to clipboard using Cmd+C
        clipboardService.copySelectedText { [weak self] success in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if success, let text = self?.clipboardService.getText() {
                    self?.speak(text)
                } else {
                    self?.errorMessage = "Could not get selected text"
                }
            }
        }
    }
    
    /// Pause current speech
    func pause() {
        speechService.pause()
        playbackState = .paused
    }
    
    /// Resume paused speech
    func resume() {
        speechService.resume()
        playbackState = .playing
    }
    
    /// Stop speech completely
    func stop() {
        speechService.stop()
        playbackState = .idle
        progress = nil
    }
    
    /// Toggle play/pause
    func togglePlayPause() {
        switch playbackState {
        case .idle:
            if !currentText.isEmpty {
                speak(currentText)
            }
        case .playing:
            pause()
        case .paused:
            resume()
        }
    }
    
    // MARK: - Settings
    
    /// Update speech rate
    func updateRate(_ rate: Float) {
        settings.rate = rate
        saveSettings()
    }
    
    /// Update pitch
    func updatePitch(_ pitch: Float) {
        settings.pitch = pitch
        saveSettings()
    }
    
    /// Update volume
    func updateVolume(_ volume: Float) {
        settings.volume = volume
        saveSettings()
    }
    
    /// Save current settings
    func saveSettings() {
        settingsStore.saveSettings(settings)
    }
    
    /// Reset settings to defaults
    func resetSettings() {
        settings = .default
        saveSettings()
    }
    
    // MARK: - Window Management
    
    /// Show the floating input window
    func showInputWindow() {
        isInputWindowVisible = true
        NSApp.activate(ignoringOtherApps: true)
        
        // Open the window using SwiftUI's openWindow
        if let window = NSApp.windows.first(where: { $0.title == "Text Input" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    /// Hide the floating input window
    func hideInputWindow() {
        isInputWindowVisible = false
    }
    
    // MARK: - Private Methods
    
    private func setupSpeechServiceCallbacks() {
        speechService.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.playbackState = state
            }
        }
        
        speechService.onProgress = { [weak self] progress in
            DispatchQueue.main.async {
                self?.progress = progress
            }
        }
        
        speechService.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error.localizedDescription
                self?.playbackState = .idle
            }
        }
    }
}
