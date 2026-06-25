# SpeakEasy Flow

Native macOS menu bar app built with Swift/SwiftUI and Swift Package Manager. It combines low-processing speech-to-text dictation with text-to-speech readback from selected text, clipboard text, manual input, and Claude Code plan files.

## Build And Run

All commands run from `SpeakEasyTTS/`, the SwiftPM package root:

```bash
cd SpeakEasyTTS

# Build debug executable
swift build

# Build release app bundle at build/release/SpeakEasyTTS.app
./build.sh

# Run debug executable
swift run SpeakEasyTTS

# Install app bundle
cp -r build/release/SpeakEasyTTS.app /Applications/
```

Use the app bundle for dictation permission testing because `build.sh` generates the `Info.plist` privacy usage strings. No tests or linting are configured.

## Architecture

**Observable singleton + service adapters + SwiftUI/AppKit shell**

`AppState` is an `@Observable` singleton (`AppState.shared`) that owns services and drives UI state. Views observe it with SwiftUI environment injection.

### Key Files

```text
SpeakEasyTTS/Sources/
├── App/
│   └── SpeakEasyApp.swift        # @main entry, MenuBarExtra scene, AppDelegate lifecycle
├── Core/
│   ├── AppState.swift            # Playback, dictation, settings, permissions, selected text
│   ├── DictationService.swift    # Native Speech framework + AVAudioEngine STT
│   ├── SpeechService.swift       # SpeechService protocol + NativeSpeechService
│   ├── EdgeTTSService.swift      # Edge TTS via python3 -m edge_tts
│   └── HotkeyManager.swift       # Carbon Option+S and Option+D global hotkeys
├── Models/
│   └── Models.swift              # DictationState, PlaybackState, Voice, SpeechSettings
├── Services/
│   ├── ClaudeCodeService.swift   # Local markdown/plan preprocessing for readback
│   └── Services.swift            # SettingsStore, VoiceManager, ClipboardService
└── Views/
    ├── MenuBarView.swift
    ├── SettingsView.swift
    ├── InputWindowView.swift
    ├── FloatingOverlayWindow.swift
    └── FloatingOverlayView.swift
```

## Important Patterns

- **Default dictation is verbatim**: `DictationService` uses Apple's Speech framework segments directly and disables automatic punctuation where supported. Do not add LLM cleanup to the default STT path.
- **Text insertion**: `ClipboardService.insertTextIntoLastFocusedApp` snapshots the pasteboard, pastes into the last external app, then restores the pasteboard.
- **Text-to-speech**: `SpeechService` supports native macOS voices and Edge TTS. `AppState.switchEngine()` swaps implementations and reloads voices.
- **Global hotkeys**: `Option+D` toggles dictation. `Option+S` reads selected text. Both require Accessibility permissions.
- **Floating overlay**: `FloatingOverlayController` owns the non-activating `NSPanel`, drag behavior, sizing, and screen tracking.
- **Permissions**: Accessibility is needed for hotkeys/readback/insertion. Microphone and Speech Recognition are needed for dictation. Privacy strings are generated in `build.sh`.
- **Settings persistence**: `SettingsStore` serializes `SpeechSettings` to `UserDefaults`.

## Product Direction

Keep the core experience low-AI and predictable. The default speech-to-text mode should dictate what the user says, not rewrite or polish it. Prefer local/native platform APIs and simple service boundaries before adding networked AI dependencies.
