# Floating Overlay Widget Integration Guide

This guide explains how to integrate the floating always-on-top overlay widget into SpeakEasyTTS.

## Overview

The floating overlay provides a minimal, persistent UI that:
- Stays on top of all windows (including fullscreen apps)
- Doesn't steal focus from other applications
- Is draggable anywhere on screen
- Expands on hover to show additional controls
- Positions at the bottom center of the screen by default

## Files Created

1. **`Sources/Views/FloatingOverlayWindow.swift`**
   - `FloatingOverlayController` - Singleton controller to show/hide the overlay
   - `FloatingOverlayPanel` - NSPanel subclass with proper window configuration

2. **`Sources/Views/FloatingOverlayView.swift`**
   - `FloatingOverlayView` - The main pill-shaped SwiftUI view
   - `SoundWaveIndicator` - Animated indicator for playing state
   - `VisualEffectBlur` - NSVisualEffectView wrapper for blur effects

## Integration Steps

### 1. Update Package.swift (if needed)

The files are pure Swift/SwiftUI with no additional dependencies.

### 2. Update AppDelegate.swift

Add the floating overlay controller to the app delegate:

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?
    private let floatingOverlay = FloatingOverlayController.shared  // ADD THIS
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        hotkeyManager = HotkeyManager.shared
        hotkeyManager?.registerGlobalHotkey()
        checkAccessibilityPermissions()
        NSApp.setActivationPolicy(.accessory)
        
        // Show the floating overlay on launch (optional)
        floatingOverlay.show()  // ADD THIS
        
        print("SpeakEasyTTS launched successfully")
    }
    
    // ... rest of the code
}
```

### 3. Add Menu Item to Show/Hide Overlay

In `MenuBarView.swift`, add a toggle in the actions section:

```swift
private var actionsSection: some View {
    VStack(spacing: 4) {
        // ADD THIS BUTTON
        Button {
            FloatingOverlayController.shared.toggle()
        } label: {
            HStack {
                Image(systemName: FloatingOverlayController.shared.isVisible 
                    ? "pip.fill" : "pip")
                Text(FloatingOverlayController.shared.isVisible 
                    ? "Hide Floating Widget" : "Show Floating Widget")
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 6)
        
        // ... existing buttons
    }
}
```

### 4. Add Hotkey Support (Optional)

In `HotkeyManager.swift`, add a hotkey to toggle the overlay:

```swift
func toggleFloatingOverlay() {
    FloatingOverlayController.shared.toggle()
}
```

### 5. Add Settings Option (Optional)

In `SettingsView.swift`, add a toggle for auto-showing the overlay:

```swift
Toggle("Show floating widget on launch", isOn: $showOverlayOnLaunch)
```

## Architecture Details

### Window Configuration

The `FloatingOverlayPanel` uses these critical settings:

| Property | Value | Purpose |
|----------|-------|---------|
| `styleMask` | `.nonactivatingPanel, .fullSizeContentView, .borderless` | Prevents focus theft |
| `level` | `.statusBar` | Floats above normal windows |
| `collectionBehavior` | `.canJoinAllSpaces, .fullScreenAuxiliary, .stationary` | Works across spaces/fullscreen |
| `isFloatingPanel` | `true` | Panel floating behavior |
| `isMovableByWindowBackground` | `true` | Drag from anywhere |
| `backgroundColor` | `.clear` | Transparent for custom shape |

### View States

The overlay has three visual states based on `PlaybackState`:

1. **Idle** - Gray waveform icon, play button
2. **Playing** - Animated green sound waves, pause button
3. **Paused** - Orange pause icon, play button

### Expansion Behavior

- **Collapsed (default)**: 120pt wide, shows status + play/pause
- **Expanded (on hover/tap)**: 280pt wide, adds stop, progress, clipboard, close

The view auto-collapses 1.5 seconds after mouse leaves.

## Customization

### Change Default Position

```swift
// In FloatingOverlayController.swift
func positionAtBottomCenter() {
    let y = screenFrame.minY + 20  // Change this value
    // Or position at top:
    // let y = screenFrame.maxY - panelFrame.height - 20
}
```

### Change Window Level

```swift
// In FloatingOverlayPanel.swift
self.level = .floating      // Normal floating (below statusBar level)
self.level = .statusBar     // Above most windows (current)
self.level = .popUpMenu     // Above menus (may be intrusive)
```

### Adjust Sizing

```swift
// In FloatingOverlayView.swift
private let collapsedWidth: CGFloat = 120   // Compact width
private let expandedWidth: CGFloat = 280    // Expanded width
private let height: CGFloat = 44            // Overall height
```

### Change Appearance

The blur material can be adjusted:
```swift
// In FloatingOverlayView.swift
VisualEffectBlur(material: .hudWindow, ...)  // Current
VisualEffectBlur(material: .sidebar, ...)    // Lighter
VisualEffectBlur(material: .dark, ...)       // Darker
```

## How It Works

### Non-Activating Window

The key to not stealing focus is the `.nonactivatingPanel` style mask combined with:

1. `canBecomeMain` returning `false`
2. NSPanel's `becomesKeyOnlyIfNeeded` behavior
3. Not calling `makeKeyAndOrderFront` (using `orderFront` instead)

### Dragging

`isMovableByWindowBackground = true` makes any empty space in the window draggable. The SwiftUI view handles its own interactions (buttons, etc.) which don't interfere with dragging.

### Fullscreen Support

`.fullScreenAuxiliary` allows the panel to appear alongside fullscreen apps, combined with `.canJoinAllSpaces` to persist across virtual desktops.

## Troubleshooting

### Overlay steals focus
- Ensure `.nonactivatingPanel` is in the styleMask
- Use `orderFront(nil)` not `makeKeyAndOrderFront(nil)`
- Check `canBecomeMain` returns `false`

### Overlay hidden behind fullscreen apps
- Add `.fullScreenAuxiliary` to collectionBehavior
- Increase window level to `.statusBar` or higher

### Hover doesn't work
- Ensure `ignoresMouseEvents = false`
- Check `NSTrackingArea` if implementing manual tracking

### Blur not appearing
- Verify the window has a clear background (`backgroundColor = .clear`)
- Check `isOpaque = false`
- Ensure VisualEffectBlur's `state = .active`

## References

- [NSPanel Documentation](https://developer.apple.com/documentation/appkit/nspanel)
- [NSWindow.Level](https://developer.apple.com/documentation/appkit/nswindow/level)
- [NSWindow.CollectionBehavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior)
- [Wispr Flow](https://wisprflow.ai) - Inspiration for the floating bar design
