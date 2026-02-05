# Mac TTS Apps Competitive Analysis Research

## 1. Speechify (Market Leader)

**Platform:** iOS, macOS, Chrome Extension, Desktop
**Rating:** 4.7/5 (450K ratings)
**Price:** Free with In-App Purchases (Premium subscription)
**Size:** 510.4 MB

### Key Features:
- 200+ lifelike voices across 60+ languages
- Speed control up to 4.5x (900 wpm)
- Cross-device sync (iOS, desktop, Chrome)
- Screenshot/image to audio
- Active text highlighting (word-by-word sync)
- Voice typing/dictation
- AI assistant integration (ask questions about content)
- AI Podcasts creation
- Note taking & bookmarks
- Celebrity voices (Snoop Dogg, MrBeast, Gwyneth Paltrow)

### User Complaints (from reviews):
- Monthly word limit on HD voices
- Some voices skip words or glitch
- Premium voices can be unreliable
- Standard/free voices sound robotic
- HD voices slow to load sometimes

### Target Users:
- Students
- People with Dyslexia, ADHD, Vision challenges
- Professionals
- Parents
- Productivity hackers
- Podcast/Audiobook lovers

---

## Research Notes - Continue gathering data on:
- NaturalReader
- Voice Dream Reader
- Speech Central
- macOS built-in TTS
- Menu bar specific apps


## 2. Voice Dream Reader (Apple Design Award Winner)

**Platform:** iOS, macOS
**Rating:** 4.5+ stars (12,000+ ratings)
**Price:** Free with In-App Purchases
**Award:** Apple Design Award Winner

### Key Features:
- 200+ human-quality premium voices
- Offline functionality (no internet required)
- Multiple input formats: PDFs, textbooks, emails, docs, articles
- Browser extensions for web content
- Camera scanning for physical text
- Cross-platform sync

### Target Users:
- Students with dyslexia
- Accessibility-focused users
- Professionals who prefer listening

---

## 3. Speakeasy-Mac (Open Source Reference)

**Platform:** macOS only
**Price:** Free (MIT License)
**GitHub:** github.com/minac/speakeasy-mac

### Architecture (Reference Implementation):
- Native macOS menu bar app using SwiftUI
- Uses AVSpeechSynthesizer (Apple's native TTS)
- URL content extraction with HTML parsing
- Real-time playback progress with word highlighting
- Playback controls: play/stop, pause/resume
- Structured logging using OSLog

### Project Structure:
```
Speakeasy/
├── SpeakeasyApp.swift              # App entry point
├── Core/
│   ├── AppState.swift              # Central state management
│   ├── SpeechEngine.swift          # TTS engine wrapper
│   ├── TextExtractor.swift         # URL/HTML processing
│   └── ShortcutManager.swift       # Global keyboard shortcuts
├── Models/
│   ├── SpeechSettings.swift        # Settings model
│   ├── Voice.swift                 # Voice wrapper
│   └── PlaybackState.swift         # Playback states
├── Services/
│   ├── SettingsService.swift       # UserDefaults persistence
│   └── VoiceDiscoveryService.swift # System voice enumeration
├── Views/
│   ├── MenuBarView.swift           # Menu bar interface
│   ├── InputWindow.swift           # Text input window
│   └── SettingsWindow.swift        # Settings interface
```

### Requirements:
- macOS 14.0+
- Swift 5.9+
- Accessibility permissions for global keyboard shortcuts

---

## 4. macOS Built-in TTS

### System Features:
- Accessible via System Settings > Accessibility > Spoken Content
- Global keyboard shortcut (configurable)
- Multiple system voices (Enhanced and Premium downloadable)
- `say` command in Terminal for automation

### `say` Command Capabilities:
- Basic usage: `say "Hello World"`
- Voice selection: `say -v "Samantha" "Hello"`
- Speed control: `say -r 200 "Hello"` (words per minute)
- Save to file: `say -o output.aiff "Hello"`
- List voices: `say -v ?`

### Limitations:
- No floating window for manual text input
- Limited voice customization in UI
- No word-by-word highlighting
- No pause/resume from menu bar

---

## 5. NaturalReader

**Platform:** iOS, macOS, Web, Chrome Extension
**Rating:** 4.5+ stars
**Price:** Free with Premium subscription

### Key Features:
- Convert text to MP3 files
- OCR text recognition for PDFs
- Camera scanner
- Multiple languages
- Cross-platform

### User Complaints:
- Similar issues to Speechify with voice quality
- Some prefer built-in Mac voices

---

## 6. Speech Central

**Platform:** iOS, macOS, Android
**Price:** Free with In-App Purchases

### Key Features:
- AI Voice Reader
- PDF, ePub, Web text to speech
- System playback controls
- Passage highlighting
- Cross-platform sync

---

## Gap Analysis - What's Missing in Existing Apps

### Common Pain Points:
1. **Subscription fatigue** - Most apps require expensive subscriptions for quality voices
2. **Word limits** - Premium features often have monthly word/character limits
3. **Bloated apps** - Many apps are feature-heavy when users just want simple TTS
4. **No free high-quality offline option** - macOS built-in is free but limited UI
5. **Complex UI** - Many apps have steep learning curves

### Market Opportunity:
A lightweight, free menu bar app that:
- Uses macOS built-in voices (free, offline, good quality with Enhanced voices)
- Optionally uses Edge TTS (free, high quality, requires internet)
- Simple hotkey to read selected text from any app
- Minimal floating window for manual text input
- Basic but essential controls (play/pause/stop, speed, voice selection)
- No subscription, no word limits


---

# iOS Companion App Research

## AVSpeechSynthesizer - Apple's Native TTS API

### Platform Support:
- iOS 7.0+
- iPadOS 7.0+
- macOS 10.14+
- Mac Catalyst 13.1+
- watchOS 2.0+
- visionOS 1.0+
- tvOS

### Key API Features:

**Core Methods:**
- `speak(AVSpeechUtterance)` - Adds utterance to queue
- `continueSpeaking()` - Resumes from paused state
- `pauseSpeaking(at: AVSpeechBoundary)` - Pause at word or immediate boundary
- `stopSpeaking(at: AVSpeechBoundary)` - Stop speech

**State Properties:**
- `isSpeaking: Bool` - Currently speaking or paused with pending utterances
- `isPaused: Bool` - In paused state

**Delegate Protocol (AVSpeechSynthesizerDelegate):**
- Receives events during speech synthesis
- Word boundaries, sentence boundaries
- Speech started/finished/paused/continued

**Advanced Features:**
- Personal Voice support (iOS 17+)
- Custom voice authorization
- Audio session management
- Telephony uplink mixing
- Buffer callbacks for audio processing

### AVSpeechUtterance Configuration:
- `voice` - AVSpeechSynthesisVoice selection
- `rate` - Speech rate (0.0 to 1.0)
- `pitchMultiplier` - Voice pitch
- `volume` - Audio volume
- `preUtteranceDelay` - Delay before speaking
- `postUtteranceDelay` - Delay after speaking

---

## iOS Companion App Strategy

### Approach 1: SwiftUI Multiplatform App (Recommended)

**Benefits:**
- Single codebase for iOS, iPadOS, and macOS
- Shared business logic and TTS engine
- Consistent user experience
- Easier maintenance

**Architecture:**
```
SharedCode/
├── Core/
│   ├── SpeechEngine.swift      # AVSpeechSynthesizer wrapper
│   ├── VoiceManager.swift      # Voice discovery & selection
│   └── SettingsStore.swift     # UserDefaults/CloudKit sync
├── Models/
│   ├── Voice.swift
│   ├── SpeechSettings.swift
│   └── PlaybackState.swift
└── Services/
    └── ClipboardService.swift  # Platform-specific clipboard

PlatformSpecific/
├── macOS/
│   ├── MenuBarView.swift       # Menu bar interface
│   ├── FloatingWindow.swift    # Text input window
│   └── GlobalHotkey.swift      # Cmd+Shift+S handler
└── iOS/
    ├── MainView.swift          # Full-screen interface
    ├── ShareExtension/         # Share sheet integration
    └── Widget/                 # Home screen widget
```

### Approach 2: Separate Apps with Shared Framework

**Benefits:**
- More platform-specific optimizations
- Smaller app sizes
- Independent release cycles

**Shared Framework:**
- Create a Swift Package for shared TTS logic
- Import in both macOS and iOS projects

### iOS-Specific Features to Consider:

1. **Share Extension** - Read text from any app via share sheet
2. **Siri Shortcuts** - "Hey Siri, read this text"
3. **Widget** - Quick access from home screen
4. **Control Center** - Playback controls
5. **Background Audio** - Continue playing when app is backgrounded
6. **Clipboard Monitoring** - Auto-detect copied text (with permission)
7. **iCloud Sync** - Sync preferences between devices

### iOS UI Considerations:

- Full-screen text input (no menu bar on iOS)
- Large, touch-friendly playback controls
- Voice picker with preview
- Speed slider with haptic feedback
- Dark mode support
- Dynamic Type support for accessibility

---

## Edge TTS Integration Options

### node-edge-tts (Node.js)
- npm package: `node-edge-tts`
- Uses Microsoft Edge's online TTS service
- High-quality voices (400+ voices)
- Supports subtitles/word timing
- Requires internet connection

### Usage Example:
```javascript
const { EdgeTTS } = require('node-edge-tts')

const tts = new EdgeTTS({
  voice: 'en-US-AriaNeural',
  lang: 'en-US',
  rate: '+10%',
  pitch: 'default'
})

await tts.ttsPromise('Hello world', './output.mp3')
```

### Available Voices (English):
- en-US-AriaNeural (Female)
- en-US-GuyNeural (Male)
- en-US-JennyNeural (Female)
- en-GB-SoniaNeural (British Female)
- en-AU-NatashaNeural (Australian Female)
- Many more...

### Integration with macOS App:
- Run Node.js subprocess from Swift
- Or use edge-tts Python package
- Or create a local HTTP server for TTS requests

