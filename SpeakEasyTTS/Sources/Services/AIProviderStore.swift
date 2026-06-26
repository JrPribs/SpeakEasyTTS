// AIProviderStore.swift
// Persists non-secret AI provider status.

import Foundation

enum AICredentialStorage: Codable, Equatable, Hashable {
    case keychain(service: String, account: String)

    static let defaultKeychain = AICredentialStorage.keychain(
        service: "com.speakeasy.ai-provider",
        account: "default"
    )

    var displayName: String {
        switch self {
        case .keychain:
            return "macOS Keychain"
        }
    }
}

enum AIProviderConfigurationState: String, Codable, CaseIterable, Equatable, Hashable {
    case notConfigured
    case configured
    case error

    var displayName: String {
        switch self {
        case .notConfigured:
            return "Not Configured"
        case .configured:
            return "Configured"
        case .error:
            return "Error"
        }
    }

    var systemImage: String {
        switch self {
        case .notConfigured:
            return "minus.circle"
        case .configured:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

struct AIProviderStatus: Codable, Equatable, Hashable {
    var state: AIProviderConfigurationState
    var providerID: String?
    var message: String?
    var credentialStorage: AICredentialStorage

    static let notConfigured = AIProviderStatus(
        state: .notConfigured,
        providerID: nil,
        message: nil,
        credentialStorage: .defaultKeychain
    )

    init(
        state: AIProviderConfigurationState,
        providerID: String? = nil,
        message: String? = nil,
        credentialStorage: AICredentialStorage = .defaultKeychain
    ) {
        self.state = state
        self.providerID = providerID
        self.message = message
        self.credentialStorage = credentialStorage
    }
}

final class AIProviderStore {
    static let storageKey = "com.speakeasy.ai-provider.status"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadStatus() -> AIProviderStatus {
        guard let data = defaults.data(forKey: Self.storageKey),
              let status = try? JSONDecoder().decode(AIProviderStatus.self, from: data) else {
            return .notConfigured
        }

        return status
    }

    func markConfigured(providerID: String) {
        saveStatus(AIProviderStatus(
            state: .configured,
            providerID: providerID,
            credentialStorage: .defaultKeychain
        ))
    }

    func markError(providerID: String?, message: String) {
        saveStatus(AIProviderStatus(
            state: .error,
            providerID: providerID,
            message: message,
            credentialStorage: .defaultKeychain
        ))
    }

    func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func saveStatus(_ status: AIProviderStatus) {
        guard let data = try? JSONEncoder().encode(status) else { return }

        defaults.set(data, forKey: Self.storageKey)
    }
}
