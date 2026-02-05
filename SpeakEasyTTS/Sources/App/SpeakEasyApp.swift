// SpeakEasyApp.swift
// SpeakEasyTTS - A lightweight macOS menu bar text-to-speech app
//
// Created for demonstration purposes
// License: MIT

import SwiftUI
import AVFoundation

/// Main application entry point
/// Uses SwiftUI's App protocol with menu bar extra for status bar integration
@main
struct SpeakEasyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState.shared
    
    var body: some Scene {
        // Menu Bar Extra - the main interface
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: appState.playbackState == .playing ? "speaker.wave.3.fill" : "speaker.wave.2")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.window)
        
        // Settings Window
        Settings {
            SettingsView()
                .environment(appState)
        }
        
        // Floating Input Window (opened via menu or hotkey)
        Window("Text Input", id: "input-window") {
            InputWindowView()
                .environment(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// AppDelegate handles application lifecycle and global hotkey registration
class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var floatingOverlay: FloatingOverlayController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize hotkey manager for global shortcuts
        hotkeyManager = HotkeyManager.shared
        hotkeyManager?.registerGlobalHotkey()
        
        // Request accessibility permissions if needed
        checkAccessibilityPermissions()
        
        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize and show floating overlay
        floatingOverlay = FloatingOverlayController.shared
        floatingOverlay?.show()
        
        print("SpeakEasyTTS launched successfully")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up speech synthesis
        AppState.shared.speechService.stop()
        hotkeyManager?.unregisterGlobalHotkey()
    }
    
    /// Check and request accessibility permissions for global hotkeys
    private func checkAccessibilityPermissions() {
        // Check WITHOUT prompting first
        let checkOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let alreadyTrusted = AXIsProcessTrustedWithOptions(checkOptions as CFDictionary)
        
        if alreadyTrusted {
            print("Accessibility permissions already granted")
            return
        }
        
        // Check if we've already prompted the user this install
        let defaults = UserDefaults.standard
        let hasPromptedKey = "com.speakeasy.hasPromptedAccessibility"
        
        if defaults.bool(forKey: hasPromptedKey) {
            // Already prompted before, don't prompt again
            print("Accessibility permissions needed but already prompted user")
            return
        }
        
        // First time - prompt the user and remember
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
        defaults.set(true, forKey: hasPromptedKey)
        print("Accessibility permissions requested")
    }
}
