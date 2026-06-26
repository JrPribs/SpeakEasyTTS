# SpeakEasy Flow

A lightweight native macOS menu bar app for verbatim dictation, text-to-speech readback, and optional AI-assisted voice prompts. The default speech-to-text path stays predictable: it uses Apple's Speech framework and inserts recognized words without an LLM rewrite step.

![macOS 14.0+](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **Verbatim dictation** - Dictate into the tracked target app with immediate insertion.
- **Configurable dictation trigger** - Use toggle, hold-to-record, or hold with Space latch.
- **Readback** - Read selected text, clipboard text, manual text, and Claude Code plan files.
- **Readback processing** - Choose raw, clean prose, summarized response, plan summary, or task-list modes.
- **Ask AI** - Dictate a prompt, review the generated response, then read, copy, insert, or discard it.
- **Local Ask AI history** - Optional plain-text `UserDefaults` history for follow-up prompts.
- **Floating overlay** - Compact always-on-top controls with recording, latched, processing, and response-ready states.
- **Permissions diagnostics** - Settings shows Accessibility, Microphone, Speech Recognition, and optional AI provider state with recovery actions.
- **Native and Edge TTS** - Use macOS voices offline, or optional Edge TTS via `python3 -m edge_tts`.

## Requirements

- macOS 14.0 Sonoma or later
- Swift 6 toolchain / Xcode 16 or later for building from source
- Accessibility permission for global shortcuts, selected-text readback, overlay selection detection, and insertion into other apps
- Microphone and Speech Recognition permissions for dictation
- Optional: `edge-tts` Python package for Edge TTS voices
- Optional: local Ollama service for Ask AI responses

## Build And Run

All commands below run from this SwiftPM package directory:

```bash
cd SpeakEasyTTS/SpeakEasyTTS

# Debug build
swift build

# Test build/link
swift test

# Release app bundle at build/release/SpeakEasyTTS.app
./build.sh

# Run the app bundle
open build/release/SpeakEasyTTS.app
```

Use the app bundle for permission testing. `build.sh` generates the `Info.plist` privacy strings that macOS uses for Microphone and Speech Recognition prompts.

## Install

```bash
./build.sh
cp -r build/release/SpeakEasyTTS.app /Applications/
open /Applications/SpeakEasyTTS.app
```

On first launch, grant permissions from Settings -> Permissions or from System Settings -> Privacy & Security.

## Core Workflows

### Dictate Into Any App

1. Click into a text field in the target app.
2. Press the dictation shortcut, default `Option+D`.
3. Speak normally.
4. Stop according to the configured trigger mode:
   - Toggle: press `Option+D` again.
   - Hold to Record: release the shortcut.
   - Hold with Space Latch: press Space while holding the shortcut to latch or unlatch.
5. SpeakEasy inserts the recognized text into the tracked target app.

Dictation is verbatim by design. It does not summarize, style, or clean up the recognized transcript.

### Ask AI

1. Open the menu bar dropdown and use Ask AI, or use the active overlay state while prompting.
2. Dictate a prompt.
3. Send the prompt and wait for the response-ready state.
4. Review the generated text in the interaction panel.
5. Choose Read, Summary, Copy, Insert, or Discard.

Insertion is explicit. Ask AI never writes generated text into another app until you choose Insert.

### Read Selected Text

1. Select text in another app.
2. Press `Option+S` or choose Read Selection from the menu.
3. SpeakEasy reads the selection using the configured readback profile.

If selection access fails, check Settings -> Permissions and confirm Accessibility is granted.

### Read Clipboard Or Manual Text

- Copy text and choose Read Clipboard.
- Type into the menu input field and press the play button.
- Open the floating input window for larger manual text.

### Read Claude Code Plans

Use the Claude Code plan section to read the latest local plan file or choose a plan manually. Plan readback uses the same readback pipeline and detail settings.

## Settings

### General

- Choose Native macOS TTS or optional Edge TTS.
- Native TTS works offline through `AVSpeechSynthesizer`.
- Edge TTS requires `python3 -m edge_tts` and network access.

### Dictation

- Recognition is currently verbatim.
- Trigger behavior is configurable.
- Dictation inserts into the focused/tracked target app.
- Explicit locale selection and review-before-insert are deferred.

### Readback

- Choose the default processing mode:
  - Raw
  - Clean Prose
  - Summarized Response
  - Plan Summary
  - Task List
- Choose Brief, Standard, or Detailed output.
- Enable optional AI summary requests when a provider is available.
- Configure auto-read on text selection and delay.

### Shortcuts

Default shortcuts:

| Shortcut | Action |
| --- | --- |
| `Option+D` | Dictation |
| `Option+S` | Read selected text |
| `Space` | Pause/resume playback when focused |
| `Escape` | Stop playback or cancel active dictation from auxiliary monitoring |
| `Command+,` | Open Settings |

Shortcut recording supports Command, Option, Control, Shift, and regular keys. Function/Globe capture depends on hardware and macOS settings.

### Permissions

Settings -> Permissions shows:

- Accessibility
- Microphone
- Speech Recognition
- AI Provider

Missing or denied required permissions include recovery actions. AI provider state is optional unless you use Ask AI or AI summaries.

### AI

The current provider adapter targets local Ollama. Provider status is stored without secrets. Ask AI history is disabled by default; when enabled, the app stores the latest 20 prompt/response turns in plain text `UserDefaults` under `com.speakeasy.ai-conversation.session`.

Verbatim dictation and readback summaries do not update Ask AI conversation history.

## Optional Edge TTS Setup

```bash
python3 -m pip install edge-tts
```

Then open Settings -> General and choose Edge TTS. If Edge TTS is unavailable, SpeakEasy falls back to native macOS speech where possible and reports a recoverable error.

## Optional Ollama Setup

Ask AI uses the provider-neutral AI layer with a local Ollama adapter. Install and run Ollama separately, then make sure the configured model is available locally. If the provider is unavailable, Ask AI leaves the response in a recoverable error state and does not insert text.

## QA

Automated gates:

```bash
swift test
swift build
git diff --check
```

In this environment, `swift test` builds and links the Swift Testing bundle; it may not print individual test execution lines.

Manual QA for permission-heavy flows is tracked in [`../docs/manual-qa.md`](../docs/manual-qa.md). Run manual QA from the app bundle, not `swift run`.

## Troubleshooting

### TTS Playback Does Not Start

1. Check system volume and output device.
2. Try Settings -> Voices -> Preview with a native voice.
3. Switch Settings -> General -> TTS Engine to Native.
4. If Edge TTS is selected, confirm `python3 -m edge_tts` is installed and reachable.
5. Check Console.app for `com.speakeasy.tts` logs in the `tts` and `readback` categories.

### Global Hotkeys Do Not Work

1. Open Settings -> Permissions and check Accessibility.
2. Use the recovery button or open System Settings -> Privacy & Security -> Accessibility.
3. Enable SpeakEasyTTS and restart the app if macOS asks.

### Dictation Does Not Start

1. Open Settings -> Permissions.
2. Confirm Accessibility, Microphone, and Speech Recognition are granted.
3. Run `build/release/SpeakEasyTTS.app`; `swift run` does not carry the generated privacy strings.

### Dictation Inserts Into The Wrong Place

1. Focus the target text field before starting dictation.
2. Avoid clicking into SpeakEasy while recording unless using the overlay.
3. If the overlay is active, SpeakEasy uses the last tracked external target app for insertion.

### Ask AI Has No Response

1. Check Settings -> Permissions -> AI Provider.
2. Confirm Ollama is running and the model is installed.
3. Use the interaction panel to discard the failed session and try again.

## Project Structure

```text
SpeakEasyTTS/
├── Package.swift
├── build.sh
├── README.md
├── Sources/
│   ├── App/
│   │   └── SpeakEasyApp.swift
│   ├── Core/
│   │   ├── AppLog.swift
│   │   ├── AppState.swift
│   │   ├── DictationService.swift
│   │   ├── HotkeyManager.swift
│   │   ├── InteractionCoordinator.swift
│   │   ├── ReadbackPipeline.swift
│   │   └── SpeechService.swift
│   ├── Models/
│   ├── Services/
│   │   ├── AIInteractionService.swift
│   │   ├── OllamaProvider.swift
│   │   ├── PermissionService.swift
│   │   ├── TextDestinationService.swift
│   │   └── TextSourceService.swift
│   └── Views/
│       ├── FloatingOverlayView.swift
│       ├── InteractionPanelView.swift
│       ├── MenuBarView.swift
│       └── Settings/
└── Tests/
    └── SpeakEasyTTSTests/
```

## Architecture

SpeakEasy uses an observable singleton plus small service adapters:

- `AppState` owns app-level state, settings, and service composition.
- `InteractionCoordinator` tracks dictation, readback, Ask AI, insertion, cancellation, and review states.
- `DictationService` wraps Apple's Speech framework and `AVAudioEngine`.
- `SpeechService` supports native macOS speech and optional Edge TTS.
- `TextSourceService` and `TextDestinationService` isolate selection, clipboard, and target-app writing.
- `ReadbackPipeline` handles deterministic speech-friendly processing and optional AI summaries.
- `PermissionService` centralizes runtime permission diagnostics.

## Logging

Runtime logs use OSLog categories through `AppLog`: `app`, `permissions`, `dictation`, `shortcuts`, `readback`, `ai`, `insertion`, and `tts`. Logs intentionally avoid raw dictated text, selected text, prompts, and generated responses.

## License

MIT License.

## Acknowledgments

- Apple's AVFoundation and Speech frameworks
- SwiftUI and AppKit
- Microsoft Edge TTS via `edge-tts`
- Ollama for local AI provider support
