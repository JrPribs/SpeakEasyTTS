# Shortcut Capture Notes

Last updated: June 26, 2026

## Function/Globe Key Feasibility

Roadmap task: P1-07.

Short answer: Function/Globe should not be promised as the default hold key yet. The macOS SDK exposes Function/Globe-related signals, but the current app path is optimized for ordinary global shortcuts and the key still needs hardware-level runtime validation before it can be made a supported trigger.

## Evidence

- AppKit exposes `NSEventModifierFlagFunction` as a device-independent modifier bit. The SDK comment says it is set when any function key is pressed.
- IOKit exposes the matching `NX_SECONDARYFNMASK` bit.
- Carbon HIToolbox exposes `kVK_Function` with virtual key code `0x3F`.
- Carbon keyboard events also expose `kEventKeyModifierFnMask`.
- CoreGraphics documents modifier keys as `flagsChanged` events rather than ordinary `keyDown` events.
- SpeakEasy currently stores shortcuts as one virtual key code plus Command, Option, Shift, and Control modifiers.
- SpeakEasy currently registers global shortcuts through `RegisterEventHotKey`, then uses Carbon pressed/released events for toggle and hold modes.
- The SwiftUI shortcut recorder captures `keyDown` events, not `flagsChanged` events, so modifier-only input is not a first-class shortcut in the current UI.
- A non-invasive runtime check showed `RegisterEventHotKey(kVK_Function, 0)` can return success, but that only proves API acceptance. It does not prove physical Function/Globe delivery across Mac keyboards and system settings.

## Current Product Decision

Use ordinary key-plus-modifier shortcuts for production hold-to-record behavior:

- Default dictation trigger: `Option+D`.
- Recommended hold fallback: Control, Option, or Command plus a regular key, such as `Control+D` or `Option+D`.
- Space latch is supported only after hold-to-record has started.

The settings UI should describe Function/Globe as hardware-dependent and direct users to a regular key fallback.

## Why Not Implement Function/Globe Now

The current Carbon registration path can represent `kVK_Function`, but that does not prove reliable global hold behavior across Mac keyboards, external keyboards, and the user's Function/Globe system settings. The current recorder also does not record pure modifier transitions, so supporting a Function-only hold key would require additional capture and runtime paths.

The smallest implementation that would be worth testing later is:

1. Add a focused diagnostic mode that logs `keyDown`, `keyUp`, and `flagsChanged` events for Function/Globe.
2. Test the app bundle on the target hardware with Accessibility permission granted.
3. Try Carbon registration for `kVK_Function` first.
4. If Carbon is insufficient, test a scoped `NSEvent` flags monitor.
5. If AppKit-level events are insufficient, evaluate a narrowly scoped `CGEventTap` or IOHID path.

Only step 3 is small enough to fit the current shortcut manager. Steps 4 and 5 increase privacy, permissions, and maintenance cost, so they should be driven by observed failure rather than added speculatively.

## Follow-Up Task If Hardware Testing Proves Viable

Add a dedicated Function/Globe trigger type instead of treating it as an ordinary `KeyboardShortcut`. That keeps the normal shortcut model simple and makes it clear that Function/Globe has separate capture rules and fallback behavior.

Acceptance for that future task:

- Function/Globe press starts hold dictation on the user's target Mac.
- Function/Globe release stops or respects latch state.
- The recorder can detect and label Function/Globe intentionally.
- A fallback shortcut remains configurable when Function/Globe is unavailable.
