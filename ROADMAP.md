# SpeakEasy Flow Voice Interaction Roadmap

Last updated: June 26, 2026

This is the authoritative in-codebase roadmap for evolving SpeakEasy Flow from a
menu bar dictation/readback utility into a full voice interaction tool: an app
the user can talk to, an app that can talk back, and an app that can read from
and write to other macOS apps with predictable user control.

The roadmap is intentionally implementation-focused. Each phase is broken into
tasks that can be executed in separate Codex sessions with clear boundaries,
expected files, acceptance criteria, and test evidence.

## Product North Star

SpeakEasy Flow should let the user work hands-free across the Mac:

1. Dictate text into any focused app with low processing by default.
2. Talk directly to an AI assistant when the user chooses an AI mode.
3. Read selected text, clipboard text, app text, Codex/Claude responses, and plan
   files aloud.
4. Summarize or transform long responses before readback so the user can hear
   the important parts without waiting through everything.
5. Write generated or dictated text back into the intended app without losing
   the user's clipboard contents or focus context.
6. Configure all primary triggers, including dictation hotkeys, readback
   hotkeys, hold-to-talk, and toggle-on/toggle-off behavior.
7. Stay local/native and predictable for baseline dictation and readback; add AI
   only through explicit modes and clear provider boundaries.

## Current Baseline

The codebase currently provides these foundations:

| Capability | Current state | Evidence |
| --- | --- | --- |
| Menu bar app shell | Implemented with `MenuBarExtra`, Settings scene, and accessory activation policy. | `SpeakEasyTTS/Sources/App/SpeakEasyApp.swift` |
| Floating overlay | Implemented as an always-on-top AppKit/SwiftUI panel with compact controls. | `SpeakEasyTTS/Sources/Views/FloatingOverlayView.swift`, `FloatingOverlayWindow.swift` |
| Native dictation | Implemented through `SFSpeechRecognizer` and `AVAudioEngine`; defaults to verbatim segment joining and disables automatic punctuation where supported. | `SpeakEasyTTS/Sources/Core/DictationService.swift` |
| Dictation insertion | Implemented by tracking the last external app, snapshotting the pasteboard, pasting, and restoring the pasteboard. | `SpeakEasyTTS/Sources/Services/Services.swift` |
| Text readback | Implemented for manual input, clipboard, selected text, and Claude plan files. | `AppState.speak`, `ClipboardService`, `ClaudeCodeService` |
| TTS engines | Native macOS TTS is the reliable default; Edge TTS remains optional. | `SpeechService.swift`, `EdgeTTSService.swift`, `Models.swift` |
| Selection detection | Implemented with Accessibility API and clipboard fallback. | `ClipboardService.getSelectedText` |
| Global hotkeys | Hardcoded `Option+D` for dictation and `Option+S` for selected-text readback. | `HotkeyManager.swift` |
| Settings persistence | `SpeechSettings` stored in `UserDefaults`. | `SettingsStore`, `Models.swift` |
| Plan readback preprocessing | Basic markdown cleanup exists, but code blocks are currently removed rather than summarized. | `ClaudeCodeService.swift` |

## Key Gaps

These gaps block the requested product:

1. Hotkeys are hardcoded instead of user-configurable.
2. Dictation only supports toggle behavior through `Option+D`; it does not
   support press-and-hold, hold-and-release, or hold-plus-space-to-latch.
3. The app does not model voice interactions as sessions with sources,
   destinations, modes, transcript history, or follow-up actions.
4. There is no AI provider boundary for conversational voice mode, summarization,
   response compression, or structured transformations.
5. Readback preprocessing is one-off and tied to Claude plan files instead of a
   reusable readback pipeline.
6. The app has no dedicated concept of "active target app", "text source", or
   "text destination" beyond the current clipboard/Accessibility helper.
7. There are no tests, no deterministic sample fixtures for markdown/readback
   processing, and no explicit acceptance checks for cross-app read/write flows.
8. The settings UI is not organized around workflows such as Dictation,
   Readback, AI, Shortcuts, Targets, and Privacy.
9. The overlay is useful for simple actions, but it does not expose mode,
   session, target, latch state, or response readback controls.
10. Permissions are checked opportunistically; there is no guided onboarding or
   diagnostics view for Accessibility, Microphone, Speech Recognition, and AI
   credentials.

## Product Principles

1. Simple baseline first.
   Native dictation and native TTS must keep working without AI, network calls,
   or external services.

2. Explicit AI modes.
   AI should never silently rewrite default dictation. The user chooses when
   dictated speech is raw text, an AI instruction, a question, or a command.

3. User-controlled writeback.
   The app can insert text into other apps, but high-impact operations should be
   visible, cancelable, and recoverable.

4. Keep text I/O boring.
   Prefer Accessibility API reads/writes and pasteboard fallback before
   app-specific automation. Add app adapters only when the generic path is not
   enough.

5. Treat audio, text, and AI as pipeline stages.
   Capture, transcription, processing, readback, and insertion should be
   separable so each can be tested and reused.

6. Settings should describe behavior, not internals.
   Users configure "Hold to dictate", "Toggle dictation", "Read selected text",
   and "Summarize before reading", not Carbon key codes or service classes.

7. Prefer recoverable state over hidden magic.
   Show the current mode, active app target, transcript, generated text, and
   pending insert/readback actions when useful.

## Target User Workflows

### Workflow A: Verbatim Dictation Into Any App

1. User focuses a text field in any app.
2. User presses configured dictation trigger.
3. SpeakEasy records speech and shows recording state in overlay/menu.
4. User stops recording by release, hotkey toggle, or latch toggle depending on
   configured mode.
5. The recognized text is inserted into the original focused app.
6. The original clipboard contents are restored.

Acceptance target:
- The user can complete this flow without clicking the SpeakEasy UI.
- The default path does not AI-rewrite the dictated text.

### Workflow B: Hold Function Key, Tap Space To Latch

This mirrors the user's Wispr Flow-style behavior.

1. User holds the configured hold key, such as Function/Globe if macOS exposes
   it reliably on the user's hardware.
2. SpeakEasy starts recording while the key is held.
3. While still holding, the user presses Space.
4. SpeakEasy latches recording on, allowing the user to release the hold key.
5. User presses the configured stop trigger or the original dictation hotkey to
   finish and insert.

Acceptance target:
- If Function/Globe is technically capturable on the target macOS/hardware, this
  exact behavior works.
- If macOS does not expose Function/Globe reliably, the app supports an explicit
  fallback hold modifier and documents the limitation in the shortcut settings.

### Workflow C: Read Selected Codex Or Claude Response

1. User selects a response in Codex, Claude Code, a browser, or another app.
2. User presses the configured readback trigger.
3. SpeakEasy reads the selected text aloud.
4. If configured, SpeakEasy summarizes first, preserving decisions,
   requirements, blockers, commands, file paths, and next actions.
5. User can pause, resume, stop, or switch between "full read" and "summary".

Acceptance target:
- The flow works for selected text and clipboard text.
- Long code blocks are not read verbatim by default in plan/technical modes.
- The summary includes important implementation details and skips noise.

### Workflow D: Read The Latest Plan File

1. User chooses "Read recent plan" or selects a plan file.
2. SpeakEasy parses markdown into spoken sections.
3. Fenced code blocks are replaced with spoken summaries of what the block does,
   not dropped silently.
4. The user can choose detail level: brief, standard, detailed.

Acceptance target:
- The existing `ClaudeCodeService` becomes one readback profile inside a more
  general readback pipeline.
- Fixture tests prove headings, bullets, tasks, code fences, file paths, and
  acceptance criteria are handled.

### Workflow E: Talk Directly To An AI Model

1. User activates "Ask AI" mode by hotkey, overlay button, or menu.
2. User speaks a prompt.
3. SpeakEasy transcribes the prompt.
4. SpeakEasy sends the prompt, app context, and optional selected text to the
   configured AI provider.
5. SpeakEasy streams or displays the response.
6. SpeakEasy can read the response aloud, summarize it, or insert it into the
   focused app with user confirmation.

Acceptance target:
- AI mode is distinct from default dictation mode.
- Provider setup and failures are visible.
- The user can choose "read response", "summarize and read", "copy", or
  "insert".

### Workflow F: Rewrite Or Transform Selected Text

1. User selects text in any app.
2. User invokes a configured AI transform, such as "make concise", "reply",
   "turn into tasks", or "fix grammar".
3. SpeakEasy shows or reads the proposed result.
4. User accepts insertion back into the target app or cancels.

Acceptance target:
- The selected text and target app are captured before SpeakEasy takes focus.
- The app does not overwrite user text without explicit user action.

## Proposed Architecture

Keep the current singleton shell for now, but add small service boundaries that
can be tested independently. Avoid a new framework or heavy architecture rewrite.

### Core Layer

Proposed files:

- `Sources/Core/InteractionSession.swift`
- `Sources/Core/InteractionCoordinator.swift`
- `Sources/Core/ShortcutManager.swift`
- `Sources/Core/ShortcutModels.swift`
- `Sources/Core/ReadbackPipeline.swift`
- `Sources/Core/AIInteractionService.swift`

Responsibilities:

- Own the interaction state machine.
- Convert hotkey/key events into actions.
- Route dictation output to raw insertion, AI prompt, readback, or transform.
- Queue readback and insertion actions.
- Keep AppState as the observable UI facade.

### Text I/O Layer

Proposed files:

- `Sources/Services/TextSourceService.swift`
- `Sources/Services/TextDestinationService.swift`
- `Sources/Services/AppContextService.swift`
- `Sources/Services/AppProfileService.swift`

Responsibilities:

- Capture selected text, clipboard text, focused element text, active app
  metadata, and file/URL hints.
- Insert text through Accessibility where possible, with pasteboard fallback.
- Track target app identity safely when overlay/settings become frontmost.
- Add per-app profiles for Codex, terminal apps, browsers, editors, chat apps,
  and document apps only when generic behavior is insufficient.

### Audio Layer

Proposed files:

- Keep `DictationService.swift`, but expose richer events.
- Keep `SpeechService.swift`, but add utterance IDs and queue support.
- Optionally add `AudioSessionCoordinator.swift` if recording and playback
  concurrency becomes complex.

Responsibilities:

- Native speech recognition.
- Native and optional network TTS.
- Interrupt, duck, stop, resume, and queue policies.
- Speech progress events that UI can display.

### AI Layer

Proposed files:

- `Sources/Services/AIProvider.swift`
- `Sources/Services/AIProviderStore.swift`
- `Sources/Services/OpenAIProvider.swift` or another provider-specific adapter
  when implementation starts.
- `Sources/Services/PromptBuilder.swift`
- `Sources/Services/ConversationStore.swift`

Responsibilities:

- Provider-neutral request/response model.
- Streaming text response support.
- Summarization and transformation profiles.
- Minimal local persistence for conversation/session history.
- Safe error handling for missing credentials, network failure, model failure,
  and user cancellation.

### UI Layer

Proposed files:

- `Sources/Views/Settings/ShortcutSettingsView.swift`
- `Sources/Views/Settings/DictationSettingsView.swift`
- `Sources/Views/Settings/ReadbackSettingsView.swift`
- `Sources/Views/Settings/AISettingsView.swift`
- `Sources/Views/InteractionPanelView.swift`
- `Sources/Views/ReadbackReviewView.swift`

Responsibilities:

- Configure triggers and modes.
- Show current session state.
- Review generated text before insertion.
- Show target app, selected text availability, and permissions health.

## Core Data Models To Add

These names are proposals. Keep the implementation as small as possible.

```swift
enum InteractionMode: String, Codable {
    case dictateVerbatim
    case askAI
    case transformSelection
    case readSelection
    case readClipboard
    case readPlan
}

enum DictationTriggerMode: String, Codable {
    case toggle
    case holdToRecord
    case holdWithSpaceLatch
}

struct KeyboardShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: ShortcutModifiers
    var displayName: String
}

struct InteractionSession: Identifiable {
    var id: UUID
    var mode: InteractionMode
    var targetApp: AppContext?
    var sourceText: String?
    var transcript: String
    var generatedText: String?
    var state: InteractionState
}

struct ReadbackRequest {
    var text: String
    var source: ReadbackSource
    var profile: ReadbackProfile
    var detailLevel: ReadbackDetailLevel
}
```

## Roadmap Phases

### Phase 0: Stabilize The Current Core

Goal:
Make the current native dictation, insertion, selected-text readback, and TTS
paths reliable enough to build on.

Deliverables:

- Current feature inventory in this roadmap.
- Basic test target added to SwiftPM.
- Unit tests for settings persistence, markdown preprocessing, and shortcut
  models.
- Manual QA checklist for permissions, dictation, insertion, readback, and
  overlay behavior.

Exit criteria:

- `swift build` passes.
- `swift test` exists and passes.
- Native TTS readback is the default and works without Edge TTS.
- Dictation still inserts verbatim text into the last focused app.

### Phase 1: Configurable Shortcuts And Trigger Modes

Goal:
Make dictation and readback triggers user-configurable, including toggle,
press-and-hold, and hold-plus-space latch behavior.

Key decisions:

- Keep Carbon hotkeys for normal global shortcuts if they remain sufficient.
- Add a keyboard event monitor or event tap only for trigger modes that Carbon
  cannot express.
- Treat Function/Globe as a hardware-dependent capability that must be detected
  and tested.

Deliverables:

- `ShortcutModels` for user-configured shortcut definitions.
- `ShortcutManager` that registers/unregisters current shortcuts dynamically.
- Settings UI for changing dictation and readback shortcuts.
- Dictation trigger setting:
  - Toggle on/off.
  - Hold to record, release to stop.
  - Hold to record, Space to latch, stop by shortcut.
- Conflict detection and user-visible errors.
- Migration from hardcoded `Option+D` and `Option+S`.

Exit criteria:

- User can change dictation hotkey.
- User can change readback hotkey.
- User can switch dictation between toggle and hold behavior.
- Hold-plus-space latch works with the configured hold trigger, subject to the
  Function/Globe feasibility check.

### Phase 2: Interaction Session State Machine

Goal:
Move from one-off AppState methods to a session coordinator that can support
dictation, readback, AI prompts, transformations, and writeback safely.

Deliverables:

- `InteractionSession` model.
- `InteractionCoordinator` service.
- Session states:
  - idle
  - preparing
  - recording
  - transcribing
  - processing
  - awaitingUserReview
  - inserting
  - reading
  - completed
  - failed
  - cancelled
- AppState bridges existing UI to coordinator.
- Overlay displays current mode and target app.
- Dictation uses the coordinator but keeps current behavior.

Exit criteria:

- Existing dictation/readback behavior remains intact.
- Session state is visible enough to debug from logs and UI.
- User can cancel any active session.

### Phase 3: Text Source And Destination Abstractions

Goal:
Make reading and writing text across macOS apps a first-class capability instead
of a collection of clipboard helper methods.

Deliverables:

- `AppContextService` captures active app bundle ID, app name, PID, focused
  element role, selected text availability, and URL/file hints where available.
- `TextSourceService` supports:
  - selected text
  - clipboard text
  - focused text field contents when safe
  - latest plan file
  - manually typed text
- `TextDestinationService` supports:
  - pasteboard-preserving insertion
  - Accessibility value replacement where reliable
  - append vs replace modes
  - target revalidation before insertion
- App profile model for app-specific behavior.

Exit criteria:

- Read and write behavior is covered by unit tests where possible and manual QA
  where macOS permissions are required.
- Target app loss is detected before insertion.
- Clipboard is restored after insertion.

### Phase 4: Readback Pipeline And Technical Summaries

Goal:
Make readback intelligent without making it unpredictable. The app should know
how to read raw text, summarize long responses, and explain technical plans.

Deliverables:

- `ReadbackPipeline` with stages:
  - acquire
  - classify
  - normalize markdown
  - remove or summarize noise
  - optionally AI-summarize
  - chunk for TTS
  - speak
- Readback profiles:
  - Raw
  - Clean prose
  - Technical response
  - Plan summary
  - Code review summary
  - Task list
- Claude/Codex plan parser upgraded from `ClaudeCodeService`.
- Code block handling:
  - detect language
  - detect likely purpose
  - summarize command/code intent
  - preserve file paths, commands, risks, and acceptance criteria
- Detail levels:
  - Brief: main decisions and next actions.
  - Standard: sections, key details, blockers, commands.
  - Detailed: standard plus task-by-task acceptance checks.

Exit criteria:

- Selected Codex/Claude response can be read in raw or summary mode.
- Plan files no longer drop code blocks silently.
- Fixtures prove markdown headings, bullets, code fences, tables, checkboxes,
  file paths, commands, and acceptance criteria are converted well enough for
  speech.

### Phase 5: AI Conversation Mode

Goal:
Let the user talk to an AI model directly, hear responses, summarize responses,
and optionally write results back into other apps.

Deliverables:

- Provider-neutral AI interfaces.
- Settings UI for provider configuration.
- Credential handling that does not store secrets in plain text.
- Voice prompt flow:
  - capture speech
  - transcribe
  - send to AI
  - stream/display response
  - read full response or summary
  - copy/insert result
- Optional context inclusion:
  - selected text
  - clipboard text
  - active app name
  - current session transcript
- Conversation history with clear reset/delete controls.

Exit criteria:

- AI mode is opt-in and separate from verbatim dictation.
- User can speak a prompt and hear a response.
- User can summarize the AI response before readback.
- User can insert a generated response into the target app after confirmation.

### Phase 6: Workflow UI And Settings Reorganization

Goal:
Make the app usable as a daily driver for voice workflows.

Deliverables:

- Settings tabs reorganized by workflow:
  - General
  - Dictation
  - Readback
  - AI
  - Shortcuts
  - Permissions
  - Advanced
- Shortcut recorder controls.
- Interaction panel for current transcript, response, and target app.
- Overlay states:
  - idle
  - selection available
  - recording hold
  - recording latched
  - processing
  - response ready
  - reading
  - insertion pending
  - error
- Quick actions:
  - read selected text
  - summarize and read
  - ask AI about selection
  - dictate raw
  - dictate AI prompt
  - stop/cancel

Exit criteria:

- User can discover and configure the main workflows without reading source.
- Overlay clearly shows whether recording is held or latched.
- Destructive or surprising insertions require review/confirmation.

### Phase 7: Reliability, Testing, Packaging, And Privacy

Goal:
Make the product robust enough for daily usage and future distribution.

Deliverables:

- SwiftPM test target.
- Fixtures for readback processing.
- Shortcut model tests.
- Settings migration tests.
- Manual QA checklist for app-to-app insertion.
- Permission diagnostics.
- Crash/error logging strategy.
- Build script keeps privacy strings current.
- README updated for new workflows.

Exit criteria:

- `swift build` and `swift test` pass.
- New feature work has focused tests or a documented manual test path.
- Privacy-sensitive behavior is visible and documented.

### Phase 8: Advanced Capabilities

Goal:
Add higher-leverage capabilities only after the core voice interaction loop is
stable.

Candidates:

- Voice activity detection for auto-stop.
- Wake phrase or local command grammar.
- OCR screenshot-to-speech with Vision framework.
- Browser page extraction or extension.
- Reading queue and bookmarks.
- Per-app automation adapters for Codex, browsers, Notes, Mail, Slack, and
  editors.
- Audio export.
- iCloud settings sync.
- Local model support where practical.

## Executable Task Backlog

Use these IDs in commits, PRs, and future Codex sessions.

### Phase 0 Tasks: Stabilize Current Core

#### P0-01: Add SwiftPM Test Target

Scope:
- Update `Package.swift` with a `SpeakEasyTTSTests` test target.
- Add minimal test directory under `Tests/SpeakEasyTTSTests`.

Files:
- `SpeakEasyTTS/Package.swift`
- `SpeakEasyTTS/Tests/SpeakEasyTTSTests/...`

Acceptance:
- `swift test` runs successfully.
- Empty or smoke tests are enough for the first commit.

Suggested commit:
- `test: add SwiftPM test target`

#### P0-02: Extract Markdown Readback Processing Into Testable Unit

Scope:
- Move preprocessing logic out of `ClaudeCodeService` or make it injectable.
- Keep current behavior intact.

Files:
- `Sources/Services/ClaudeCodeService.swift`
- New `Sources/Core/ReadbackPipeline.swift` or `Sources/Services/ReadbackProcessor.swift`
- Test fixtures under `Tests/SpeakEasyTTSTests/Fixtures`

Acceptance:
- Existing "read Claude plan" UI still works.
- Unit tests cover headings, bullets, inline formatting, file paths, and code
  fences.

Suggested commit:
- `refactor: extract readback preprocessing`

#### P0-03: Add Settings Migration Tests

Scope:
- Add testable settings migration for legacy Edge TTS default to native TTS.
- Avoid direct dependence on global `UserDefaults.standard` in tests.

Files:
- `Sources/Services/Services.swift`
- `Sources/Core/AppState.swift` if migration remains there
- `Tests/SpeakEasyTTSTests/SettingsTests.swift`

Acceptance:
- Test proves old Edge default migrates to native.
- Test proves explicit non-default settings are preserved.

Suggested commit:
- `test: cover playback settings migration`

#### P0-04: Create Manual QA Checklist

Scope:
- Add a QA document for permission-heavy flows that cannot be fully automated.

Files:
- `QA.md` or `docs/manual-qa.md`

Acceptance:
- Includes setup, app bundle run instructions, permissions, dictation,
  readback, insertion, Edge TTS optional path, and overlay.

Suggested commit:
- `docs: add manual QA checklist`

### Phase 1 Tasks: Configurable Shortcuts And Trigger Modes

#### P1-01: Define Shortcut Models

Scope:
- Add Codable shortcut model types for key code, modifiers, display name,
  trigger action, and trigger mode.
- Include defaults matching current `Option+D` and `Option+S`.

Files:
- `Sources/Core/ShortcutModels.swift`
- `Sources/Models/Models.swift`
- Tests under `ShortcutModelTests.swift`

Acceptance:
- Defaults round-trip through Codable.
- Display names are stable.
- Model can represent toggle, hold, and hold-plus-space latch modes.

Suggested commit:
- `feat(shortcuts): add shortcut models`

#### P1-02: Store Shortcuts In Settings

Scope:
- Extend `SpeechSettings` or introduce `AppSettings`.
- Preserve backwards compatibility with existing serialized settings.
- Prefer a single settings root if settings grow beyond speech.

Files:
- `Sources/Models/Models.swift`
- `Sources/Services/Services.swift`

Acceptance:
- Existing saved settings decode successfully.
- New shortcut settings persist and reload.
- Reset to defaults restores default shortcuts and trigger modes.

Suggested commit:
- `feat(settings): persist shortcut preferences`

#### P1-03: Refactor HotkeyManager To Register Dynamic Shortcuts

Scope:
- Replace hardcoded private `hotkeys` list with registered shortcut
  definitions from settings.
- Keep existing Carbon behavior for ordinary toggle shortcuts.

Files:
- `Sources/Core/HotkeyManager.swift`
- `Sources/Core/AppState.swift`
- `Sources/Core/ShortcutModels.swift`

Acceptance:
- Default `Option+D` and `Option+S` still work.
- Changing settings re-registers shortcuts without restarting the app.
- Registration failures produce user-visible errors.

Suggested commit:
- `feat(shortcuts): register configured global hotkeys`

#### P1-04: Add Shortcut Recorder UI

Scope:
- Add a reusable SwiftUI recorder control.
- Let user set dictation and readback shortcuts.
- Show conflicts and restore-default buttons.

Files:
- `Sources/Views/SettingsView.swift`
- Optional new `Sources/Views/Settings/ShortcutRecorderView.swift`

Acceptance:
- User can click a control and press a shortcut.
- UI displays the chosen shortcut.
- Invalid or reserved shortcuts are rejected with a clear message.

Suggested commit:
- `feat(settings): add shortcut recorder`

#### P1-05: Support Hold-To-Record

Scope:
- Add key-down/key-up tracking for a configured hold shortcut.
- Start dictation on key down.
- Stop and insert on key up.

Files:
- `Sources/Core/HotkeyManager.swift` or new `ShortcutManager.swift`
- `Sources/Core/AppState.swift`
- `Sources/Models/Models.swift`

Acceptance:
- Hold shortcut starts recording.
- Releasing shortcut stops and inserts.
- Cancelling via UI or Escape works while held.
- Toggle shortcut mode still works.

Suggested commit:
- `feat(dictation): support hold-to-record shortcut mode`

#### P1-06: Support Hold-Plus-Space Latch

Scope:
- While hold-to-record is active, Space toggles latch mode.
- Once latched, releasing the hold key does not stop recording.
- Stop by pressing dictation shortcut again, overlay stop, or configured stop
  key.

Files:
- `Sources/Core/ShortcutManager.swift`
- `Sources/Core/AppState.swift`
- `Sources/Views/FloatingOverlayView.swift`

Acceptance:
- Hold key starts recording.
- Space while held changes overlay to "latched" state.
- Releasing hold key keeps recording.
- Stop action inserts text.

Suggested commit:
- `feat(dictation): add hold space latch mode`

#### P1-07: Function/Globe Key Feasibility Spike

Scope:
- Determine whether Function/Globe key can be captured reliably on the target
  hardware and macOS version.
- Use the smallest working approach: Carbon if possible, otherwise local/global
  event monitor, otherwise event tap, otherwise IOHID spike.

Files:
- Prototype can live in a temporary branch or documented spike note.
- Final note in `ROADMAP.md` or `docs/shortcut-capture-notes.md`.

Acceptance:
- Documented answer for Function/Globe capture.
- If viable, create implementation task for exact capture mechanism.
- If not viable, settings UI offers a clear fallback hold key.

Suggested commit:
- `docs(shortcuts): document function key capture findings`

### Phase 2 Tasks: Interaction Session State Machine

#### P2-01: Add Interaction Session Models

Scope:
- Define session, state, mode, source, destination, and cancellation models.

Files:
- `Sources/Core/InteractionSession.swift`

Acceptance:
- Models compile and are testable.
- Session can represent current dictation and readback flows.

Suggested commit:
- `feat(interactions): add session models`

#### P2-02: Add InteractionCoordinator Skeleton

Scope:
- Create coordinator that AppState can call for dictation/readback actions.
- Initially delegate to existing AppState services.

Files:
- `Sources/Core/InteractionCoordinator.swift`
- `Sources/Core/AppState.swift`

Acceptance:
- Current dictation and readback behavior remains unchanged.
- Coordinator emits session state changes.

Suggested commit:
- `refactor(interactions): route actions through coordinator`

#### P2-03: Move Dictation Flow Into Coordinator

Scope:
- Coordinator owns start, stop, cancel, insert behavior.
- AppState remains observable facade.

Files:
- `Sources/Core/InteractionCoordinator.swift`
- `Sources/Core/AppState.swift`
- `Sources/Core/DictationService.swift`

Acceptance:
- Toggle dictation works.
- Hold modes from Phase 1 work.
- Dictated text insertion still restores pasteboard.

Suggested commit:
- `refactor(dictation): coordinate dictation sessions`

#### P2-04: Add Session Error And Cancellation Handling

Scope:
- Standardize error state and cancellation cleanup.
- Make active sessions cancelable from overlay/menu.

Files:
- `InteractionCoordinator.swift`
- `AppState.swift`
- `FloatingOverlayView.swift`
- `MenuBarView.swift`

Acceptance:
- Cancel recording stops microphone and does not insert.
- Cancel readback stops speech.
- Errors reset to a recoverable idle state.

Suggested commit:
- `feat(interactions): add session cancellation`

### Phase 3 Tasks: Text Source And Destination Services

#### P3-01: Extract AppContextService

Scope:
- Move frontmost/last-external-app tracking out of `ClipboardService`.
- Capture bundle ID, localized name, PID, and timestamps.

Files:
- `Sources/Services/AppContextService.swift`
- `Sources/Services/Services.swift`
- `Sources/Core/AppState.swift`

Acceptance:
- Existing selected-text and insertion behavior still works.
- Tests cover pure model behavior.
- Manual QA covers app focus transitions.

Suggested commit:
- `refactor(app-context): track target app separately`

#### P3-02: Extract TextSourceService

Scope:
- Provide a single interface for selected text, clipboard, manual text, plan
  text, and focused field text when available.

Files:
- `Sources/Services/TextSourceService.swift`
- `Sources/Services/Services.swift`
- `Sources/Services/ClaudeCodeService.swift`

Acceptance:
- `speakSelectedText`, `speakFromClipboard`, and plan readback use text source
  requests.
- Errors identify which source failed.

Suggested commit:
- `refactor(text): add text source service`

#### P3-03: Extract TextDestinationService

Scope:
- Move pasteboard-preserving insertion into a destination service.
- Add destination modes: insert, replace selection, append.

Files:
- `Sources/Services/TextDestinationService.swift`
- `Sources/Services/Services.swift`
- `Sources/Core/AppState.swift`

Acceptance:
- Existing dictation insertion still works.
- Destination service validates target app before insertion.
- Clipboard restore still happens.

Suggested commit:
- `refactor(text): add text destination service`

#### P3-04: Add Target App Revalidation

Scope:
- Before writing generated or dictated text, confirm the target app is still
  available and either focused or intentionally recoverable.

Files:
- `TextDestinationService.swift`
- `AppContextService.swift`
- `InteractionCoordinator.swift`

Acceptance:
- If target app disappears, insertion is cancelled with an error.
- If SpeakEasy is frontmost, insertion still targets the last external app.
- User can retry after focusing a target app.

Suggested commit:
- `feat(text): revalidate target app before insertion`

#### P3-05: Add App Profiles

Scope:
- Introduce profiles for generic apps first, then specific overrides for Codex,
  terminals, browsers, and editors as needed.

Files:
- `Sources/Services/AppProfileService.swift`
- `Sources/Models/AppProfile.swift`

Acceptance:
- Generic profile is used by default.
- Profile can specify preferred read and write strategies.
- No app-specific behavior is hardcoded in UI views.

Suggested commit:
- `feat(text): add app profile model`

### Phase 4 Tasks: Readback Pipeline And Summaries

#### P4-01: Define Readback Requests And Profiles

Scope:
- Add source, profile, detail level, and processing options.

Files:
- `Sources/Core/ReadbackPipeline.swift`
- `Sources/Models/Models.swift` or new `ReadbackModels.swift`

Acceptance:
- Models represent raw, clean prose, technical response, plan summary, and task
  list profiles.
- Defaults preserve existing readback behavior.

Suggested commit:
- `feat(readback): add readback request models`

#### P4-02: Implement Deterministic Markdown Normalizer

Scope:
- Convert markdown to speech-friendly text without AI.
- Handle headings, bullets, numbered lists, checkboxes, links, code spans,
  tables, blockquotes, and file paths.

Files:
- `ReadbackPipeline.swift`
- Tests and fixtures

Acceptance:
- Unit tests cover representative Codex/Claude responses.
- No code blocks are silently lost without a spoken placeholder.

Suggested commit:
- `feat(readback): normalize markdown for speech`

#### P4-03: Summarize Code Blocks Deterministically

Scope:
- For fenced code blocks, produce a non-AI fallback summary:
  - language if present
  - number of lines
  - likely kind: shell command, Swift code, JSON, diff, config, markdown
  - named files or commands if detectable

Files:
- `ReadbackPipeline.swift`
- Tests and fixtures

Acceptance:
- A shell block is summarized as commands, not read line by line.
- A Swift block is summarized as Swift code with line count and visible symbols
  when easy to detect.
- A diff block names changed files when detectable.

Suggested commit:
- `feat(readback): summarize code fences for speech`

#### P4-04: Add AI Summarization Hook

Scope:
- Define interface for optional AI summary, but keep deterministic fallback.
- Do not require provider implementation in this task.

Files:
- `ReadbackPipeline.swift`
- `AIInteractionService.swift`

Acceptance:
- Pipeline can request an AI summary when provider is available.
- Pipeline falls back cleanly when no provider is configured.

Suggested commit:
- `feat(readback): add optional AI summary hook`

#### P4-05: Add Selected Response Summary Action

Scope:
- Add UI action and hotkey-ready command for "summarize and read selection".

Files:
- `MenuBarView.swift`
- `FloatingOverlayView.swift`
- `AppState.swift`
- `ReadbackPipeline.swift`

Acceptance:
- User can select a Codex/Claude response and choose summary readback.
- Summary mode preserves tasks, blockers, commands, files, and decisions.

Suggested commit:
- `feat(readback): summarize selected text before speech`

#### P4-06: Upgrade Plan Reader

Scope:
- Replace direct `ClaudeCodeService.preprocessForSpeech` call with readback
  pipeline profile `planSummary`.

Files:
- `ClaudeCodeService.swift`
- `ReadbackPipeline.swift`
- `AppState.swift`

Acceptance:
- Recent-plan and file-picker readback still work.
- Code blocks are summarized, not dropped.
- Detail level can be changed.

Suggested commit:
- `feat(readback): route plan reading through pipeline`

### Phase 5 Tasks: AI Conversation Mode

#### P5-01: Add AI Provider Protocol

Scope:
- Define provider-neutral request, response, streaming event, and error types.
- Keep provider implementation out of this first task.

Files:
- `Sources/Services/AIProvider.swift`
- Tests for model encoding if needed

Acceptance:
- Protocol supports non-streaming and streaming responses.
- Request can include prompt, selected text, app context, and conversation ID.

Suggested commit:
- `feat(ai): add provider protocol`

#### P5-02: Add AI Settings And Credential State

Scope:
- Add settings UI for provider status without hardcoding secrets.
- Decide secure storage path before implementation.

Files:
- `SettingsView.swift`
- `AIProviderStore.swift`
- Models/settings

Acceptance:
- UI shows not configured/configured/error states.
- No API key is stored in plain text UserDefaults.

Suggested commit:
- `feat(ai): add provider settings shell`

#### P5-03: Implement First AI Provider Adapter

Scope:
- Implement one provider adapter behind `AIProvider`.
- Keep provider-specific code isolated.

Files:
- Provider-specific service file
- `AIProviderStore.swift`
- Tests with mocked transport

Acceptance:
- Mocked tests cover request building and response parsing.
- Runtime errors are user-visible.
- Missing credentials do not crash.

Suggested commit:
- `feat(ai): add first AI provider adapter`

#### P5-04: Add Ask-AI Voice Mode

Scope:
- Add a mode that sends dictated transcript to AI instead of inserting it.
- Keep verbatim dictation unchanged.

Files:
- `InteractionCoordinator.swift`
- `DictationService.swift`
- `AIInteractionService.swift`
- UI views

Acceptance:
- User can choose Ask AI mode.
- User speaks prompt.
- AI response is received and displayed.
- User can read response aloud.

Suggested commit:
- `feat(ai): add voice prompt mode`

#### P5-05: Add Response Actions

Scope:
- Add actions for AI responses:
  - read full response
  - summarize and read
  - copy
  - insert into target app
  - discard

Files:
- `InteractionPanelView.swift`
- `InteractionCoordinator.swift`
- `TextDestinationService.swift`
- `ReadbackPipeline.swift`

Acceptance:
- Insert requires explicit user action.
- Summary readback uses Phase 4 pipeline.
- User can cancel without writing anything.

Suggested commit:
- `feat(ai): add response actions`

#### P5-06: Add Conversation History

Scope:
- Store lightweight local session history.
- Include clear/delete controls.

Files:
- `ConversationStore.swift`
- `AIInteractionService.swift`
- Settings or interaction panel

Acceptance:
- Follow-up prompts can include prior turns when enabled.
- User can clear history.
- History storage is documented.

Suggested commit:
- `feat(ai): persist conversation sessions`

### Phase 6 Tasks: UX And Settings

#### P6-01: Split Settings Views By Domain

Scope:
- Move large settings view into smaller files.

Files:
- `Sources/Views/Settings/...`
- `SettingsView.swift`

Acceptance:
- No behavior change.
- Settings tabs remain available.

Suggested commit:
- `refactor(settings): split settings tabs`

#### P6-02: Add Dictation Settings Tab

Scope:
- Configure dictation mode, trigger behavior, locale, insertion behavior, and
  confirmation preferences.

Files:
- `DictationSettingsView.swift`
- Settings models

Acceptance:
- User can choose toggle, hold, or hold-plus-space latch.
- Locale setting is available or explicitly deferred.

Suggested commit:
- `feat(settings): add dictation settings`

#### P6-03: Add Readback Settings Tab

Scope:
- Configure default readback profile, detail level, auto-read, speed, voice, and
  summary behavior.

Files:
- `ReadbackSettingsView.swift`
- `ReadbackPipeline` models

Acceptance:
- User can choose raw vs summarized default.
- Auto-read remains configurable.

Suggested commit:
- `feat(settings): add readback settings`

#### P6-04: Add Interaction Panel

Scope:
- Show active session transcript, generated text, target app, and actions.

Files:
- `InteractionPanelView.swift`
- `AppState.swift`
- `InteractionCoordinator.swift`

Acceptance:
- User can review generated AI text before insertion.
- User can read, summarize, copy, insert, or discard from one panel.

Suggested commit:
- `feat(ui): add interaction panel`

#### P6-05: Upgrade Overlay State Display

Scope:
- Show recording vs latched vs processing vs response-ready states.
- Add concise controls without bloating the compact overlay.

Files:
- `FloatingOverlayView.swift`
- `FloatingOverlayWindow.swift`

Acceptance:
- Latch state is visible.
- AI response-ready state is visible.
- Stop/cancel remains easy to hit.

Suggested commit:
- `feat(overlay): show interaction states`

### Phase 7 Tasks: Reliability And Distribution

#### P7-01: Add Permission Diagnostics

Scope:
- Centralize permission checks and display status.

Files:
- `PermissionService.swift`
- Settings permissions tab

Acceptance:
- Accessibility, Microphone, Speech Recognition, and optional AI provider state
  are visible.
- Each failed permission includes a recovery action.

Suggested commit:
- `feat(permissions): add diagnostics`

#### P7-02: Add Runtime Logging Strategy

Scope:
- Replace scattered prints with lightweight logging categories.

Files:
- New `Logger` wrapper or direct `OSLog` usage
- Core services

Acceptance:
- Dictation, shortcut, readback, AI, and insertion events are diagnosable.
- No sensitive text is logged by default.

Suggested commit:
- `chore(logging): add runtime log categories`

#### P7-03: Update README For Voice Interaction Workflows

Scope:
- Document new dictation modes, readback modes, AI mode, permissions, and QA.

Files:
- `SpeakEasyTTS/README.md`

Acceptance:
- README matches implemented behavior.
- Setup and troubleshooting are current.

Suggested commit:
- `docs: update voice interaction README`

#### P7-04: Prepare Release Checklist

Scope:
- Add distribution checklist for direct app bundle and later notarization.

Files:
- `RELEASE.md`

Acceptance:
- Includes build, privacy strings, permissions, smoke tests, signing, and
  rollback notes.

Suggested commit:
- `docs: add release checklist`

## Suggested Session Plan

Use these as separate implementation sessions. Each session should end with a
build, tests where available, and a conventional commit.

1. Session 1: P0-01, P0-02, P0-03.
   Add tests and make readback processing testable.

2. Session 2: P1-01, P1-02, P1-03.
   Add configurable shortcut models and dynamic registration while preserving
   default hotkeys.

3. Session 3: P1-04, P1-05.
   Add shortcut recorder UI and hold-to-record mode.

4. Session 4: P1-06, P1-07.
   Add hold-plus-space latch and document Function/Globe feasibility.

5. Session 5: P2-01 through P2-04.
   Introduce interaction sessions and move current dictation through the
   coordinator.

6. Session 6: P3-01 through P3-04.
   Extract app context, text source, and text destination services.

7. Session 7: P4-01 through P4-03.
   Build deterministic readback pipeline and code block summaries.

8. Session 8: P4-04 through P4-06.
   Add optional AI summary hook and upgrade selected response/plan readback.

9. Session 9: P5-01 through P5-04.
   Add AI provider boundary and first ask-AI voice flow.

10. Session 10: P5-05, P5-06, P6-04.
    Add response actions, history, and review panel.

11. Session 11: P6-01 through P6-05.
    Reorganize settings and overlay UX around the new workflows.

12. Session 12: P7-01 through P7-04.
    Add diagnostics, logging, README updates, and release checklist.

## Parallel Work Opportunities

These can be assigned to parallel agents or separate sessions without major
conflicts:

1. Shortcut model/tests and shortcut recorder UI can proceed in parallel after
   P1-01 is agreed.
2. Readback fixtures and deterministic markdown processing can proceed in
   parallel with AI provider interface work.
3. Permission diagnostics can proceed in parallel with settings reorganization.
4. App profile research/manual QA can proceed in parallel with text source and
   destination extraction.
5. README/release docs can proceed after feature names stabilize.

Avoid parallel edits to:

- `AppState.swift` during coordinator extraction.
- `SettingsView.swift` during settings split.
- `Services.swift` during text source/destination extraction.

## Acceptance Matrix For The Original Goal

| Requirement | Roadmap coverage |
| --- | --- |
| Interface the user can talk to | Phases 1, 2, 5, and 6 define trigger modes, sessions, and AI voice mode. |
| App talks back | Phases 4 and 5 define readback pipeline, summaries, and AI response speech. |
| Dictation into any app | Current baseline plus Phases 1, 2, and 3. |
| Talk directly through an AI model | Phase 5. |
| Reads and writes text for any app | Phase 3, with app profiles for exceptions. |
| Codex/Claude response readback | Workflows C and D, Phase 4 tasks. |
| Summarize long responses before reading | Phase 4 tasks P4-04 and P4-05. |
| Claude Code plan processing | Current baseline plus P4-06 upgrade. |
| Skip/summarize code blocks | P4-03 and P4-06. |
| Configurable dictation hotkey | P1-01 through P1-04. |
| Configurable read-text hotkey | P1-01 through P1-04. |
| Press-and-hold dictation | P1-05. |
| Hold key plus Space latch mode | P1-06 and P1-07. |
| User-configurable trigger behavior | Phase 1 and Phase 6 settings tasks. |

## Definition Of Done For The Full Product

The roadmap is complete when:

1. Native dictation and native readback are reliable without AI.
2. User can configure dictation and readback triggers.
3. User can use toggle, hold, and hold-plus-space latch dictation modes.
4. User can read selected text, clipboard text, current plan files, and AI
   responses.
5. User can summarize long technical responses before readback.
6. User can speak to an AI model and hear the response.
7. User can insert dictated or generated text into the intended target app.
8. The app shows enough session state to understand what it is recording,
   reading, processing, or about to write.
9. Permission and provider failures are recoverable.
10. Tests and manual QA cover the core pipelines.
