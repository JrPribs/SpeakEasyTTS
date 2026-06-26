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
    var hasSelectedText: Bool = false
    var dictationState: DictationState = .idle
    var dictationTriggerState: DictationTriggerState = .inactive
    var dictationTranscript: String = ""
    var activeInteractionSession: InteractionSession?

    var isDictationHeld: Bool {
        if case .holding = dictationTriggerState {
            return true
        }
        return false
    }

    var isDictationLatched: Bool {
        switch dictationTriggerState {
        case .holding(_, let isLatched):
            return isLatched
        case .latched:
            return true
        case .inactive:
            return false
        }
    }

    var canLatchDictationWithSpace: Bool {
        if case .holding(let canLatch, _) = dictationTriggerState {
            return canLatch
        }
        return false
    }
    
    // MARK: - Accessibility Permissions
    var hasAccessibilityPermissions: Bool = false
    private var permissionCheckTimer: Timer?
    private var selectionMonitorTimer: Timer?
    private var selectionPositiveStreak: Int = 0
    private var selectionNegativeStreak: Int = 0
    
    // MARK: - Services
    var speechService: SpeechService
    private var nativeSpeechService: NativeSpeechService
    private var edgeTTSService: EdgeTTSService
    let settingsStore: SettingsStore
    let voiceManager: VoiceManager
    let clipboardService: ClipboardService
    let claudeCodeService = ClaudeCodeService()
    let interactionCoordinator = InteractionCoordinator()
    private let dictationService = DictationService()
    
    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    private var hasInsertedCurrentDictation = false
    
    // MARK: - Initialization
    
    private init() {
        // Initialize settings first to know which engine to use
        let store = SettingsStore()
        let loadedSettings = store.loadMigratedSettings()
        
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
        setupInteractionCoordinatorCallbacks()
        setupSpeechServiceCallbacks()
        setupDictationServiceCallbacks()
        
        // Restore selected voice
        if let voiceId = settings.selectedVoiceId,
           let voice = availableVoices.first(where: { $0.id == voiceId }) {
            selectedVoice = voice
        } else {
            // Default to first English voice
            selectedVoice = availableVoices.first { $0.language.starts(with: "en") }
        }
        
        // Start accessibility permission monitoring
        startAccessibilityPermissionMonitoring()
        startSelectionMonitoring()
    }
    
    deinit {
        permissionCheckTimer?.invalidate()
        selectionMonitorTimer?.invalidate()
    }
    
    // MARK: - Accessibility Permission Management
    
    /// Start monitoring for accessibility permissions
    func startAccessibilityPermissionMonitoring() {
        // Check immediately
        checkAccessibilityPermissions()
        
        // Only start polling if not already granted
        if !hasAccessibilityPermissions {
            permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.checkAccessibilityPermissions()
            }
        }
    }
    
    /// Check current accessibility permission status
    func checkAccessibilityPermissions() {
        let granted = AXIsProcessTrusted()
        
        if granted != hasAccessibilityPermissions {
            hasAccessibilityPermissions = granted
            print("🔐 Accessibility permissions: \(granted ? "GRANTED ✅" : "NOT GRANTED ❌")")
            
            // Stop polling once permissions are granted
            if granted {
                permissionCheckTimer?.invalidate()
                permissionCheckTimer = nil
                registerConfiguredHotkeys()
            } else {
                updateSelectionState(false)
            }
        }
    }
    
    /// Request accessibility permissions (opens System Preferences)
    func requestAccessibilityPermissions() {
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
    }
    
    /// Open System Preferences to Accessibility settings
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Auto-Read Settings
    
    /// Update auto-read on selection setting
    func updateAutoReadOnSelection(_ enabled: Bool) {
        settings.autoReadOnSelection = enabled
        saveSettings()
    }
    
    /// Update auto-read delay
    func updateAutoReadDelay(_ delay: Double) {
        settings.autoReadDelay = delay
        saveSettings()
    }

    func updateShortcutPreferences(_ shortcuts: ShortcutPreferences) {
        settings.shortcuts = shortcuts
        saveSettings()
        if hasAccessibilityPermissions {
            registerConfiguredHotkeys()
        }
    }

    func updateDictationTriggerMode(_ mode: DictationTriggerMode) {
        var shortcuts = settings.shortcuts
        shortcuts.dictation.triggerMode = mode
        updateShortcutPreferences(shortcuts)
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
        if engine == .edgeTTS && !EdgeTTSService.isAvailable() {
            errorMessage = EdgeTTSError.edgeTTSNotInstalled.localizedDescription
            print("[TTS] Edge TTS unavailable; staying on \(settings.ttsEngine.rawValue)")
            return
        }

        speechService.stop()
        settings.ttsEngine = engine
        progress = nil
        
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
        speak(text, source: InteractionSource(kind: .manualText, text: text))
    }

    private func speak(_ text: String, source: InteractionSource) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "No text to speak"
            return
        }

        interactionCoordinator.beginReadback(source: source, text: text) { [weak self] text in
            self?.performSpeak(text)
        }
    }

    private func performSpeak(_ text: String) {
        if settings.ttsEngine == .edgeTTS && !EdgeTTSService.isAvailable() {
            print("[TTS] Edge TTS unavailable; falling back to native macOS speech")
            switchEngine(.native)
        }

        let engine = settings.ttsEngine == .edgeTTS ? "Edge TTS" : "Native"
        let voiceName = selectedVoice?.name ?? "default"
        print("[TTS] Speaking \(text.count) chars via \(engine), voice: \(voiceName)")

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

    /// Test audio pipeline using native TTS directly
    func testSpeech() {
        print("[TTS] Running native speech test")
        let testService = NativeSpeechService()
        let request = SpeechRequest(
            text: "Speech test successful.",
            voice: nil,
            settings: .default,
            source: .manualInput
        )
        testService.speak(request)
    }
    
    /// Speak text from clipboard
    func speakFromClipboard() {
        if let text = clipboardService.getText() {
            speak(text, source: InteractionSource(kind: .clipboard, text: text))
        } else {
            errorMessage = "Clipboard is empty or contains non-text content"
        }
    }
    
    /// Speak selected text from any application
    func speakSelectedText() {
        // Get selected text using the improved method
        clipboardService.getSelectedText { [weak self] text in
            if let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self?.speak(text, source: InteractionSource(kind: .selectedText, text: text))
            } else {
                self?.errorMessage = "No text selected. Please select some text first."
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
        interactionCoordinator.cancelActiveSession(
            message: "Speech stopped.",
            performCancel: { [weak self] in
                self?.performStopSpeech()
            }
        )
    }

    private func performStopSpeech() {
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

    // MARK: - Dictation Control

    /// Toggle native speech-to-text dictation. Completed text is pasted into the last focused app.
    func toggleDictation() {
        dictationTriggerState = .inactive
        switch dictationState {
        case .idle:
            startDictation()
        case .authorizing, .recording:
            stopDictationAndInsert()
        }
    }

    /// Start verbatim dictation without AI rewriting or cleanup.
    func startDictation() {
        guard dictationState == .idle else { return }

        interactionCoordinator.startDictation(triggerState: dictationTriggerState) { [weak self] in
            self?.performStartDictation()
        }
    }

    private func performStartDictation() {
        guard dictationState == .idle else { return }

        if playbackState != .idle {
            performStopSpeech()
        }

        clipboardService.trackFrontmostApp()
        dictationTranscript = ""
        hasInsertedCurrentDictation = false
        errorMessage = nil

        dictationService.start()
    }

    /// Stop dictation and insert the captured transcript into the focused app.
    func stopDictationAndInsert() {
        let textToInsert = dictationTranscript
        dictationTriggerState = .inactive
        interactionCoordinator.finishDictation(transcript: textToInsert) { [weak self] in
            self?.performStopDictationAndInsert(textToInsert)
        }
    }

    private func performStopDictationAndInsert(_ textToInsert: String) {
        dictationService.stop()
        insertDictatedText(textToInsert)
    }

    func beginHoldDictation(canLatch: Bool) {
        if dictationTriggerState == .latched {
            stopDictationAndInsert()
            return
        }

        guard dictationState == .idle else { return }
        dictationTriggerState = .holding(canLatch: canLatch, isLatched: false)
        startDictation()
    }

    func latchHoldDictation() {
        guard dictationState != .idle else { return }

        if case .holding(true, let isLatched) = dictationTriggerState {
            dictationTriggerState = .holding(canLatch: true, isLatched: !isLatched)
            interactionCoordinator.updateDictationTriggerState(dictationTriggerState)
        }
    }

    /// Finish a hold-to-record session. If release happens during authorization, cancel without inserting.
    func finishHoldDictation() {
        if case .latched = dictationTriggerState {
            return
        }

        if case .holding(_, true) = dictationTriggerState {
            dictationTriggerState = .latched
            interactionCoordinator.updateDictationTriggerState(dictationTriggerState)
            return
        }

        guard case .holding = dictationTriggerState else { return }
        dictationTriggerState = .inactive

        switch dictationState {
        case .recording:
            stopDictationAndInsert()
        case .authorizing:
            cancelDictation()
        case .idle:
            break
        }
    }

    /// Stop dictation without inserting text.
    func cancelDictation() {
        dictationTriggerState = .inactive
        interactionCoordinator.cancelActiveSession(
            message: "Dictation cancelled.",
            performCancel: { [weak self] in
                self?.performCancelDictation()
            }
        )
    }

    private func performCancelDictation() {
        dictationService.stop()
        dictationTranscript = ""
        hasInsertedCurrentDictation = false
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
    
    // MARK: - Claude Code Plan Reading

    /// Auto-find and read the most recent Claude Code plan
    func speakRecentClaudePlan() {
        guard let url = claudeCodeService.findRecentPlan() else {
            errorMessage = "No Claude Code plan files found in ~/.claude/projects/"
            return
        }
        guard let content = claudeCodeService.readPlan(at: url) else {
            errorMessage = "Could not read plan file"
            return
        }
        let processed = claudeCodeService.preprocessForSpeech(content)
        speak(processed, source: InteractionSource(kind: .file, text: processed, url: url))
    }

    /// Show file picker and read the selected plan file
    func speakClaudePlanFromPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        panel.title = "Select Claude Code Plan"
        panel.message = "Choose a plan or conversation file to read aloud"

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            if let content = claudeCodeService.readPlan(at: url) {
                let processed = claudeCodeService.preprocessForSpeech(content)
                speak(processed, source: InteractionSource(kind: .file, text: processed, url: url))
            }
        }
    }

    // MARK: - Private Methods

    private func startSelectionMonitoring() {
        selectionMonitorTimer?.invalidate()
        selectionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.refreshSelectedTextState()
        }
        refreshSelectedTextState()
    }
    
    private var lastLoggedTrustedState: Bool?

    private func refreshSelectedTextState() {
        clipboardService.trackFrontmostApp()
        let currentlyTrusted = AXIsProcessTrusted()
        if currentlyTrusted != hasAccessibilityPermissions {
            hasAccessibilityPermissions = currentlyTrusted
            if currentlyTrusted {
                registerConfiguredHotkeys()
            } else {
                permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    self?.checkAccessibilityPermissions()
                }
            }
        }

        // Log AX trust state changes (not every poll)
        if lastLoggedTrustedState != currentlyTrusted {
            lastLoggedTrustedState = currentlyTrusted
            if !currentlyTrusted {
                print("AX not trusted - selection detection disabled")
            }
        }

        guard hasAccessibilityPermissions else {
            selectionPositiveStreak = 0
            selectionNegativeStreak = 0
            updateSelectionState(false)
            return
        }
        
        let hasSelectionNow = clipboardService.hasSelectedText()
        
        if hasSelectionNow {
            selectionPositiveStreak += 1
            selectionNegativeStreak = 0
            if selectionPositiveStreak >= 1 {
                updateSelectionState(true)
            }
        } else {
            selectionNegativeStreak += 1
            selectionPositiveStreak = 0
            if selectionNegativeStreak >= 2 {
                updateSelectionState(false)
            }
        }
    }
    
    private func updateSelectionState(_ newValue: Bool) {
        if hasSelectedText != newValue {
            hasSelectedText = newValue
        }
    }

    private func registerConfiguredHotkeys() {
        let failures = HotkeyManager.shared.registerGlobalHotkey(shortcuts: settings.shortcuts)
        if !failures.isEmpty {
            errorMessage = failures.map(\.message).joined(separator: "\n")
        }
    }

    private func setupInteractionCoordinatorCallbacks() {
        interactionCoordinator.onSessionChange = { [weak self] session in
            DispatchQueue.main.async {
                self?.activeInteractionSession = session
            }
        }
    }

    private func setupSpeechServiceCallbacks() {
        speechService.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.playbackState = state
                self?.interactionCoordinator.updatePlaybackState(state)
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
                self?.interactionCoordinator.failActiveSession(
                    reason: .serviceError,
                    message: error.localizedDescription
                )
            }
        }
    }

    private func setupDictationServiceCallbacks() {
        dictationService.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }

                self.dictationState = state
                self.interactionCoordinator.updateDictationState(
                    state,
                    triggerState: self.dictationTriggerState,
                    transcript: self.dictationTranscript
                )
            }
        }

        dictationService.onTranscript = { [weak self] transcript, isFinal in
            DispatchQueue.main.async {
                guard let self else { return }

                self.dictationTranscript = transcript
                self.interactionCoordinator.updateDictationTranscript(transcript)

                if isFinal {
                    self.insertDictatedText(transcript)
                }
            }
        }

        dictationService.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error.localizedDescription
                self?.dictationState = .idle
                self?.dictationTriggerState = .inactive
                self?.interactionCoordinator.failActiveSession(
                    reason: .serviceError,
                    message: error.localizedDescription
                )
            }
        }
    }

    private func insertDictatedText(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            errorMessage = "No dictation text captured."
            interactionCoordinator.failActiveSession(
                reason: .emptyInput,
                message: "No dictation text captured."
            )
            return
        }
        guard !hasInsertedCurrentDictation else { return }

        hasInsertedCurrentDictation = true
        clipboardService.insertTextIntoLastFocusedApp(normalized) { [weak self] didInsert in
            guard let self else { return }

            if didInsert {
                self.dictationTranscript = normalized
                self.interactionCoordinator.completeActiveSession(transcript: normalized)
            } else {
                self.errorMessage = "Could not insert dictated text. Click into a text field and try again."
                self.hasInsertedCurrentDictation = false
                self.interactionCoordinator.failActiveSession(
                    reason: .destinationUnavailable,
                    message: "Could not insert dictated text. Click into a text field and try again."
                )
            }
        }
    }
}
