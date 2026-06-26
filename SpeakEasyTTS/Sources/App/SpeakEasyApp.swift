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
            Image(systemName: menuBarIcon)
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

    private var menuBarIcon: String {
        if appState.dictationState != .idle {
            return appState.dictationState.systemImage
        }

        return appState.playbackState == .playing ? "speaker.wave.3.fill" : "speaker.wave.2"
    }
}

/// AppDelegate handles application lifecycle and global hotkey registration
class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private var floatingOverlay: FloatingOverlayController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize hotkey manager for global shortcuts
        hotkeyManager = HotkeyManager.shared
        hotkeyManager?.registerGlobalHotkey(shortcuts: AppState.shared.settings.shortcuts)
        
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
        AppState.shared.cancelDictation()
        hotkeyManager?.unregisterGlobalHotkey()
    }
    
    /// Check and request accessibility permissions for global hotkeys and text selection
    private func checkAccessibilityPermissions() {
        // Check WITHOUT prompting first
        let alreadyTrusted = AXIsProcessTrusted()
        
        if alreadyTrusted {
            print("✅ Accessibility permissions already granted")
            return
        }
        
        print("⚠️ Accessibility NOT trusted - will prompt user")
        
        // Show the system accessibility prompt
        // This opens System Preferences automatically
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
        
        // Note: We removed the redundant NSAlert - the system prompt is sufficient
        // The system prompt already explains what's needed and opens System Preferences
    }
}
