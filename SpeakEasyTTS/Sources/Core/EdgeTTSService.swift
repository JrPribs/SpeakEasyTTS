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
    private var audioPlayerDelegate: AudioPlayerDelegate?
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
        
        // Build arguments
        let pythonPath = EdgeTTSService.findPython3Path()
        let arguments = [
            "-m", "edge_tts",
            "-t", request.text,
            "-v", voiceId,
            "--rate", rateString,
            "--write-media", outputFile.path
        ]

        // Execute in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeEdgeTTS(pythonPath: pythonPath, arguments: arguments, outputFile: outputFile)
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
        audioPlayerDelegate = nil
        currentState = .idle
        onStateChange?(.idle)
    }
    
    // MARK: - Python Path Discovery

    private static var cachedPython3Path: String?

    static func findPython3Path() -> String {
        if let cached = cachedPython3Path { return cached }

        let candidates = [
            "/opt/homebrew/bin/python3",   // Apple Silicon Homebrew
            "/usr/local/bin/python3",       // Intel Homebrew
            "/opt/miniconda3/bin/python3",  // Conda
            "/usr/bin/python3",             // System Python
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) && hasEdgeTTS(pythonPath: path) {
                cachedPython3Path = path
                print("[EdgeTTS] Found python3 with edge-tts at: \(path)")
                return path
            }
        }

        // Fall back to PATH resolution via shell
        print("[EdgeTTS] No python3 with edge-tts found at known paths, falling back to PATH resolution")
        cachedPython3Path = "python3"
        return "python3"
    }

    /// Check if a given python3 binary has the edge-tts module installed
    static func hasEdgeTTS(pythonPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-c", "import edge_tts"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func executeEdgeTTS(pythonPath: String, arguments: [String], outputFile: URL) {
        print("[EdgeTTS] Executing: \(pythonPath) \(arguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        currentProcess = process

        do {
            try process.run()
            process.waitUntilExit()

            print("[EdgeTTS] Process exited with status: \(process.terminationStatus)")

            if process.terminationStatus == 0 {
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
            let delegate = AudioPlayerDelegate { [weak self] in
                self?.currentState = .idle
                self?.onStateChange?(.idle)
                self?.audioPlayerDelegate = nil
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: url)
            }
            audioPlayerDelegate = delegate
            audioPlayer?.delegate = delegate
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
    case pythonNotInstalled
    case edgeTTSNotInstalled
    case synthesisFailure(String)
    case networkError

    var errorDescription: String? {
        switch self {
        case .pythonNotInstalled:
            return "Python 3 is not installed. Please install Python 3 to use Edge TTS."
        case .edgeTTSNotInstalled:
            return "edge-tts is not installed. Run: pip3 install edge-tts"
        case .synthesisFailure(let message):
            return "Edge TTS synthesis failed: \(message)"
        case .networkError:
            return "Network error. Edge TTS requires an internet connection."
        }
    }
}

// MARK: - Edge TTS Availability Check

extension EdgeTTSService {
    /// Check if Edge TTS is available (Python 3 with edge-tts module installed)
    static func isAvailable() -> Bool {
        let pythonPath = findPython3Path()
        return hasEdgeTTS(pythonPath: pythonPath)
    }
}
