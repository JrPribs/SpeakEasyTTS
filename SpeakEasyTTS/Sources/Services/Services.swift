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
    
    /// Get selected text from the frontmost application using Accessibility API
    /// This reads the selection DIRECTLY without copying to clipboard
    func getSelectedText(completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let selectedText = self.getSelectedTextViaAccessibility()
            
            DispatchQueue.main.async {
                if let text = selectedText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    completion(text)
                } else {
                    // Fall back to clipboard copy method
                    self.copySelectedTextThenRead(completion: completion)
                }
            }
        }
    }
    
    /// Use Accessibility API to read selected text directly (no clipboard modification)
    private func getSelectedTextViaAccessibility() -> String? {
        // Get the focused application
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let pid = focusedApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get the focused UI element
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard focusResult == .success, let element = focusedElement else {
            // Try to get the focused window's first responder
            return getSelectedTextFromWindow(appElement: appElement)
        }
        
        // Try to get selected text from the focused element
        return getSelectedTextFromElement(element as! AXUIElement)
    }
    
    /// Get selected text from a specific AXUIElement
    private func getSelectedTextFromElement(_ element: AXUIElement) -> String? {
        // Try kAXSelectedTextAttribute first (most direct)
        var selectedText: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        
        if result == .success, let text = selectedText as? String, !text.isEmpty {
            return text
        }
        
        // Try kAXSelectedTextRangeAttribute with kAXValueAttribute
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        
        if rangeResult == .success {
            var fullValue: CFTypeRef?
            let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &fullValue)
            
            if valueResult == .success, let fullText = fullValue as? String {
                // Extract the selected portion using the range
                var range = CFRange()
                if AXValueGetValue(selectedRange as! AXValue, .cfRange, &range) {
                    let start = fullText.index(fullText.startIndex, offsetBy: range.location, limitedBy: fullText.endIndex) ?? fullText.startIndex
                    let end = fullText.index(start, offsetBy: range.length, limitedBy: fullText.endIndex) ?? fullText.endIndex
                    let selected = String(fullText[start..<end])
                    if !selected.isEmpty {
                        return selected
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Try to get selected text from the focused window
    private func getSelectedTextFromWindow(appElement: AXUIElement) -> String? {
        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        guard windowResult == .success, let window = focusedWindow else {
            return nil
        }
        
        // Try to find text areas in the window
        return findSelectedTextInChildren(window as! AXUIElement, depth: 0)
    }
    
    /// Recursively search for selected text in UI element children
    private func findSelectedTextInChildren(_ element: AXUIElement, depth: Int) -> String? {
        // Limit recursion depth
        guard depth < 10 else { return nil }
        
        // Check this element
        if let text = getSelectedTextFromElement(element), !text.isEmpty {
            return text
        }
        
        // Check children
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let childArray = children as? [AXUIElement] else {
            return nil
        }
        
        for child in childArray {
            if let text = findSelectedTextInChildren(child, depth: depth + 1) {
                return text
            }
        }
        
        return nil
    }
    
    /// Check if there's currently selected text (quick check without getting the text)
    /// Uses multiple methods for better compatibility
    func hasSelectedText() -> Bool {
        // First check if we have accessibility permissions
        if !AXIsProcessTrusted() {
            // Can't check selection without accessibility - return false
            // The app will prompt user if needed
            return false
        }
        
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        let pid = focusedApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Try to get the focused element
        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if focusResult == .success, let element = focusedElement {
            // Check for selected text
            var selectedText: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
            
            if result == .success, let text = selectedText as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            
            // Try selected text range as fallback
            var selectedRange: CFTypeRef?
            let rangeResult = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
            
            if rangeResult == .success, let range = selectedRange {
                var cfRange = CFRange()
                if AXValueGetValue(range as! AXValue, .cfRange, &cfRange) {
                    return cfRange.length > 0
                }
            }
        }
        
        // Fallback: Try getting selection from system-wide element
        let systemWide = AXUIElementCreateSystemWide()
        var systemFocused: CFTypeRef?
        let systemResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &systemFocused)
        
        if systemResult == .success, let element = systemFocused {
            var selectedText: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText)
            
            if result == .success, let text = selectedText as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
        }
        
        return false
    }
    
    /// Check if accessibility permissions are granted
    func hasAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Copy selected text using CGEvent simulation then read clipboard (fallback)
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
