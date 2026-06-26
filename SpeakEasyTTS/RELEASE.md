# Release Checklist

Use this checklist for direct app bundle releases. Complete it from the SwiftPM package directory:

```bash
cd /Users/john/code/SpeakEasyTTS/SpeakEasyTTS
```

Record the release version, commit SHA, macOS version, tester, and date before starting.

## Preflight

- [ ] Confirm the working tree is clean.
- [ ] Confirm the release commit is pushed.
- [ ] Confirm `build.sh` has the intended `APP_NAME`, `BUNDLE_ID`, `VERSION`, and `CFBundleVersion`.
- [ ] Confirm `Package.swift` still targets the supported macOS range.
- [ ] Confirm no debug-only provider keys, secrets, or local paths are documented as required release inputs.

## Automated Gates

Run:

```bash
swift test
swift build
git diff --check
```

- [ ] `swift test` succeeds.
- [ ] `swift build` succeeds.
- [ ] `git diff --check` succeeds.
- [ ] Any known warnings are recorded in release notes.

## Build The App Bundle

Run:

```bash
./build.sh
```

- [ ] `build/release/SpeakEasyTTS.app` exists.
- [ ] `SpeakEasyTTS.app/Contents/MacOS/SpeakEasyTTS` exists and is executable.
- [ ] `SpeakEasyTTS.app/Contents/Info.plist` exists.
- [ ] The bundle launches:

  ```bash
  open build/release/SpeakEasyTTS.app
  ```

## Privacy Strings

Inspect the generated plist:

```bash
/usr/libexec/PlistBuddy -c "Print :NSMicrophoneUsageDescription" build/release/SpeakEasyTTS.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Print :NSSpeechRecognitionUsageDescription" build/release/SpeakEasyTTS.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Print :LSUIElement" build/release/SpeakEasyTTS.app/Contents/Info.plist
```

- [ ] Microphone usage string explains local dictation.
- [ ] Speech Recognition usage string explains speech-to-text.
- [ ] `LSUIElement` is true for menu bar behavior.
- [ ] Bundle identifier is `com.speakeasy.tts`.

## Permissions Smoke Test

Use the app bundle, not `swift run`.

- [ ] Settings -> Permissions shows Accessibility, Microphone, Speech Recognition, and AI Provider.
- [ ] Accessibility recovery opens the correct System Settings pane or system prompt.
- [ ] Microphone recovery opens the Microphone privacy pane.
- [ ] Speech Recognition recovery opens the Speech Recognition privacy pane.
- [ ] Missing permissions fail safely with a visible message and no crash.
- [ ] After granting permissions and relaunching, diagnostics update correctly.

## Functional Smoke Test

- [ ] Menu bar item appears and the app has no Dock icon.
- [ ] Native TTS reads manual input.
- [ ] Read Clipboard speaks clipboard text.
- [ ] `Option+S` reads selected text from another app after Accessibility is granted.
- [ ] `Option+D` starts and stops verbatim dictation.
- [ ] Dictation inserts into the originally focused target text field.
- [ ] Hold-to-record and Space-latch modes show the expected overlay states.
- [ ] Ask AI can record a prompt, show processing, and show response-ready review state when the provider is available.
- [ ] Ask AI response actions work: Read, Copy, Insert, Discard.
- [ ] Readback settings change raw vs summarized default behavior.
- [ ] Floating overlay stays non-activating and keeps controls usable.
- [ ] Edge TTS either works when `edge-tts` is installed or reports a recoverable error.

Reference the broader manual checklist in `../docs/manual-qa.md` for permission reset commands and deeper coverage.

## Signing

Current direct bundle builds are unsigned unless a release owner signs them after `build.sh`.

Ad hoc validation:

```bash
codesign --verify --deep --strict --verbose=2 build/release/SpeakEasyTTS.app
spctl --assess --type execute --verbose build/release/SpeakEasyTTS.app
```

- [ ] If unsigned direct distribution is intentional, document Gatekeeper expectations in release notes.
- [ ] If signing for distribution, sign with the intended Developer ID Application identity.
- [ ] Re-run `codesign --verify --deep --strict --verbose=2`.
- [ ] Re-run the functional smoke test after signing.

## Notarization Path

For a future notarized direct release:

- [ ] Sign with hardened runtime and the correct Developer ID Application identity.
- [ ] Confirm entitlements match actual capabilities.
- [ ] Zip or package the signed app for notarization.
- [ ] Submit with `xcrun notarytool submit --wait`.
- [ ] Staple with `xcrun stapler staple`.
- [ ] Verify on a clean machine or clean user account.
- [ ] Confirm first-launch permission prompts still appear with the release bundle.

## Packaging

- [ ] Create the final distributable from the signed/notarized app bundle.
- [ ] Include release notes with version, commit SHA, known warnings, and required permissions.
- [ ] Do not include local build artifacts, logs, provider secrets, or test data.
- [ ] Archive the exact app bundle and release notes in the release artifact location.

## Rollback

- [ ] Keep the previous known-good app bundle available.
- [ ] Record the previous release version and commit SHA.
- [ ] If the new release fails permission prompts, TTS playback, or dictation insertion, remove the new artifact from distribution and restore the previous bundle.
- [ ] If user settings migration causes issues, document whether users should reset UserDefaults keys:

  ```bash
  defaults delete com.speakeasy.tts
  ```

- [ ] File a follow-up issue with the failed checklist item, logs category, macOS version, and reproduction steps.
