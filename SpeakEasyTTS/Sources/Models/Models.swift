// Models.swift
// Data models for SpeakEasyTTS

import Foundation
import AVFoundation

// MARK: - DictationState

/// Represents the current state of speech-to-text capture.
enum DictationState: Equatable {
    case idle
    case authorizing
    case recording

    var displayName: String {
        switch self {
        case .idle: return "Dictation Ready"
        case .authorizing: return "Requesting Access"
        case .recording: return "Listening"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "mic"
        case .authorizing: return "lock.open"
        case .recording: return "mic.fill"
        }
    }
}

// MARK: - PlaybackState

/// Represents the current state of speech playback
enum PlaybackState: Equatable {
    case idle
    case playing
    case paused
    
    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .playing: return "Speaking"
        case .paused: return "Paused"
        }
    }
    
    var systemImage: String {
        switch self {
        case .idle: return "speaker.wave.2"
        case .playing: return "speaker.wave.3.fill"
        case .paused: return "pause.fill"
        }
    }
}

// MARK: - Voice

/// Wrapper around AVSpeechSynthesisVoice with additional metadata
struct Voice: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let language: String
    let quality: VoiceQuality
    
    enum VoiceQuality: String, Codable {
        case `default` = "Default"
        case enhanced = "Enhanced"
        case premium = "Premium"
    }
    
    /// Create from AVSpeechSynthesisVoice
    init(from avVoice: AVSpeechSynthesisVoice) {
        self.id = avVoice.identifier
        self.name = avVoice.name
        self.language = avVoice.language
        
        // Determine quality based on voice characteristics
        switch avVoice.quality {
        case .enhanced:
            self.quality = .enhanced
        case .premium:
            self.quality = .premium
        default:
            self.quality = .default
        }
    }
    
    /// Manual initializer for custom voices
    init(id: String, name: String, language: String, quality: VoiceQuality) {
        self.id = id
        self.name = name
        self.language = language
        self.quality = quality
    }
    
    /// Display name with quality indicator
    var displayName: String {
        switch quality {
        case .default:
            return name
        case .enhanced:
            return "\(name) (Enhanced)"
        case .premium:
            return "\(name) (Premium)"
        }
    }
    
    /// Get the corresponding AVSpeechSynthesisVoice
    var avVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(identifier: id)
    }
}

// MARK: - SpeechSettings

/// User preferences for speech synthesis
struct SpeechSettings: Codable, Equatable {
    var selectedVoiceId: String?
    var rate: Float
    var pitch: Float
    var volume: Float
    var ttsEngine: TTSEngine
    var autoReadOnSelection: Bool
    var autoReadDelay: Double
    
    /// TTS engine selection
    enum TTSEngine: String, Codable, CaseIterable {
        case native = "Native (macOS)"
        case edgeTTS = "Edge TTS (Online)"
        
        var description: String {
            switch self {
            case .native:
                return "Uses macOS built-in voices. Works offline."
            case .edgeTTS:
                return "Uses Microsoft Edge TTS. Higher quality, requires internet."
            }
        }
    }
    
    /// Default settings
    static let `default` = SpeechSettings(
        selectedVoiceId: "en-US-GuyNeural",  // Default to Edge TTS voice
        rate: 0.5,      // AVSpeechUtteranceDefaultSpeechRate
        pitch: 1.0,     // Normal pitch
        volume: 1.0,    // Full volume
        ttsEngine: .edgeTTS,  // Default to Edge TTS for better quality
        autoReadOnSelection: false,  // Disabled by default
        autoReadDelay: 0.8  // 0.8 second debounce delay
    )
    
    /// Rate as words per minute (approximate)
    var wordsPerMinute: Int {
        // AVSpeechUtterance rate 0.0-1.0 maps roughly to 100-300 WPM
        return Int(100 + (rate * 400))
    }
    
    /// Rate display string
    var rateDisplayString: String {
        String(format: "%.1fx", rate * 2)
    }
}

// MARK: - SpeechRequest

/// Represents a request to speak text
struct SpeechRequest {
    let text: String
    let voice: Voice?
    let settings: SpeechSettings
    let source: Source
    
    enum Source {
        case clipboard
        case manualInput
        case selectedText
        case url(URL)
    }
    
    init(text: String, voice: Voice? = nil, settings: SpeechSettings = .default, source: Source = .manualInput) {
        self.text = text
        self.voice = voice
        self.settings = settings
        self.source = source
    }
}

// MARK: - SpeechProgress

/// Progress information during speech playback
struct SpeechProgress {
    let currentWord: String
    let currentCharacterRange: Range<String.Index>?
    let progress: Double // 0.0 to 1.0
    let elapsedTime: TimeInterval
    let estimatedRemainingTime: TimeInterval?
}
