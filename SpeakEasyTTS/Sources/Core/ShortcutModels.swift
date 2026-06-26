// ShortcutModels.swift
// User-configurable keyboard shortcut models

import Carbon
import Foundation
import AppKit

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

    init(eventModifierFlags flags: NSEvent.ModifierFlags) {
        var modifiers: ShortcutModifiers = []
        let deviceFlags = flags.intersection(.deviceIndependentFlagsMask)

        if deviceFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if deviceFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if deviceFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if deviceFlags.contains(.control) {
            modifiers.insert(.control)
        }

        self = modifiers
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

    init(event: NSEvent) {
        self.init(
            keyCode: UInt32(event.keyCode),
            modifiers: ShortcutModifiers(eventModifierFlags: event.modifierFlags)
        )
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

    func matches(_ other: KeyboardShortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
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

enum ShortcutValidator {
    static func validationMessage(
        for shortcut: KeyboardShortcut,
        replacing action: ShortcutTriggerAction,
        preferences: ShortcutPreferences
    ) -> String? {
        if shortcut.keyCode == KeyCodeDisplayName.function {
            return "Function/Globe is hardware-dependent. Use Command, Option, or Control with a regular key."
        }

        let hasPrimaryModifier = shortcut.modifiers.contains(.command)
            || shortcut.modifiers.contains(.option)
            || shortcut.modifiers.contains(.control)
        guard hasPrimaryModifier else {
            return "Use Command, Option, or Control with a regular key."
        }

        if shortcut.keyCode == KeyCodeDisplayName.escape {
            return "Escape is reserved."
        }

        switch action {
        case .readSelection:
            if shortcut.matches(preferences.dictation.shortcut) {
                return "Already used by Dictation."
            }
        case .toggleDictation:
            if shortcut.matches(preferences.readSelection.shortcut) {
                return "Already used by Read Selected Text."
            }
        }

        return nil
    }
}

enum KeyCodeDisplayName {
    static let a: UInt32 = 0
    static let s: UInt32 = 1
    static let d: UInt32 = 2
    static let f: UInt32 = 3
    static let h: UInt32 = 4
    static let g: UInt32 = 5
    static let z: UInt32 = 6
    static let x: UInt32 = 7
    static let c: UInt32 = 8
    static let v: UInt32 = 9
    static let b: UInt32 = 11
    static let q: UInt32 = 12
    static let w: UInt32 = 13
    static let e: UInt32 = 14
    static let r: UInt32 = 15
    static let y: UInt32 = 16
    static let t: UInt32 = 17
    static let tab: UInt32 = 48
    static let space: UInt32 = 49
    static let delete: UInt32 = 51
    static let escape: UInt32 = 53
    static let function: UInt32 = UInt32(kVK_Function)

    private static let knownNames: [UInt32: String] = [
        a: "A",
        s: "S",
        d: "D",
        f: "F",
        h: "H",
        g: "G",
        z: "Z",
        x: "X",
        c: "C",
        v: "V",
        b: "B",
        q: "Q",
        w: "W",
        e: "E",
        r: "R",
        y: "Y",
        t: "T",
        tab: "Tab",
        space: "Space",
        delete: "Delete",
        escape: "Escape",
        function: "Function/Globe"
    ]

    static func name(for keyCode: UInt32) -> String {
        knownNames[keyCode] ?? "Key \(keyCode)"
    }
}
