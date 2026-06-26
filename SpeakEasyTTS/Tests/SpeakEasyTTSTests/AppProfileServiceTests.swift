import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct AppProfileServiceTests {
    @Test
    func genericProfileDefinesDefaultReadAndWritePreferences() {
        let profile = AppProfile.generic

        #expect(profile.id == "generic")
        #expect(profile.bundleIdentifiers.isEmpty)
        #expect(profile.preferredReadStrategies == [.selectedText, .clipboard])
        #expect(profile.preferredWriteStrategy == .pasteboard)
        #expect(profile.preferredWriteMode == .insert)
    }

    @Test
    func genericProfileIsUsedByDefault() {
        let service = AppProfileService()

        #expect(service.profile(for: nil) == .generic)
        #expect(service.profile(for: app(bundleIdentifier: "com.example.Unknown")) == .generic)
    }

    @Test
    func matchingBundleIdentifierReturnsSpecificProfile() {
        let terminalProfile = AppProfile(
            id: "terminal",
            displayName: "Terminal",
            bundleIdentifiers: ["com.apple.Terminal"],
            preferredReadStrategies: [.clipboard],
            preferredWriteMode: .append
        )
        let service = AppProfileService(profiles: [terminalProfile])

        #expect(service.profile(for: app(bundleIdentifier: "com.apple.Terminal")) == terminalProfile)
    }

    @Test
    func profileCanSpecifyPreferredReadAndWriteStrategies() {
        let editorProfile = AppProfile(
            id: "editor",
            displayName: "Editor",
            bundleIdentifiers: ["com.example.Editor"],
            preferredReadStrategies: [.focusedTextField, .selectedText],
            preferredWriteStrategy: .pasteboard,
            preferredWriteMode: .replaceSelection
        )
        let service = AppProfileService(profiles: [editorProfile])

        #expect(service.preferredSourceRequests(for: app(bundleIdentifier: "com.example.Editor")) == [
            .focusedTextField,
            .selectedText
        ])
        #expect(service.preferredDestination(for: app(bundleIdentifier: "com.example.Editor")) == InteractionDestination(
            kind: .targetApp,
            appContext: app(bundleIdentifier: "com.example.Editor"),
            writeMode: .replaceSelection
        ))
    }

    @Test
    func unmatchedAppUsesGenericDestinationPreferences() {
        let context = app(bundleIdentifier: "com.example.Unknown")
        let service = AppProfileService()

        #expect(service.preferredSourceRequests(for: context) == [.selectedText, .clipboard])
        #expect(service.preferredDestination(for: context) == InteractionDestination(
            kind: .targetApp,
            appContext: context,
            writeMode: .insert
        ))
    }

    private func app(bundleIdentifier: String) -> AppContext {
        AppContext(
            bundleIdentifier: bundleIdentifier,
            appName: "Test App",
            processIdentifier: 42,
            capturedAt: Date(timeIntervalSince1970: 1_000)
        )
    }
}
