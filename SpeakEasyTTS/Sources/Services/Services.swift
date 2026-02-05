// Services.swift
// Service classes for settings, voice discovery, and clipboard

import Foundation
import AVFoundation
import AppKit

// MARK: - SettingsStore

/// Handles persistence of user settings using UserDefaults
final class SettingsStore {
    private let defaults = UserDefaults.standard
    private let settingsKey = "com.speakeasy.settings"
    
    /// Load saved settings or return defaults
    func loadSettings() -> SpeechSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(SpeechSettings.self, from: data) else {
            return .default
        }
        return settings
    }
    
    /// Save settings to UserDefaults
    func saveSettings(_ settings: SpeechSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }
    
    /// Reset to default settings
    func resetSettings() {
        defaults.removeObject(forKey: settingsKey)
    }
}

// MARK: - VoiceManager

/// Discovers and manages available TTS voices
final class VoiceManager {
    /// Discover all available system voices
    func discoverVoices() -> [Voice] {
        let avVoices = AVSpeechSynthesisVoice.speechVoices()
        
        return avVoices
            .map { Voice(from: $0) }
            .sorted { v1, v2 in
                // Sort by: language, then quality (premium first), then name
                if v1.language != v2.language {
                    // English first
                    if v1.language.starts(with: "en") && !v2.language.starts(with: "en") {
                        return true
                    }
                    if !v1.language.starts(with: "en") && v2.language.starts(with: "en") {
                        return false
                    }
                    return v1.language < v2.language
                }
                if v1.quality != v2.quality {
                    return v1.quality.sortOrder < v2.quality.sortOrder
                }
                return v1.name < v2.name
            }
    }
    
    /// Get voices filtered by language
    func voices(forLanguage language: String) -> [Voice] {
        discoverVoices().filter { $0.language.starts(with: language) }
    }
    
    /// Get English voices only
    func englishVoices() -> [Voice] {
        voices(forLanguage: "en")
    }
    
    /// Get the default voice for a language
    func defaultVoice(forLanguage language: String = "en-US") -> Voice? {
        if let avVoice = AVSpeechSynthesisVoice(language: language) {
            return Voice(from: avVoice)
        }
        return nil
    }
    
    /// Preview a voice with sample text
    func previewVoice(_ voice: Voice, completion: @escaping () -> Void) {
        let synthesizer = AVSpeechSynthesizer()
        let sampleText = "Hello! This is a preview of the \(voice.name) voice."
        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.voice = voice.avVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        // Use a delegate to know when preview finishes
        let delegate = PreviewDelegate(completion: completion)
        synthesizer.delegate = delegate
        
        // Keep delegate alive
        objc_setAssociatedObject(synthesizer, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        
        synthesizer.speak(utterance)
    }
}

// Helper delegate for voice preview
private class PreviewDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        completion()
    }
}

// Extension for voice quality sorting
extension Voice.VoiceQuality {
    var sortOrder: Int {
        switch self {
        case .premium: return 0
        case .enhanced: return 1
        case .default: return 2
        }
    }
}

// MARK: - ClipboardService

/// Handles clipboard operations and selected text retrieval
final class ClipboardService {
    private let pasteboard = NSPasteboard.general
    
    /// Get text from clipboard
    func getText() -> String? {
        return pasteboard.string(forType: .string)
    }
    
    /// Set text to clipboard
    func setText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    /// Get selected text from the frontmost application
    /// Uses multiple methods for maximum compatibility
    func getSelectedText(completion: @escaping (String?) -> Void) {
        // Method 1: Try AppleScript first (most reliable for getting selection)
        getSelectedTextViaAppleScript { [weak self] text in
            if let text = text, !text.isEmpty {
                completion(text)
                return
            }
            
            // Method 2: Fall back to simulating Cmd+C
            self?.copySelectedTextThenRead(completion: completion)
        }
    }
    
    /// Use AppleScript to get selected text from System Events
    private func getSelectedTextViaAppleScript(completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            tell application "System Events"
                keystroke "c" using {command down}
                delay 0.1
            end tell
            delay 0.1
            the clipboard as text
            """
            
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let result = appleScript.executeAndReturnError(&error)
                
                DispatchQueue.main.async {
                    if error == nil, let text = result.stringValue {
                        completion(text)
                    } else {
                        completion(nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    /// Copy selected text using CGEvent simulation then read clipboard
    private func copySelectedTextThenRead(completion: @escaping (String?) -> Void) {
        // Store current clipboard content
        let previousContent = getText()
        let previousChangeCount = pasteboard.changeCount
        
        // Clear clipboard
        pasteboard.clearContents()
        
        // Simulate Cmd+C using CGEvent
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'C' key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        
        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
        
        // Wait for the copy to complete, then check clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            // Check if clipboard changed
            if self.pasteboard.changeCount != previousChangeCount,
               let newContent = self.getText(),
               !newContent.isEmpty {
                completion(newContent)
            } else {
                // Restore previous content if copy failed
                if let previous = previousContent {
                    self.setText(previous)
                }
                completion(nil)
            }
        }
    }
    
    /// Legacy method - simulates copy then calls completion with success/failure
    func copySelectedText(completion: @escaping (Bool) -> Void) {
        getSelectedText { text in
            completion(text != nil)
        }
    }
    
    /// Monitor clipboard for changes
    func startMonitoring(onChange: @escaping (String) -> Void) -> Timer {
        var lastChangeCount = pasteboard.changeCount
        
        return Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.pasteboard.changeCount != lastChangeCount {
                lastChangeCount = self.pasteboard.changeCount
                if let text = self.getText() {
                    onChange(text)
                }
            }
        }
    }
}
