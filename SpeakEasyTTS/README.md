# SpeakEasy Flow

A lightweight macOS menu bar app for verbatim dictation and text-to-speech. Dictate into the focused app with minimal rewriting, or read selected text back from your screen.

![macOS 14.0+](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **🎯 Global Hotkeys** - Press `Option+D` for dictation or `Option+S` to read selected text
- **🎤 Verbatim Dictation** - Native speech-to-text inserts recognized words without an AI rewrite step
- **📋 Clipboard Reading** - Instantly read text from your clipboard
- **🖥️ Screen Readback** - Read selected text from other apps through the macOS Accessibility API
- **📝 Floating Window** - Manual text input with a clean, minimal interface
- **🎙️ Multiple Voices** - Choose from all available macOS system voices
- **⚡ Speed Control** - Adjust reading speed from 0.2x to 2.0x
- **🔊 Playback Controls** - Play, pause, resume, and stop at any time
- **💾 Persistent Settings** - Your voice and speed preferences are remembered
- **🌐 Edge TTS (Optional)** - High-quality Microsoft neural voices (requires internet)

## Screenshots

```
┌─────────────────────────────────────┐
│  🎤 SpeakEasy Flow                  │
│  ─────────────────────────────────  │
│  Verbatim Dictation          ⌥D     │
│  [Start]                            │
│  ─────────────────────────────────  │
│  [Enter text to speak...]      [▶]  │
│                                     │
│  [Read Clipboard] [Read Selection]  │
│  ─────────────────────────────────  │
│  Voice: [Samantha (Enhanced)    ▼]  │
│  ─────────────────────────────────  │
│  Speed: ━━━━━━●━━━━━━━━━  1.0x     │
│  ─────────────────────────────────  │
│  ⚙️ Settings...              Quit   │
└─────────────────────────────────────┘
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ (for building from source)
- Swift 5.9+
- Accessibility permissions (for global hotkeys, selected-text readback, and dictation insertion)
- Microphone and Speech Recognition permissions (for dictation)

## Installation

### Option 1: Download Release

1. Download the latest `.app` from the Releases page
2. Move `SpeakEasyTTS.app` to your Applications folder
3. Right-click → Open (first time only, to bypass Gatekeeper)
4. Grant Accessibility, Microphone, and Speech Recognition permissions when prompted

### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/SpeakEasyTTS.git
cd SpeakEasyTTS

# Build the app
./build.sh

# Install to Applications
cp -r build/release/SpeakEasyTTS.app /Applications/

# Run
open /Applications/SpeakEasyTTS.app
```

## Usage

### Basic Usage

1. Click the SpeakEasy icon in your menu bar
2. Type or paste text in the input field
3. Click Play or press `Cmd+Return`

### Dictate Into Any App

1. Click into a text field in another app
2. Press `Option+D`
3. Speak normally
4. Press `Option+D` again to stop and insert the recognized text

### Read Selected Text

1. Select text in any application
2. Press `Option+S`
3. SpeakEasy will read the selected text aloud

### Read from Clipboard

1. Copy text to clipboard (`Cmd+C`)
2. Click "Read Clipboard" in the menu bar dropdown

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Option+D` | Toggle dictation (global) |
| `Option+S` | Read selected text (global) |
| `Cmd+Return` | Play text in input window |
| `Space` | Pause/Resume (when focused) |
| `Escape` | Stop playback |
| `Cmd+,` | Open Settings |

## Configuration

### Voice Selection

1. Open Settings (`Cmd+,`)
2. Go to the "Voices" tab
3. Browse and preview available voices
4. Click to select your preferred voice

**Pro Tip:** Download Enhanced or Premium voices from System Settings → Accessibility → Spoken Content → System Voice → Manage Voices for better quality.

### Speed Adjustment

Adjust the speed slider in the menu bar dropdown or Settings:
- 0.2x - Very slow (for learning)
- 0.5x - Slow
- 1.0x - Normal speed
- 1.5x - Fast
- 2.0x - Very fast

### TTS Engine

Choose between:
- **Native (macOS)** - Uses built-in AVSpeechSynthesizer. Works offline.
- **Edge TTS** - Uses Microsoft's neural voices. Higher quality, requires internet.

### Dictation Mode

Dictation defaults to verbatim mode. The app uses Apple's Speech framework result segments directly and disables automatic punctuation where supported, so it does not run dictated text through an LLM cleanup step.

### Ask AI History

Ask AI conversation history is disabled by default. When enabled from the Ask AI section, recent prompt/response turns are stored locally in plain text `UserDefaults` under `com.speakeasy.ai-conversation.session` and included as context for follow-up prompts.

The store keeps the latest 20 turns. Use the trash button in the Ask AI section to clear stored turns without changing the history toggle. Verbatim dictation and readback summaries are not stored in Ask AI history.

## Project Structure

```
SpeakEasyTTS/
├── Package.swift              # Swift Package manifest
├── build.sh                   # Build script
├── README.md
└── Sources/
    ├── App/
    │   └── SpeakEasyApp.swift     # App entry point
    ├── Core/
    │   ├── AppState.swift         # Central state management
    │   ├── DictationService.swift # Native speech-to-text capture
    │   ├── SpeechService.swift    # TTS protocol & native impl
    │   ├── EdgeTTSService.swift   # Edge TTS implementation
    │   └── HotkeyManager.swift    # Global keyboard shortcuts
    ├── Models/
    │   └── Models.swift           # Data models
    ├── Services/
    │   └── Services.swift         # Settings, Voice, Clipboard
    ├── Views/
    │   ├── MenuBarView.swift      # Menu bar interface
    │   ├── InputWindowView.swift  # Floating input window
    │   └── SettingsView.swift     # Preferences window
    └── Resources/
        └── Info.plist
```

## Architecture

The app follows a clean architecture with:

- **@Observable AppState** - Central state management using Swift's new observation framework
- **Protocol-based Services** - SpeechService protocol allows swapping TTS engines
- **Native Dictation Service** - Speech framework + AVAudioEngine speech-to-text capture
- **SwiftUI Views** - Modern declarative UI with menu bar extra
- **Carbon Events** - Global hotkey registration for readback and dictation shortcuts

## Edge TTS Setup (Optional)

For higher quality neural voices:

```bash
# Install Edge TTS for Python
python3 -m pip install edge-tts

# Enable in SpeakEasy Settings -> General -> TTS Engine -> Edge TTS
```

## Troubleshooting

### Global Hotkey Not Working

1. Open System Settings → Privacy & Security → Accessibility
2. Find SpeakEasyTTS and enable it
3. Restart the app

### No Sound

1. Check system volume
2. Verify the selected voice is installed
3. Try a different voice

### Dictation Not Starting

1. Open System Settings → Privacy & Security → Microphone and enable SpeakEasyTTS
2. Open System Settings → Privacy & Security → Speech Recognition and enable SpeakEasyTTS
3. Run the bundled app from `build/release/SpeakEasyTTS.app`; `swift run` does not carry the generated privacy strings

### App Not Starting

1. Check Console.app for error messages
2. Ensure macOS 14.0 or later
3. Try rebuilding from source

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Apple's AVFoundation and Speech frameworks
- Microsoft Edge TTS service (via node-edge-tts)
- SwiftUI and the new @Observable macro
- The macOS developer community

---

Made for accessibility and productivity
