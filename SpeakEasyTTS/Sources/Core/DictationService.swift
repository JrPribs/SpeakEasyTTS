// DictationService.swift
// Native speech-to-text capture using Apple's Speech framework.

import AVFoundation
import Foundation
import Speech

enum DictationError: LocalizedError {
    case speechPermissionDenied
    case microphonePermissionDenied
    case recognizerUnavailable
    case invalidAudioInput
    case audioEngineFailed(String)
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .speechPermissionDenied:
            return "Speech recognition permission is required for dictation."
        case .microphonePermissionDenied:
            return "Microphone permission is required for dictation."
        case .recognizerUnavailable:
            return "Speech recognition is not available right now."
        case .invalidAudioInput:
            return "No valid microphone input was found."
        case .audioEngineFailed(let message):
            return "Could not start microphone capture: \(message)"
        case .recognitionFailed(let message):
            return "Dictation failed: \(message)"
        }
    }
}

/// Captures microphone audio and streams low-processing speech-to-text results.
final class DictationService {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    private(set) var currentState: DictationState = .idle {
        didSet {
            guard currentState != oldValue else { return }
            onStateChange?(currentState)
        }
    }

    var onStateChange: ((DictationState) -> Void)?
    var onTranscript: ((String, Bool) -> Void)?
    var onError: ((Error) -> Void)?

    func start(localeIdentifier: String = Locale.current.identifier) {
        guard currentState != .recording else { return }

        stop()
        updateState(.authorizing)

        requestPermissions { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success:
                    self.startRecognition(localeIdentifier: localeIdentifier)
                case .failure(let error):
                    self.updateState(.idle)
                    self.onError?(error)
                }
            }
        }
    }

    func stop() {
        finishRecognition(cancelTask: true)
    }

    private func requestPermissions(completion: @escaping (Result<Void, Error>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { speechStatus in
            guard speechStatus == .authorized else {
                completion(.failure(DictationError.speechPermissionDenied))
                return
            }

            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    completion(.success(()))
                } else {
                    completion(.failure(DictationError.microphonePermissionDenied))
                }
            }
        }
    }

    private func startRecognition(localeIdentifier: String) {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable else {
            updateState(.idle)
            onError?(DictationError.recognizerUnavailable)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        if #available(macOS 13.0, *) {
            request.addsPunctuation = false
        }

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            updateState(.idle)
            onError?(DictationError.invalidAudioInput)
            return
        }

        self.recognizer = recognizer
        recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            DispatchQueue.main.async {
                if let result {
                    self.onTranscript?(self.verbatimTranscript(from: result), result.isFinal)

                    if result.isFinal {
                        self.finishRecognition(cancelTask: false)
                    }
                }

                if let error, self.currentState == .recording {
                    self.onError?(DictationError.recognitionFailed(error.localizedDescription))
                    self.finishRecognition(cancelTask: false)
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            updateState(.recording)
        } catch {
            finishRecognition(cancelTask: true)
            onError?(DictationError.audioEngineFailed(error.localizedDescription))
        }
    }

    private func finishRecognition(cancelTask: Bool) {
        let task = recognitionTask
        let request = recognitionRequest

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()

        recognitionTask = nil
        recognitionRequest = nil
        recognizer = nil

        updateState(.idle)

        if cancelTask {
            task?.cancel()
        }
    }

    private func updateState(_ state: DictationState) {
        currentState = state
    }

    private func verbatimTranscript(from result: SFSpeechRecognitionResult) -> String {
        let words = result.bestTranscription.segments.map(\.substring)
        if words.isEmpty {
            return result.bestTranscription.formattedString
        }
        return words.joined(separator: " ")
    }
}
