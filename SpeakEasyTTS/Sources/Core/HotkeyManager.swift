// HotkeyManager.swift
// Global hotkey registration and handling

import Foundation
import Carbon
import AppKit

/// Manages global keyboard shortcuts using Carbon Event Manager
/// Default hotkey: Cmd+Shift+S to read selected text
final class HotkeyManager {
    // MARK: - Singleton
    static let shared = HotkeyManager()
    
    // MARK: - Properties
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyID = EventHotKeyID()
    
    // Hotkey configuration
    private let defaultKeyCode: UInt32 = 1  // 'S' key
    private let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)
    
    // Callback for when hotkey is pressed
    var onHotkeyPressed: (() -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        // Set up default callback
        onHotkeyPressed = { [weak self] in
            self?.handleHotkey()
        }
    }
    
    deinit {
        unregisterGlobalHotkey()
    }
    
    // MARK: - Public Methods
    
    /// Register the global hotkey (Cmd+Shift+S)
    func registerGlobalHotkey() {
        // Check accessibility permissions first
        guard AXIsProcessTrusted() else {
            print("HotkeyManager: Accessibility permissions not granted")
            return
        }
        
        // Set up hotkey ID
        hotkeyID.signature = OSType(0x53455454) // "SETT" in hex
        hotkeyID.id = 1
        
        // Set up event type spec
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // Install event handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                // Get the hotkey ID from the event
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
                
                // Call the handler
                if let manager = userData?.assumingMemoryBound(to: HotkeyManager.self).pointee {
                    manager.onHotkeyPressed?()
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
            return
        }
        
        // Register the hotkey
        let registerStatus = RegisterEventHotKey(
            defaultKeyCode,
            defaultModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if registerStatus == noErr {
            print("HotkeyManager: Global hotkey registered (Cmd+Shift+S)")
        } else {
            print("HotkeyManager: Failed to register hotkey: \(registerStatus)")
        }
    }
    
    /// Unregister the global hotkey
    func unregisterGlobalHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        
        print("HotkeyManager: Global hotkey unregistered")
    }
    
    // MARK: - Private Methods
    
    /// Handle hotkey press - read selected text
    private func handleHotkey() {
        print("HotkeyManager: Hotkey pressed")
        
        DispatchQueue.main.async {
            AppState.shared.speakSelectedText()
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
        // Check for Cmd+Shift+S
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommandShift = modifiers.contains([.command, .shift])
        let isKeyS = event.keyCode == 1 // 'S' key
        
        if isCommandShift && isKeyS {
            DispatchQueue.main.async {
                AppState.shared.speakSelectedText()
            }
        }
    }
}
