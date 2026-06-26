// ShortcutModels.swift
// User-configurable keyboard shortcut models

import Carbon
import Foundation

struct ShortcutModifiers: OptionSet, Codable, Equatable, Hashable {
    let rawValue: UInt32

    static let command = ShortcutModifiers(rawValue: UInt32(cmdKey))
    static let shift = ShortcutModifiers(rawValue: UInt32(shiftKey))
    static let option = ShortcutModifiers(rawValue: UInt32(optionKey))
    static let control = ShortcutModifiers(rawValue: UInt32(controlKey))

    static let displayOrder: [(ShortcutModifiers, String, String)] = [
        (.control, "Control", "^"),
        (.option, "Option", "⌥"),
        (.shift, "Shift", "⇧"),
        (.command, "Command", "⌘")
    ]

    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    var displayName: String {
        let names = Self.displayOrder.compactMap { modifier, name, _ in
            contains(modifier) ? name : nil
        }
        return names.joined(separator: "+")
    }

    var symbolDisplayName: String {
        Self.displayOrder.compactMap { modifier, _, symbol in
            contains(modifier) ? symbol : nil
        }.joined()
    }
}

struct KeyboardShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: ShortcutModifiers
    var displayName: String

    init(keyCode: UInt32, modifiers: ShortcutModifiers, displayName: String? = nil) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.displayName = displayName ?? Self.makeDisplayName(keyCode: keyCode, modifiers: modifiers)
    }

    static func makeDisplayName(keyCode: UInt32, modifiers: ShortcutModifiers) -> String {
        let keyName = KeyCodeDisplayName.name(for: keyCode)
        let modifierName = modifiers.displayName
        let symbolName = modifiers.symbolDisplayName

        if modifierName.isEmpty {
            return keyName
        }

        return "\(modifierName)+\(keyName) / \(symbolName)\(keyName)"
    }
}

enum ShortcutTriggerAction: String, Codable, CaseIterable, Equatable, Hashable {
    case toggleDictation
    case readSelection

    var displayName: String {
        switch self {
        case .toggleDictation:
            return "Dictation"
        case .readSelection:
            return "Read Selection"
        }
    }
}

enum DictationTriggerMode: String, Codable, CaseIterable, Equatable, Hashable {
    case toggle
    case holdToRecord
    case holdWithSpaceLatch

    var displayName: String {
        switch self {
        case .toggle:
            return "Toggle"
        case .holdToRecord:
            return "Hold to Record"
        case .holdWithSpaceLatch:
            return "Hold with Space Latch"
        }
    }
}

struct ShortcutDefinition: Codable, Equatable, Hashable, Identifiable {
    var action: ShortcutTriggerAction
    var shortcut: KeyboardShortcut
    var triggerMode: DictationTriggerMode?

    var id: ShortcutTriggerAction { action }

    static let defaultDictation = ShortcutDefinition(
        action: .toggleDictation,
        shortcut: KeyboardShortcut(keyCode: KeyCodeDisplayName.d, modifiers: .option),
        triggerMode: .toggle
    )

    static let defaultReadSelection = ShortcutDefinition(
        action: .readSelection,
        shortcut: KeyboardShortcut(keyCode: KeyCodeDisplayName.s, modifiers: .option),
        triggerMode: nil
    )
}

struct ShortcutPreferences: Codable, Equatable, Hashable {
    var dictation: ShortcutDefinition
    var readSelection: ShortcutDefinition

    static let `default` = ShortcutPreferences(
        dictation: .defaultDictation,
        readSelection: .defaultReadSelection
    )
}

enum KeyCodeDisplayName {
    static let s: UInt32 = 1
    static let d: UInt32 = 2
    static let space: UInt32 = 49

    private static let knownNames: [UInt32: String] = [
        s: "S",
        d: "D",
        space: "Space"
    ]

    static func name(for keyCode: UInt32) -> String {
        knownNames[keyCode] ?? "Key \(keyCode)"
    }
}
