# Conversation History

Ask AI conversation history is stored locally in plain text `UserDefaults` under `com.speakeasy.ai-conversation.session`.

History is disabled by default. When enabled, SpeakEasy includes recent Ask AI turns as context for follow-up prompts and appends successful AI responses to the local session. The default store keeps the latest 20 turns. Readback summaries and verbatim dictation do not update this history.

The menu bar Ask AI section shows the stored turn count, a history checkbox, and a clear button. Clearing history removes stored turns and starts a fresh local session without changing the enabled setting.
