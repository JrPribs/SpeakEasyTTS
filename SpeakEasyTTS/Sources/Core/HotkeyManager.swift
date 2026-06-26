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
    private let hotkeySignature = OSType(0x53455454) // "SETT"

    struct HotkeyDefinition: Equatable {
        let action: ShortcutTriggerAction
        let shortcut: KeyboardShortcut
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
        if !hotkeyRefs.isEmpty {
            unregisterGlobalHotkey()
        }

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

        return failures
    }

    /// Unregister global hotkeys.
    func unregisterGlobalHotkey() {
        for hotkeyRef in hotkeyRefs.values {
            UnregisterEventHotKey(hotkeyRef)
        }
        hotkeyRefs.removeAll()

        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        print("HotkeyManager: Global hotkeys unregistered")
    }

    // MARK: - Private Methods

    static func hotkeyDefinitions(from shortcuts: ShortcutPreferences) -> [HotkeyDefinition] {
        [
            HotkeyDefinition(action: shortcuts.readSelection.action, shortcut: shortcuts.readSelection.shortcut),
            HotkeyDefinition(action: shortcuts.dictation.action, shortcut: shortcuts.dictation.shortcut)
        ]
    }

    private func installEventHandlerIfNeeded() -> Bool {
        guard eventHandler == nil else { return true }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
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

                if let userData {
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    manager.handleHotkey(id: hkID.id)
                }

                return noErr
            },
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandler
        )
        
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
            print("HotkeyManager: Global hotkey registered (\(hotkey.shortcut.displayName))")
            return nil
        } else {
            let message = "Could not register \(hotkey.action.displayName) shortcut \(hotkey.shortcut.displayName)."
            print("HotkeyManager: \(message) Status: \(status)")
            return HotkeyRegistrationFailure(message: message)
        }
    }

    private func handleHotkey(id: UInt32) {
        DispatchQueue.main.async {
            switch ShortcutTriggerAction(hotkeyID: id) {
            case .readSelection:
                print("HotkeyManager: Read selection hotkey pressed")
                AppState.shared.speakSelectedText()
            case .toggleDictation:
                print("HotkeyManager: Dictation hotkey pressed")
                AppState.shared.toggleDictation()
            case .none:
                print("HotkeyManager: Unknown hotkey id \(id)")
            }
        }
    }
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
