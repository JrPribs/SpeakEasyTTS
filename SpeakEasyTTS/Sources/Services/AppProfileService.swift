// AppProfileService.swift
// Resolves app-specific text interaction preferences.

import Foundation

final class AppProfileService {
    private let genericProfile: AppProfile
    private let profiles: [AppProfile]

    init(
        profiles: [AppProfile] = [],
        genericProfile: AppProfile = .generic
    ) {
        self.genericProfile = genericProfile
        self.profiles = profiles
    }

    func profile(for appContext: AppContext?) -> AppProfile {
        profiles.first { profile in
            profile.matches(appContext)
        } ?? genericProfile
    }

    func preferredSourceRequests(for appContext: AppContext?) -> [TextSourceRequest] {
        profile(for: appContext).preferredReadStrategies.map(sourceRequest(for:))
    }

    func preferredDestination(for appContext: AppContext?) -> InteractionDestination {
        let profile = profile(for: appContext)

        switch profile.preferredWriteStrategy {
        case .pasteboard:
            return InteractionDestination(
                kind: .targetApp,
                appContext: appContext,
                writeMode: profile.preferredWriteMode
            )
        }
    }

    private func sourceRequest(for strategy: TextReadStrategy) -> TextSourceRequest {
        switch strategy {
        case .selectedText:
            return .selectedText
        case .clipboard:
            return .clipboard
        case .focusedTextField:
            return .focusedTextField
        }
    }
}
