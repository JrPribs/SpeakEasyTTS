// FloatingOverlayWindow.swift
// A floating, always-on-top, non-activating overlay window for SpeakEasyTTS
//
// Inspired by Wispr Flow's floating bar implementation
// Key features:
// - Stays on top of all windows (including fullscreen)
// - Does NOT steal focus from other apps
// - Draggable by clicking anywhere on the background
// - Positions at bottom center of screen by default

import SwiftUI
import AppKit

/// Controller class to manage the floating overlay panel
final class FloatingOverlayController: ObservableObject {
    static let shared = FloatingOverlayController()
    
    private var panel: FloatingOverlayPanel?
    @Published var isVisible: Bool = false
    
    private init() {}
    
    /// Show the floating overlay
    func show() {
        if panel == nil {
            createPanel()
        }
        
        panel?.orderFront(nil)
        isVisible = true
    }
    
    /// Hide the floating overlay
    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }
    
    /// Toggle visibility
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    /// Position the panel at the bottom center of the screen
    func positionAtBottomCenter() {
        guard let panel = panel,
              let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let panelFrame = panel.frame
        
        let x = screenFrame.midX - (panelFrame.width / 2)
        let y = screenFrame.minY + 20 // 20pt from bottom
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func createPanel() {
        let contentView = FloatingOverlayView()
            .environment(AppState.shared)
        
        let panel = FloatingOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 44),
            backing: .buffered,
            defer: false
        )
        
        panel.contentView = NSHostingView(rootView: contentView)
        self.panel = panel
        
        // Position at bottom center after creating
        positionAtBottomCenter()
    }
}

/// Custom NSPanel subclass for the floating overlay
/// NSPanel is ideal for floating palettes and utility windows
final class FloatingOverlayPanel: NSPanel {
    
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask = [],
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        // Style mask configuration:
        // - .nonactivatingPanel: Won't activate the app or steal focus
        // - .fullSizeContentView: Content extends to fill entire window
        // - .borderless: No window chrome (we'll draw our own UI)
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: backingStoreType,
            defer: flag
        )
        
        configurePanel()
    }
    
    private func configurePanel() {
        // MARK: - Window Level
        // Use .statusBar level to float above most windows
        // Options: .floating < .statusBar < .popUpMenu < .screenSaver
        self.level = .statusBar
        
        // MARK: - Floating Behavior
        // isFloatingPanel makes the panel behave as a floating palette
        self.isFloatingPanel = true
        
        // MARK: - Collection Behavior
        // .canJoinAllSpaces: Appears on all virtual desktops/spaces
        // .fullScreenAuxiliary: Can appear alongside fullscreen apps
        // .stationary: Doesn't move with Mission Control gestures
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        // MARK: - Appearance
        // Transparent background - we'll draw our own pill shape
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        
        // Hide the titlebar completely
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        
        // Hide traffic light buttons
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        // MARK: - Interaction
        // Allow dragging by clicking anywhere on the window background
        self.isMovableByWindowBackground = true
        
        // Don't release when closed - user may open/close frequently
        self.isReleasedWhenClosed = false
        
        // Ignore mouse events that should pass through to windows below
        // (handled by the SwiftUI view for specific areas)
        self.ignoresMouseEvents = false
        
        // MARK: - Animation
        self.animationBehavior = .utilityWindow
    }
    
    // MARK: - Focus Behavior
    
    /// Allow the panel to receive key events when needed (e.g., for button clicks)
    /// but this won't make it steal focus proactively
    override var canBecomeKey: Bool {
        return true
    }
    
    /// Prevent the panel from becoming the main window
    /// This ensures it stays as a utility overlay
    override var canBecomeMain: Bool {
        return false
    }
    
    // MARK: - Mouse Tracking
    
    /// Ensure mouse events are handled properly for hover effects
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        // The SwiftUI view will handle hover state
    }
}

// MARK: - Environment Key for Floating Overlay

struct FloatingOverlayControllerKey: EnvironmentKey {
    static let defaultValue = FloatingOverlayController.shared
}

extension EnvironmentValues {
    var floatingOverlay: FloatingOverlayController {
        get { self[FloatingOverlayControllerKey.self] }
        set { self[FloatingOverlayControllerKey.self] = newValue }
    }
}
