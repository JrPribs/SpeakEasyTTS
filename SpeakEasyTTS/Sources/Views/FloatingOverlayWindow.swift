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
import QuartzCore

/// Controller class to manage the floating overlay panel
final class FloatingOverlayController: ObservableObject {
    static let shared = FloatingOverlayController()
    
    private var panel: FloatingOverlayPanel?
    private var dragStartMouseLocation: NSPoint?
    private var dragStartPanelOrigin: NSPoint?
    private var screenTrackingTimer: Timer?
    private var currentScreenID: UInt32?
    @Published var isVisible: Bool = false
    
    private init() {}
    
    /// Show the floating overlay
    func show() {
        if panel == nil {
            createPanel()
        }
        
        panel?.orderFront(nil)
        isVisible = true
        startScreenTracking()
    }
    
    /// Hide the floating overlay
    func hide() {
        stopScreenTracking()
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
    
    /// Position the panel at the bottom center of a screen
    func positionAtBottomCenter(of screen: NSScreen? = nil, animated: Bool = false) {
        guard let panel = panel,
              let targetScreen = screen ?? NSScreen.main else { return }

        let screenFrame = targetScreen.visibleFrame
        let panelFrame = panel.frame

        let x = screenFrame.midX - (panelFrame.width / 2)
        let y = screenFrame.minY + 20 // 20pt from bottom
        let origin = NSPoint(x: x, y: y)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrameOrigin(origin)
            }
        } else {
            panel.setFrameOrigin(origin)
        }
    }
    
    func beginDrag(at screenLocation: NSPoint) {
        guard let panel else { return }
        dragStartMouseLocation = screenLocation
        dragStartPanelOrigin = panel.frame.origin
    }
    
    func updateDrag(to screenLocation: NSPoint) {
        guard let panel,
              let dragStartMouseLocation,
              let dragStartPanelOrigin else { return }

        let deltaX = screenLocation.x - dragStartMouseLocation.x
        let deltaY = screenLocation.y - dragStartMouseLocation.y

        let newOrigin = NSPoint(
            x: dragStartPanelOrigin.x + deltaX,
            y: dragStartPanelOrigin.y + deltaY
        )

        panel.setFrameOrigin(newOrigin)
    }
    
    func endDrag() {
        dragStartMouseLocation = nil
        dragStartPanelOrigin = nil
    }
    
    func updateSize(width: CGFloat, height: CGFloat = 56) {
        guard let panel else { return }

        var frame = panel.frame
        let targetWidth = max(50, width)
        let targetHeight = max(40, height)

        if abs(frame.width - targetWidth) < 0.5 && abs(frame.height - targetHeight) < 0.5 {
            return
        }

        frame.size = NSSize(width: targetWidth, height: targetHeight)
        panel.setFrame(frame, display: true)
    }
    
    // MARK: - Screen Tracking

    private func displayID(for screen: NSScreen) -> UInt32? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    private func startScreenTracking() {
        screenTrackingTimer?.invalidate()

        guard let mouseScreen = screenContainingMouse() else { return }
        currentScreenID = displayID(for: mouseScreen)

        screenTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForScreenChange()
        }
    }

    private func stopScreenTracking() {
        screenTrackingTimer?.invalidate()
        screenTrackingTimer = nil
        currentScreenID = nil
    }

    private func checkForScreenChange() {
        // Don't fight manual dragging
        guard dragStartMouseLocation == nil,
              isVisible,
              let mouseScreen = screenContainingMouse(),
              let mouseDisplayID = displayID(for: mouseScreen),
              mouseDisplayID != currentScreenID else { return }

        currentScreenID = mouseDisplayID
        positionAtBottomCenter(of: mouseScreen, animated: true)
    }

    private func createPanel() {
        let contentView = FloatingOverlayView()
            .environment(AppState.shared)

        let panel = FloatingOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 50, height: 56),
            backing: .buffered,
            defer: false
        )

        let hostingView = CapsuleHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        hostingView.layer?.isOpaque = false

        panel.contentView = hostingView
        self.panel = panel

        positionAtBottomCenter(of: screenContainingMouse())
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
        self.hasShadow = false
        
        // Hide the titlebar completely
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        
        // Hide traffic light buttons
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        // MARK: - Interaction
        // We drive drag manually from SwiftUI to avoid jitter during hover/size changes.
        self.isMovableByWindowBackground = false
        
        // Don't release when closed - user may open/close frequently
        self.isReleasedWhenClosed = false
        
        // Ignore mouse events that should pass through to windows below
        // (handled by the SwiftUI view for specific areas)
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        
        // MARK: - Animation
        self.animationBehavior = .utilityWindow
    }
    
    // MARK: - Focus Behavior
    
    /// Keep panel non-key to preserve frontmost app selection/focus.
    override var canBecomeKey: Bool {
        return false
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

// MARK: - Capsule-Masked Hosting View

/// NSHostingView subclass that masks its layer to a capsule shape.
/// Eliminates the faint rectangular background that NSHostingView renders by default.
private final class CapsuleHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        let mask = CAShapeLayer()
        let radius = bounds.height / 2
        mask.path = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
        layer?.mask = mask
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
