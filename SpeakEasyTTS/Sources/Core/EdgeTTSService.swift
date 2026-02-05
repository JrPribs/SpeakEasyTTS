// EdgeTTSService.swift
// Microsoft Edge TTS integration (optional, requires internet)

import Foundation
import AVFoundation

/// Edge TTS service implementation using node-edge-tts
/// Provides high-quality neural voices via Microsoft's TTS service
/// Requires Node.js and node-edge-tts to be installed
final class EdgeTTSService: SpeechService {
    // MARK: - Properties
    
    private var audioPlayer: AVAudioPlayer?
    private var currentProcess: Process?
    private var tempDirectory: URL
    
    var currentState: PlaybackState = .idle
    var onStateChange: ((PlaybackState) -> Void)?
    var onProgress: ((SpeechProgress) -> Void)?
    var onError: ((Error) -> Void)?
    
    // Available Edge TTS voices (English)
    static let availableVoices: [EdgeVoice] = [
        EdgeVoice(id: "en-US-AriaNeural", name: "Aria", language: "en-US", gender: .female),
        EdgeVoice(id: "en-US-GuyNeural", name: "Guy", language: "en-US", gender: .male),
        EdgeVoice(id: "en-US-JennyNeural", name: "Jenny", language: "en-US", gender: .female),
        EdgeVoice(id: "en-US-ChristopherNeural", name: "Christopher", language: "en-US", gender: .male),
        EdgeVoice(id: "en-US-EricNeural", name: "Eric", language: "en-US", gender: .male),
        EdgeVoice(id: "en-US-MichelleNeural", name: "Michelle", language: "en-US", gender: .female),
        EdgeVoice(id: "en-GB-SoniaNeural", name: "Sonia", language: "en-GB", gender: .female),
        EdgeVoice(id: "en-GB-RyanNeural", name: "Ryan", language: "en-GB", gender: .male),
        EdgeVoice(id: "en-AU-NatashaNeural", name: "Natasha", language: "en-AU", gender: .female),
        EdgeVoice(id: "en-AU-WilliamNeural", name: "William", language: "en-AU", gender: .male),
    ]
    
    // MARK: - Initialization
    
    init() {
        // Create temp directory for audio files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpeakEasyTTS", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    deinit {
        stop()
        // Clean up temp files
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    // MARK: - SpeechService Implementation
    
    func speak(_ request: SpeechRequest) {
        // Stop any current playback
        stop()
        
        // Generate unique filename
        let outputFile = tempDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        
        // Determine voice
        let voiceId = request.voice?.id ?? "en-US-AriaNeural"
        
        // Calculate rate adjustment
        let ratePercent = Int((request.settings.rate - 0.5) * 100)
        let rateString = ratePercent >= 0 ? "+\(ratePercent)%" : "\(ratePercent)%"
        
        // Build command
        let command = buildEdgeTTSCommand(
            text: request.text,
            voice: voiceId,
            rate: rateString,
            outputFile: outputFile.path
        )
        
        // Execute in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeEdgeTTS(command: command, outputFile: outputFile)
        }
        
        currentState = .playing
        onStateChange?(.playing)
    }
    
    func pause() {
        audioPlayer?.pause()
        currentState = .paused
        onStateChange?(.paused)
    }
    
    func resume() {
        audioPlayer?.play()
        currentState = .playing
        onStateChange?(.playing)
    }
    
    func stop() {
        currentProcess?.terminate()
        currentProcess = nil
        audioPlayer?.stop()
        audioPlayer = nil
        currentState = .idle
        onStateChange?(.idle)
    }
    
    // MARK: - Private Methods
    
    private func buildEdgeTTSCommand(text: String, voice: String, rate: String, outputFile: String) -> String {
        // Escape text for shell
        let escapedText = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "\\'")
        
        // Use Python edge-tts (Homebrew/pip Python, not Xcode's)
        return """
        /usr/local/bin/python3 -m edge_tts -t '\(escapedText)' -v '\(voice)' --rate '\(rate)' --write-media '\(outputFile)'
        """
    }
    
    private func executeEdgeTTS(command: String, outputFile: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        currentProcess = process
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                // Play the generated audio
                DispatchQueue.main.async { [weak self] in
                    self?.playAudioFile(outputFile)
                }
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                
                DispatchQueue.main.async { [weak self] in
                    self?.onError?(EdgeTTSError.synthesisFailure(errorMessage))
                    self?.currentState = .idle
                    self?.onStateChange?(.idle)
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(error)
                self?.currentState = .idle
                self?.onStateChange?(.idle)
            }
        }
    }
    
    private func playAudioFile(_ url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = AudioPlayerDelegate { [weak self] in
                self?.currentState = .idle
                self?.onStateChange?(.idle)
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: url)
            }
            audioPlayer?.play()
        } catch {
            onError?(error)
            currentState = .idle
            onStateChange?(.idle)
        }
    }
}

// MARK: - Edge Voice Model

struct EdgeVoice: Identifiable {
    let id: String
    let name: String
    let language: String
    let gender: Gender
    
    enum Gender {
        case male
        case female
    }
    
    var displayName: String {
        "\(name) (\(language))"
    }
}

// MARK: - Audio Player Delegate

private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

// MARK: - Edge TTS Errors

enum EdgeTTSError: LocalizedError {
    case nodeNotInstalled
    case packageNotInstalled
    case synthesisFailure(String)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .nodeNotInstalled:
            return "Node.js is not installed. Please install Node.js to use Edge TTS."
        case .packageNotInstalled:
            return "node-edge-tts is not installed. Run: npm install -g node-edge-tts"
        case .synthesisFailure(let message):
            return "Edge TTS synthesis failed: \(message)"
        case .networkError:
            return "Network error. Edge TTS requires an internet connection."
        }
    }
}

// MARK: - Edge TTS Availability Check

extension EdgeTTSService {
    /// Check if Edge TTS is available (Node.js and package installed)
    static func isAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["npx"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
