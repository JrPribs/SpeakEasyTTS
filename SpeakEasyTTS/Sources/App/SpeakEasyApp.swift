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
    
    /// Check and request accessibility permissions for global hotkeys and text selection
    private func checkAccessibilityPermissions() {
        // Check WITHOUT prompting first
        let alreadyTrusted = AXIsProcessTrusted()
        
        if alreadyTrusted {
            print("Accessibility permissions already granted")
            return
        }
        
        // Not trusted - show the system prompt
        // This will open System Preferences to the Accessibility pane
        let promptOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(promptOptions as CFDictionary)
        print("Accessibility permissions requested - user needs to enable in System Preferences")
        
        // Show an alert explaining why we need permissions
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Access Required"
            alert.informativeText = "SpeakEasy needs Accessibility permissions to detect selected text in other apps.\n\n1. Open System Preferences > Privacy & Security > Accessibility\n2. Find SpeakEasyTTS and enable it\n3. Restart the app"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Later")
            
            if alert.runModal() == .alertFirstButtonReturn {
                // Open System Preferences to Accessibility
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }
}
