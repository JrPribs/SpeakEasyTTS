// PermissionService.swift
// Centralized runtime permission diagnostics.

import AppKit
import AVFoundation
import Foundation
import Speech

enum PermissionDiagnosticID: String, CaseIterable, Equatable, Hashable {
    case accessibility
    case microphone
    case speechRecognition
    case aiProvider
}

enum PermissionDiagnosticState: Equatable, Hashable {
    case granted
    case needsAction
    case denied
    case restricted
    case optional
    case error

    var displayName: String {
        switch self {
        case .granted:
            return "Granted"
        case .needsAction:
            return "Needs Setup"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .optional:
            return "Optional"
        case .error:
            return "Error"
        }
    }

    var systemImage: String {
        switch self {
        case .granted:
            return "checkmark.circle.fill"
        case .needsAction:
            return "exclamationmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .restricted:
            return "lock.circle.fill"
        case .optional:
            return "minus.circle"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var needsRecoveryAction: Bool {
        switch self {
        case .granted, .optional:
            return false
        case .needsAction, .denied, .restricted, .error:
            return true
        }
    }
}

enum PermissionRecoveryAction: Equatable, Hashable {
    case openSystemSettings(title: String, url: URL)
    case requestAccessibilityPrompt(title: String)
    case resetAIProvider(title: String)

    var title: String {
        switch self {
        case .openSystemSettings(let title, _),
             .requestAccessibilityPrompt(let title),
             .resetAIProvider(let title):
            return title
        }
    }
}

struct PermissionDiagnostic: Identifiable, Equatable, Hashable {
    var id: PermissionDiagnosticID
    var title: String
    var detail: String
    var state: PermissionDiagnosticState
    var recoveryAction: PermissionRecoveryAction?
}

final class PermissionService {
    typealias AccessibilityStatusProvider = () -> Bool
    typealias MicrophoneStatusProvider = () -> AVAuthorizationStatus
    typealias SpeechRecognitionStatusProvider = () -> SFSpeechRecognizerAuthorizationStatus

    private let accessibilityStatusProvider: AccessibilityStatusProvider
    private let microphoneStatusProvider: MicrophoneStatusProvider
    private let speechRecognitionStatusProvider: SpeechRecognitionStatusProvider

    init(
        accessibilityStatusProvider: @escaping AccessibilityStatusProvider = { AXIsProcessTrusted() },
        microphoneStatusProvider: @escaping MicrophoneStatusProvider = {
            AVCaptureDevice.authorizationStatus(for: .audio)
        },
        speechRecognitionStatusProvider: @escaping SpeechRecognitionStatusProvider = {
            SFSpeechRecognizer.authorizationStatus()
        }
    ) {
        self.accessibilityStatusProvider = accessibilityStatusProvider
        self.microphoneStatusProvider = microphoneStatusProvider
        self.speechRecognitionStatusProvider = speechRecognitionStatusProvider
    }

    func hasAccessibilityPermissions() -> Bool {
        accessibilityStatusProvider()
    }

    func diagnostics(aiProviderStatus: AIProviderStatus) -> [PermissionDiagnostic] {
        [
            accessibilityDiagnostic(),
            microphoneDiagnostic(),
            speechRecognitionDiagnostic(),
            aiProviderDiagnostic(aiProviderStatus)
        ]
    }

    func requestAccessibilityPermissions() {
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
    }

    func openSystemSettings(for permissionID: PermissionDiagnosticID) {
        guard let url = systemSettingsURL(for: permissionID) else { return }

        NSWorkspace.shared.open(url)
    }

    func openSystemSettings(url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func accessibilityDiagnostic() -> PermissionDiagnostic {
        if hasAccessibilityPermissions() {
            return PermissionDiagnostic(
                id: .accessibility,
                title: "Accessibility",
                detail: "Global shortcuts, selected text readback, and text insertion are available.",
                state: .granted
            )
        }

        return PermissionDiagnostic(
            id: .accessibility,
            title: "Accessibility",
            detail: "Required for global shortcuts, reading selected text, and inserting dictated text.",
            state: .needsAction,
            recoveryAction: .requestAccessibilityPrompt(title: "Request Access")
        )
    }

    private func microphoneDiagnostic() -> PermissionDiagnostic {
        switch microphoneStatusProvider() {
        case .authorized:
            return PermissionDiagnostic(
                id: .microphone,
                title: "Microphone",
                detail: "Dictation can capture audio.",
                state: .granted
            )
        case .notDetermined:
            return PermissionDiagnostic(
                id: .microphone,
                title: "Microphone",
                detail: "macOS has not granted microphone access yet. Start dictation or open settings to allow it.",
                state: .needsAction,
                recoveryAction: systemSettingsAction(for: .microphone)
            )
        case .denied:
            return PermissionDiagnostic(
                id: .microphone,
                title: "Microphone",
                detail: "Dictation cannot record audio until microphone access is allowed.",
                state: .denied,
                recoveryAction: systemSettingsAction(for: .microphone)
            )
        case .restricted:
            return PermissionDiagnostic(
                id: .microphone,
                title: "Microphone",
                detail: "Microphone access is restricted by system policy.",
                state: .restricted,
                recoveryAction: systemSettingsAction(for: .microphone)
            )
        @unknown default:
            return PermissionDiagnostic(
                id: .microphone,
                title: "Microphone",
                detail: "Microphone permission status is unknown.",
                state: .needsAction,
                recoveryAction: systemSettingsAction(for: .microphone)
            )
        }
    }

    private func speechRecognitionDiagnostic() -> PermissionDiagnostic {
        switch speechRecognitionStatusProvider() {
        case .authorized:
            return PermissionDiagnostic(
                id: .speechRecognition,
                title: "Speech Recognition",
                detail: "Dictation can transcribe speech.",
                state: .granted
            )
        case .notDetermined:
            return PermissionDiagnostic(
                id: .speechRecognition,
                title: "Speech Recognition",
                detail: "macOS has not granted speech recognition access yet. Start dictation or open settings to allow it.",
                state: .needsAction,
                recoveryAction: systemSettingsAction(for: .speechRecognition)
            )
        case .denied:
            return PermissionDiagnostic(
                id: .speechRecognition,
                title: "Speech Recognition",
                detail: "Dictation cannot transcribe audio until speech recognition access is allowed.",
                state: .denied,
                recoveryAction: systemSettingsAction(for: .speechRecognition)
            )
        case .restricted:
            return PermissionDiagnostic(
                id: .speechRecognition,
                title: "Speech Recognition",
                detail: "Speech recognition access is restricted by system policy.",
                state: .restricted,
                recoveryAction: systemSettingsAction(for: .speechRecognition)
            )
        @unknown default:
            return PermissionDiagnostic(
                id: .speechRecognition,
                title: "Speech Recognition",
                detail: "Speech recognition permission status is unknown.",
                state: .needsAction,
                recoveryAction: systemSettingsAction(for: .speechRecognition)
            )
        }
    }

    private func aiProviderDiagnostic(_ status: AIProviderStatus) -> PermissionDiagnostic {
        switch status.state {
        case .configured:
            return PermissionDiagnostic(
                id: .aiProvider,
                title: "AI Provider",
                detail: "Ask AI is configured with \(status.providerID ?? "the selected provider").",
                state: .granted
            )
        case .notConfigured:
            return PermissionDiagnostic(
                id: .aiProvider,
                title: "AI Provider",
                detail: "Optional. Configure a provider only if you use Ask AI or AI summaries.",
                state: .optional
            )
        case .error:
            return PermissionDiagnostic(
                id: .aiProvider,
                title: "AI Provider",
                detail: status.message ?? "The saved AI provider state needs attention.",
                state: .error,
                recoveryAction: .resetAIProvider(title: "Reset State")
            )
        }
    }

    private func systemSettingsAction(for permissionID: PermissionDiagnosticID) -> PermissionRecoveryAction? {
        guard let url = systemSettingsURL(for: permissionID) else { return nil }

        return .openSystemSettings(title: "Open Settings", url: url)
    }

    private func systemSettingsURL(for permissionID: PermissionDiagnosticID) -> URL? {
        let pane: String
        switch permissionID {
        case .accessibility:
            pane = "Privacy_Accessibility"
        case .microphone:
            pane = "Privacy_Microphone"
        case .speechRecognition:
            pane = "Privacy_SpeechRecognition"
        case .aiProvider:
            return nil
        }

        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
    }
}
