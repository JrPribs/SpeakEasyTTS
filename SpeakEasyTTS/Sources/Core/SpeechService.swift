// SpeechService.swift
// Speech synthesis service protocol and implementations

import Foundation
import AVFoundation

// MARK: - SpeechService Protocol

/// Protocol defining the interface for text-to-speech services
protocol SpeechService: AnyObject {
    /// Current playback state
    var currentState: PlaybackState { get }
    
    /// Callback for state changes
    var onStateChange: ((PlaybackState) -> Void)? { get set }
    
    /// Callback for progress updates
    var onProgress: ((SpeechProgress) -> Void)? { get set }
    
    /// Callback for errors
    var onError: ((Error) -> Void)? { get set }
    
    /// Start speaking the given request
    func speak(_ request: SpeechRequest)
    
    /// Pause current speech
    func pause()
    
    /// Resume paused speech
    func resume()
    
    /// Stop speech completely
    func stop()
}

// MARK: - NativeSpeechService

/// Native macOS TTS implementation using AVSpeechSynthesizer
final class NativeSpeechService: NSObject, SpeechService {
    // MARK: - Properties
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var currentText: String = ""
    private var startTime: Date?
    
    var currentState: PlaybackState = .idle
    var onStateChange: ((PlaybackState) -> Void)?
    var onProgress: ((SpeechProgress) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - SpeechService Implementation
    
    func speak(_ request: SpeechRequest) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        currentText = request.text
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: request.text)
        
        // Configure voice
        if let voice = request.voice?.avVoice {
            utterance.voice = voice
        } else {
            // Default to system voice or first English voice
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        // Configure speech parameters
        // AVSpeechUtterance rate: 0.0 (slowest) to 1.0 (fastest), default ~0.5
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (request.settings.rate * 2)
        utterance.pitchMultiplier = request.settings.pitch
        utterance.volume = request.settings.volume
        
        // Small delays for natural speech
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        
        currentUtterance = utterance
        startTime = Date()
        
        // Start speaking
        synthesizer.speak(utterance)
        
        currentState = .playing
        onStateChange?(.playing)
    }
    
    func pause() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .word)
        currentState = .paused
        onStateChange?(.paused)
    }
    
    func resume() {
        guard synthesizer.isPaused else { return }
        synthesizer.continueSpeaking()
        currentState = .playing
        onStateChange?(.playing)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        currentUtterance = nil
        currentText = ""
        startTime = nil
        currentState = .idle
        onStateChange?(.idle)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension NativeSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        currentState = .playing
        onStateChange?(.playing)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        currentState = .idle
        onStateChange?(.idle)
        currentUtterance = nil
        startTime = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        currentState = .paused
        onStateChange?(.paused)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        currentState = .playing
        onStateChange?(.playing)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        currentState = .idle
        onStateChange?(.idle)
        currentUtterance = nil
        startTime = nil
    }
    
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        // Calculate progress
        let text = utterance.speechString
        let totalLength = text.count
        let currentPosition = characterRange.location + characterRange.length
        let progressValue = Double(currentPosition) / Double(totalLength)
        
        // Get current word
        let nsString = text as NSString
        let currentWord = nsString.substring(with: characterRange)
        
        // Calculate elapsed time
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? 0
        
        // Estimate remaining time
        let estimatedTotal = progressValue > 0 ? elapsed / progressValue : 0
        let remaining = max(0, estimatedTotal - elapsed)
        
        let progress = SpeechProgress(
            currentWord: currentWord,
            currentCharacterRange: nil,
            progress: progressValue,
            elapsedTime: elapsed,
            estimatedRemainingTime: remaining
        )
        
        onProgress?(progress)
    }
}

// MARK: - Speech Errors

enum SpeechError: LocalizedError {
    case noTextProvided
    case voiceNotAvailable
    case synthesisFailure(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .noTextProvided:
            return "No text provided for speech synthesis"
        case .voiceNotAvailable:
            return "Selected voice is not available"
        case .synthesisFailure(let message):
            return "Speech synthesis failed: \(message)"
        case .networkError:
            return "Network error occurred"
        }
    }
}
