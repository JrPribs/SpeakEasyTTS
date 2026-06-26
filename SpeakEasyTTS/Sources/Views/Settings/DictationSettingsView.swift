import SwiftUI

struct DictationSettingsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Mode") {
                HStack {
                    Text("Recognition")
                    Spacer()
                    Label("Verbatim", systemImage: "text.quote")
                        .foregroundStyle(.secondary)
                }

                Text("Dictation inserts the recognized words directly, with no AI rewrite or cleanup step.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Trigger Behavior") {
                Picker("Dictation Shortcut", selection: Binding(
                    get: { appState.settings.shortcuts.dictation.triggerMode ?? .toggle },
                    set: { appState.updateDictationTriggerMode($0) }
                )) {
                    ForEach(DictationTriggerMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text("Hold with Space Latch lets the dictation shortcut start recording, then Space latches or unlatches recording while the shortcut is held.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Insertion") {
                HStack {
                    Text("Destination")
                    Spacer()
                    Label("Focused Target App", systemImage: "text.cursor")
                        .foregroundStyle(.secondary)
                }

                Text("Dictation stops by shortcut, overlay stop, or final speech result, then inserts into the tracked target app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Locale") {
                HStack {
                    Text("Recognition Locale")
                    Spacer()
                    Label("System Default", systemImage: "globe")
                        .foregroundStyle(.secondary)
                }

                Text("Explicit locale selection is deferred until dictation service locale switching is implemented.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Confirmation") {
                HStack {
                    Text("Before Inserting")
                    Spacer()
                    Label("Insert Immediately", systemImage: "return")
                        .foregroundStyle(.secondary)
                }

                Text("Review-before-insert is deferred; current verbatim dictation preserves the existing immediate insertion workflow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
