// AppProfile.swift
// Per-app preferences for reading and writing text.

import Foundation

enum TextReadStrategy: String, Codable, CaseIterable, Equatable, Hashable {
    case selectedText
    case clipboard
    case focusedTextField
}

enum TextWriteStrategy: String, Codable, CaseIterable, Equatable, Hashable {
    case pasteboard
}

struct AppProfile: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var displayName: String
    var bundleIdentifiers: [String]
    var preferredReadStrategies: [TextReadStrategy]
    var preferredWriteStrategy: TextWriteStrategy
    var preferredWriteMode: TextWriteMode

    static let generic = AppProfile(
        id: "generic",
        displayName: "Generic App",
        bundleIdentifiers: [],
        preferredReadStrategies: [.selectedText, .clipboard],
        preferredWriteStrategy: .pasteboard,
        preferredWriteMode: .insert
    )

    init(
        id: String,
        displayName: String,
        bundleIdentifiers: [String] = [],
        preferredReadStrategies: [TextReadStrategy] = AppProfile.generic.preferredReadStrategies,
        preferredWriteStrategy: TextWriteStrategy = AppProfile.generic.preferredWriteStrategy,
        preferredWriteMode: TextWriteMode = AppProfile.generic.preferredWriteMode
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifiers = bundleIdentifiers
        self.preferredReadStrategies = preferredReadStrategies
        self.preferredWriteStrategy = preferredWriteStrategy
        self.preferredWriteMode = preferredWriteMode
    }

    func matches(_ appContext: AppContext?) -> Bool {
        guard let bundleIdentifier = appContext?.bundleIdentifier else {
            return false
        }

        return bundleIdentifiers.contains(bundleIdentifier)
    }
}
