import AVFoundation
import Speech
import Testing
@testable import SpeakEasyTTS

@Suite
struct PermissionServiceTests {
    @Test
    func deniedRuntimePermissionsIncludeRecoveryActions() {
        let service = PermissionService(
            accessibilityStatusProvider: { false },
            microphoneStatusProvider: { .denied },
            speechRecognitionStatusProvider: { .denied }
        )

        let diagnostics = service.diagnostics(aiProviderStatus: .notConfigured)

        let accessibility = diagnostics.diagnostic(.accessibility)
        let microphone = diagnostics.diagnostic(.microphone)
        let speechRecognition = diagnostics.diagnostic(.speechRecognition)

        #expect(accessibility?.state == .needsAction)
        #expect(accessibility?.recoveryAction == .requestAccessibilityPrompt(title: "Request Access"))

        #expect(microphone?.state == .denied)
        #expect(microphone?.recoveryAction?.title == "Open Settings")

        #expect(speechRecognition?.state == .denied)
        #expect(speechRecognition?.recoveryAction?.title == "Open Settings")
    }

    @Test
    func grantedRuntimePermissionsHaveNoRecoveryActions() {
        let service = PermissionService(
            accessibilityStatusProvider: { true },
            microphoneStatusProvider: { .authorized },
            speechRecognitionStatusProvider: { .authorized }
        )

        let diagnostics = service.diagnostics(aiProviderStatus: .notConfigured)

        #expect(diagnostics.diagnostic(.accessibility)?.state == .granted)
        #expect(diagnostics.diagnostic(.accessibility)?.recoveryAction == nil)
        #expect(diagnostics.diagnostic(.microphone)?.state == .granted)
        #expect(diagnostics.diagnostic(.microphone)?.recoveryAction == nil)
        #expect(diagnostics.diagnostic(.speechRecognition)?.state == .granted)
        #expect(diagnostics.diagnostic(.speechRecognition)?.recoveryAction == nil)
    }

    @Test
    func aiProviderNotConfiguredIsVisibleButOptional() {
        let service = PermissionService(
            accessibilityStatusProvider: { true },
            microphoneStatusProvider: { .authorized },
            speechRecognitionStatusProvider: { .authorized }
        )

        let diagnostic = service
            .diagnostics(aiProviderStatus: .notConfigured)
            .diagnostic(.aiProvider)

        #expect(diagnostic?.state == .optional)
        #expect(diagnostic?.recoveryAction == nil)
    }

    @Test
    func aiProviderErrorIncludesResetRecoveryAction() {
        let service = PermissionService(
            accessibilityStatusProvider: { true },
            microphoneStatusProvider: { .authorized },
            speechRecognitionStatusProvider: { .authorized }
        )

        let diagnostic = service
            .diagnostics(aiProviderStatus: AIProviderStatus(
                state: .error,
                providerID: "ollama",
                message: "Provider unavailable.",
                credentialStorage: .notRequired
            ))
            .diagnostic(.aiProvider)

        #expect(diagnostic?.state == .error)
        #expect(diagnostic?.detail == "Provider unavailable.")
        #expect(diagnostic?.recoveryAction == .resetAIProvider(title: "Reset State"))
    }
}

private extension Array where Element == PermissionDiagnostic {
    func diagnostic(_ id: PermissionDiagnosticID) -> PermissionDiagnostic? {
        first { $0.id == id }
    }
}
