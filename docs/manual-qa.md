# Manual QA Checklist

Use this checklist for permission-heavy SpeakEasy Flow behavior that cannot be
covered reliably by automated tests. Record the app version or commit, macOS
version, tester, date, and any failures before merging release-bound changes.

## Setup

- [ ] Start from a clean build:

  ```bash
  cd /Users/john/code/SpeakEasyTTS/SpeakEasyTTS
  ./build.sh
  ```

- [ ] Run the generated app bundle, not `swift run`, so macOS sees the privacy
      usage strings from `Info.plist`:

  ```bash
  open build/release/SpeakEasyTTS.app
  ```

- [ ] Confirm the SpeakEasy Flow menu bar item appears and the app does not show
      a Dock icon.
- [ ] Open a target app with an editable text field, such as TextEdit, Notes, or
      Safari, and keep a short test document ready.
- [ ] Optional first-run reset: if testing prompts from a clean permission state,
      remove SpeakEasyTTS from System Settings privacy panes or run:

  ```bash
  tccutil reset Accessibility com.speakeasy.tts
  tccutil reset Microphone com.speakeasy.tts
  tccutil reset SpeechRecognition com.speakeasy.tts
  ```

## Permissions

- [ ] Accessibility: open System Settings -> Privacy & Security ->
      Accessibility, enable SpeakEasyTTS, and relaunch the app if macOS asks.
      `Option+D`, `Option+S`, selected-text readback, and insertion into another
      app should work only after this permission is granted.
- [ ] Microphone: start dictation and grant microphone access when prompted.
      If access is denied, dictation should not crash and the user should be
      able to recover by enabling SpeakEasyTTS in System Settings -> Privacy &
      Security -> Microphone.
- [ ] Speech Recognition: start dictation and grant speech recognition access
      when prompted. If access is denied, dictation should not crash and the
      user should be able to recover by enabling SpeakEasyTTS in System Settings
      -> Privacy & Security -> Speech Recognition.
- [ ] Permission recovery: after granting any missing permission, quit and reopen
      SpeakEasyTTS, then repeat the blocked action successfully.

## Dictation And Insertion

- [ ] Focus a text field in the target app.
- [ ] Press `Option+D` and confirm the menu/overlay shows recording state.
- [ ] Speak a short phrase with distinctive wording, such as "manual QA
      dictation sample".
- [ ] Press `Option+D` again to stop recording.
- [ ] Confirm the recognized text is inserted into the originally focused text
      field, not into SpeakEasy.
- [ ] Confirm dictation is verbatim enough for a smoke test: no AI rewrite,
      summary, or style cleanup is applied.
- [ ] Repeat while SpeakEasy is visible but the target app was focused before
      starting dictation; insertion should still return to the last focused app.
- [ ] Repeat with no editable target focused and confirm the app fails safely:
      no crash and no unexpected paste into an unrelated app.

## Readback

- [ ] Type text in the menu bar input field and start playback with the play
      control or `Cmd+Return`.
- [ ] Pause, resume, and stop playback; controls should reflect the current
      playback state.
- [ ] Copy a short sentence to the clipboard and choose Read Clipboard; the
      copied sentence should be spoken.
- [ ] Select text in another app and press `Option+S`; the selected text should
      be spoken.
- [ ] Select text in a browser or Codex/Claude response if available and repeat
      `Option+S`; selected-text readback should work through Accessibility or
      the clipboard fallback.
- [ ] With no selected text, trigger selected-text readback and confirm the app
      fails safely without speaking stale or unrelated content.

## Clipboard Preservation

- [ ] Copy a sentinel value, such as `CLIPBOARD_SENTINEL_123`, before testing a
      selected-text readback flow.
- [ ] Select different text in another app and trigger `Option+S`.
- [ ] Paste into a scratch document and confirm the sentinel clipboard value is
      still present after readback.
- [ ] Copy the sentinel value again, perform a dictation insertion into another
      app, then paste into a scratch document.
- [ ] Confirm the sentinel clipboard value is restored after dictation insertion
      and the recognized text was inserted only into the target field.

## Floating Overlay

- [ ] Open the floating overlay from the menu bar UI if it is not already
      visible.
- [ ] Confirm the overlay stays above normal windows without stealing focus from
      the target text field during dictation setup.
- [ ] Drag the overlay to another screen position and confirm it remains usable.
- [ ] Start and stop dictation; overlay state should match recording state.
- [ ] Start readback, then pause/resume/stop from the overlay if controls are
      available; playback state should stay in sync with the menu UI.
- [ ] Move between displays or spaces if available; the overlay should remain
      visible, correctly sized, and not cover system permission prompts.

## Optional Edge TTS Path

- [ ] Install the optional Edge TTS dependency if it is not already present:

  ```bash
  python3 -m pip install edge-tts
  ```

- [ ] In SpeakEasy Settings, switch the TTS engine from Native to Edge TTS.
- [ ] Confirm Edge voices load or the app reports a recoverable error.
- [ ] Speak text from manual input and clipboard using an Edge voice.
- [ ] Switch back to Native TTS and confirm playback still works offline.
- [ ] If the network is unavailable or `edge-tts` is missing, confirm the app
      does not crash and the user can return to Native TTS.

## Completion

- [ ] All required checks pass on the app bundle.
- [ ] Any failed check includes macOS version, permission state, target app,
      reproduction steps, expected behavior, and actual behavior.
- [ ] No source code or tests were changed as part of this manual QA pass.
