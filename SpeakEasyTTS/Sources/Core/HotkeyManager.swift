// HotkeyManager.swift
// Global hotkey registration and handling

import Foundation
import Carbon
import AppKit

/// Manages global keyboard shortcuts using Carbon Event Manager
/// Default hotkeys: Option+S to read selected text, Option+D to toggle dictation.
final class HotkeyManager {
    // MARK: - Singleton
    static let shared = HotkeyManager()
    
    // MARK: - Properties
    private var eventHandler: EventHandlerRef?
    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var registeredHotkeys: [UInt32: HotkeyDefinition] = [:]
    private var globalAuxiliaryMonitor: Any?
    private var localAuxiliaryMonitor: Any?
    private var currentShortcuts: ShortcutPreferences = .default
    private let hotkeySignature = OSType(0x53455454) // "SETT"

    struct HotkeyDefinition: Equatable {
        let action: ShortcutTriggerAction
        let shortcut: KeyboardShortcut
        let triggerMode: DictationTriggerMode?
    }

    // MARK: - Initialization
    
    private init() {}
    
    deinit {
        unregisterGlobalHotkey()
    }
    
    // MARK: - Public Methods
    
    /// Register global hotkeys from current shortcut preferences.
    @discardableResult
    func registerGlobalHotkey(shortcuts: ShortcutPreferences = .default) -> [HotkeyRegistrationFailure] {
        if !hotkeyRefs.isEmpty || globalAuxiliaryMonitor != nil || localAuxiliaryMonitor != nil {
            unregisterGlobalHotkey()
        }
        currentShortcuts = shortcuts

        guard AXIsProcessTrusted() else {
            print("HotkeyManager: Accessibility permissions not granted")
            return []
        }

        guard installEventHandlerIfNeeded() else {
            return [HotkeyRegistrationFailure(message: "Could not install the global shortcut handler.")]
        }

        var failures: [HotkeyRegistrationFailure] = []
        for hotkey in Self.hotkeyDefinitions(from: shortcuts) {
            if let failure = registerHotkey(hotkey) {
                failures.append(failure)
            }
        }

        if Self.requiresAuxiliaryMonitoring(for: shortcuts) {
            installAuxiliaryMonitor()
        }

        return failures
    }

    /// Unregister global hotkeys.
    func unregisterGlobalHotkey() {
        for hotkeyRef in hotkeyRefs.values {
            UnregisterEventHotKey(hotkeyRef)
        }
        hotkeyRefs.removeAll()
        registeredHotkeys.removeAll()

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        removeAuxiliaryMonitor()

        print("HotkeyManager: Global hotkeys unregistered")
    }

    // MARK: - Private Methods

    static func hotkeyDefinitions(from shortcuts: ShortcutPreferences) -> [HotkeyDefinition] {
        [
            HotkeyDefinition(
                action: shortcuts.readSelection.action,
                shortcut: shortcuts.readSelection.shortcut,
                triggerMode: shortcuts.readSelection.triggerMode
            ),
            HotkeyDefinition(
                action: shortcuts.dictation.action,
                shortcut: shortcuts.dictation.shortcut,
                triggerMode: shortcuts.dictation.triggerMode
            )
        ]
    }

    static func requiresAuxiliaryMonitoring(for shortcuts: ShortcutPreferences) -> Bool {
        shortcuts.dictation.triggerMode != .toggle
    }

    static func shouldLatchFromAuxiliaryShortcut(_ shortcut: KeyboardShortcut, shortcuts: ShortcutPreferences) -> Bool {
        guard shortcuts.dictation.triggerMode == .holdWithSpaceLatch else { return false }
        guard shortcut.keyCode == KeyCodeDisplayName.space else { return false }

        return shortcut.modifiers.isEmpty || shortcut.modifiers == shortcuts.dictation.shortcut.modifiers
    }

    static func command(for hotkey: HotkeyDefinition, eventKind: HotkeyEventKind) -> HotkeyCommand? {
        switch hotkey.action {
        case .readSelection:
            return eventKind == .pressed ? .readSelection : nil
        case .toggleDictation:
            let mode = hotkey.triggerMode ?? .toggle
            switch (mode, eventKind) {
            case (.toggle, .pressed):
                return .toggleDictation
            case (.holdToRecord, .pressed), (.holdWithSpaceLatch, .pressed):
                return .startHoldDictation(canLatch: mode == .holdWithSpaceLatch)
            case (.holdToRecord, .released), (.holdWithSpaceLatch, .released):
                return .finishHoldDictation
            default:
                return nil
            }
        }
    }

    private func installEventHandlerIfNeeded() -> Bool {
        guard eventHandler == nil else { return true }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let status = eventTypes.withUnsafeMutableBufferPointer { eventTypes in
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData -> OSStatus in
                    var hkID = EventHotKeyID()
                    GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hkID
                    )

                    if let userData, let eventKind = HotkeyEventKind(carbonEventKind: GetEventKind(event)) {
                        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                        manager.handleHotkey(id: hkID.id, eventKind: eventKind)
                    }

                    return noErr
                },
                eventTypes.count,
                eventTypes.baseAddress,
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                &eventHandler
            )
        }
        
        guard status == noErr else {
            print("HotkeyManager: Failed to install event handler: \(status)")
            return false
        }

        return true
    }

    private func registerHotkey(_ hotkey: HotkeyDefinition) -> HotkeyRegistrationFailure? {
        var hotkeyID = EventHotKeyID()
        hotkeyID.signature = hotkeySignature
        hotkeyID.id = hotkey.action.hotkeyID

        var hotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.shortcut.keyCode,
            hotkey.shortcut.modifiers.rawValue,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr, let hotkeyRef {
            hotkeyRefs[hotkey.action.hotkeyID] = hotkeyRef
            registeredHotkeys[hotkey.action.hotkeyID] = hotkey
            print("HotkeyManager: Global hotkey registered (\(hotkey.shortcut.displayName))")
            return nil
        } else {
            let message = "Could not register \(hotkey.action.displayName) shortcut \(hotkey.shortcut.displayName)."
            print("HotkeyManager: \(message) Status: \(status)")
            return HotkeyRegistrationFailure(message: message)
        }
    }

    private func handleHotkey(id: UInt32, eventKind: HotkeyEventKind) {
        DispatchQueue.main.async {
            guard let hotkey = self.registeredHotkeys[id],
                  let command = Self.command(for: hotkey, eventKind: eventKind) else {
                return
            }

            switch command {
            case .readSelection:
                print("HotkeyManager: Read selection hotkey pressed")
                AppState.shared.speakSelectedText()
            case .toggleDictation:
                print("HotkeyManager: Dictation hotkey pressed")
                AppState.shared.toggleDictation()
            case .startHoldDictation(let canLatch):
                print("HotkeyManager: Hold dictation started")
                AppState.shared.beginHoldDictation(canLatch: canLatch)
            case .finishHoldDictation:
                print("HotkeyManager: Hold dictation released")
                AppState.shared.finishHoldDictation()
            }
        }
    }

    private func installAuxiliaryMonitor() {
        removeAuxiliaryMonitor()

        globalAuxiliaryMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleAuxiliaryEvent(event)
        }
        localAuxiliaryMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleAuxiliaryEvent(event)
            return event
        }
    }

    private func removeAuxiliaryMonitor() {
        if let globalAuxiliaryMonitor {
            NSEvent.removeMonitor(globalAuxiliaryMonitor)
            self.globalAuxiliaryMonitor = nil
        }
        if let localAuxiliaryMonitor {
            NSEvent.removeMonitor(localAuxiliaryMonitor)
            self.localAuxiliaryMonitor = nil
        }
    }

    private func handleAuxiliaryEvent(_ event: NSEvent) {
        guard !event.isARepeat else { return }

        let shortcut = KeyboardShortcut(event: event)

        DispatchQueue.main.async {
            if shortcut.keyCode == KeyCodeDisplayName.escape, shortcut.modifiers.isEmpty,
               AppState.shared.dictationState != .idle {
                AppState.shared.cancelDictation()
                return
            }

            if Self.shouldLatchFromAuxiliaryShortcut(shortcut, shortcuts: self.currentShortcuts) {
                AppState.shared.latchHoldDictation()
            }
        }
    }
}

enum HotkeyEventKind: Equatable {
    case pressed
    case released

    init?(carbonEventKind: UInt32) {
        switch carbonEventKind {
        case UInt32(kEventHotKeyPressed):
            self = .pressed
        case UInt32(kEventHotKeyReleased):
            self = .released
        default:
            return nil
        }
    }
}

enum HotkeyCommand: Equatable {
    case readSelection
    case toggleDictation
    case startHoldDictation(canLatch: Bool)
    case finishHoldDictation
}

struct HotkeyRegistrationFailure: Equatable {
    let message: String
}

private extension ShortcutTriggerAction {
    var hotkeyID: UInt32 {
        switch self {
        case .readSelection:
            return 1
        case .toggleDictation:
            return 2
        }
    }

    init?(hotkeyID: UInt32) {
        switch hotkeyID {
        case 1:
            self = .readSelection
        case 2:
            self = .toggleDictation
        default:
            return nil
        }
    }
}

// MARK: - Alternative: NSEvent Global Monitor

/// Alternative hotkey implementation using NSEvent
/// This is simpler but requires the app to be in the foreground for some events
final class NSEventHotkeyManager {
    static let shared = NSEventHotkeyManager()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private init() {}
    
    /// Start monitoring for hotkey
    func startMonitoring() {
        // Global monitor (requires accessibility permissions)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Local monitor (for when app is active)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    /// Handle key event
    private func handleKeyEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isOptionOnly = modifiers == .option
        let isKeyS = event.keyCode == 1 // S
        let isKeyD = event.keyCode == 2 // D
        
        if isOptionOnly && isKeyS {
            DispatchQueue.main.async {
                AppState.shared.speakSelectedText()
            }
        } else if isOptionOnly && isKeyD {
            DispatchQueue.main.async {
                AppState.shared.toggleDictation()
            }
        }
    }
}
