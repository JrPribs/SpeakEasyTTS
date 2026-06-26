import SwiftUI

struct PermissionsSettingsTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Required") {
                ForEach(requiredDiagnostics) { diagnostic in
                    PermissionDiagnosticRow(
                        diagnostic: diagnostic,
                        performRecovery: appState.performPermissionRecovery
                    )
                }
            }

            Section("Optional") {
                ForEach(optionalDiagnostics) { diagnostic in
                    PermissionDiagnosticRow(
                        diagnostic: diagnostic,
                        performRecovery: appState.performPermissionRecovery
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            appState.refreshPermissionDiagnostics()
        }
    }

    private var requiredDiagnostics: [PermissionDiagnostic] {
        appState.permissionDiagnostics.filter { $0.id != .aiProvider }
    }

    private var optionalDiagnostics: [PermissionDiagnostic] {
        appState.permissionDiagnostics.filter { $0.id == .aiProvider }
    }
}

private struct PermissionDiagnosticRow: View {
    var diagnostic: PermissionDiagnostic
    var performRecovery: (PermissionRecoveryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(diagnostic.title, systemImage: diagnostic.state.systemImage)
                    .foregroundStyle(statusColor)

                Spacer()

                Text(diagnostic.state.displayName)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Text(diagnostic.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let recoveryAction = diagnostic.recoveryAction {
                Button(recoveryAction.title) {
                    performRecovery(recoveryAction)
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 3)
    }

    private var statusColor: Color {
        switch diagnostic.state {
        case .granted:
            return .green
        case .needsAction:
            return .orange
        case .denied, .restricted, .error:
            return .red
        case .optional:
            return .secondary
        }
    }
}
