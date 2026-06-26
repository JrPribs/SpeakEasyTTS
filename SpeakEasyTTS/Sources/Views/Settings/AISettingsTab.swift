import SwiftUI

struct AISettingsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Provider") {
                HStack {
                    Text("Status")
                    Spacer()
                    Label(
                        appState.aiProviderStatus.state.displayName,
                        systemImage: appState.aiProviderStatus.state.systemImage
                    )
                    .foregroundStyle(statusColor)
                }

                HStack {
                    Text("Provider")
                    Spacer()
                    Text(appState.aiProviderStatus.providerID ?? "None")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Credential Storage")
                    Spacer()
                    Text(appState.aiProviderStatus.credentialStorage.displayName)
                        .foregroundStyle(.secondary)
                }

                if let message = appState.aiProviderStatus.message,
                   !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Credentials") {
                Text("Secrets are reserved for macOS Keychain. UserDefaults stores only provider status.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Reset Provider State") {
                    appState.resetAIProviderStatus()
                }
                .disabled(appState.aiProviderStatus.state == .notConfigured)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            appState.refreshAIProviderStatus()
        }
    }

    private var statusColor: Color {
        switch appState.aiProviderStatus.state {
        case .notConfigured:
            return .secondary
        case .configured:
            return .green
        case .error:
            return .red
        }
    }
}
