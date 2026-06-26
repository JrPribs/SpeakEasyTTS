// InteractionPanelView.swift
// Active voice workflow review panel.

import SwiftUI

struct InteractionPanelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if let session = appState.activeInteractionSession,
               session.state != .idle,
               !session.state.isTerminal {
                panel(for: session)
            }
        }
    }

    private func panel(for session: InteractionSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header(for: session)
            targetRow(for: session)
            transcriptSection(for: session)
            generatedTextSection(for: session)
            failureSection(for: session)
            aiActions(for: session)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
    }

    private func header(for session: InteractionSession) -> some View {
        HStack(spacing: 8) {
            Label(session.mode.displayName, systemImage: iconName(for: session.mode))
                .font(.subheadline.weight(.semibold))

            Text(stateTitle(for: session.state))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.tertiaryLabelColor).opacity(0.18))
                .cornerRadius(4)

            Spacer()

            if appState.canCancelActiveInteraction && !usesDiscardAsCancel(for: session) {
                Button {
                    appState.cancelActiveInteraction()
                } label: {
                    Label(cancelTitle(for: session), systemImage: cancelIcon(for: session))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private func targetRow(for session: InteractionSession) -> some View {
        if let appContext = visibleAppContext(for: session) {
            HStack(spacing: 6) {
                Image(systemName: "app.connected.to.app.below.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(appContextRole(for: session))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(appContext.appName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()
            }

            if let bundleIdentifier = appContext.bundleIdentifier {
                Text(bundleIdentifier)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func transcriptSection(for session: InteractionSession) -> some View {
        if let transcript = nonEmpty(session.transcript) {
            textPreview(
                title: session.mode == .askAI ? "Prompt" : "Transcript",
                systemImage: "text.quote",
                text: transcript,
                lineLimit: 3,
                foregroundStyle: .secondary
            )
        }
    }

    @ViewBuilder
    private func generatedTextSection(for session: InteractionSession) -> some View {
        if let generatedText = nonEmpty(session.generatedText) {
            textPreview(
                title: session.mode == .askAI ? "Response" : "Text",
                systemImage: session.mode == .askAI ? "sparkles" : "text.alignleft",
                text: generatedText,
                lineLimit: 5,
                foregroundStyle: .primary
            )
        }
    }

    @ViewBuilder
    private func failureSection(for session: InteractionSession) -> some View {
        if let failure = session.failure {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)

                Text(failure.message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func aiActions(for session: InteractionSession) -> some View {
        if session.mode == .askAI,
           hasReviewableAIResponse(session) {
            let canModifyResponse = session.state == .awaitingUserReview

            HStack(spacing: 8) {
                Button {
                    appState.readCurrentAIResponse()
                } label: {
                    Label("Read", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    appState.summarizeAndReadCurrentAIResponse()
                } label: {
                    Label("Summary", systemImage: "text.bubble")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canModifyResponse)

                Button {
                    appState.copyCurrentAIResponse()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }

            HStack(spacing: 8) {
                Button {
                    appState.insertCurrentAIResponse()
                } label: {
                    Label("Insert", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canModifyResponse)

                Button(role: .destructive) {
                    appState.discardCurrentAIResponse()
                } label: {
                    Label("Discard", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
        }
    }

    private func textPreview(
        title: String,
        systemImage: String,
        text: String,
        lineLimit: Int,
        foregroundStyle: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(text)
                .font(.caption)
                .foregroundStyle(foregroundStyle)
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
        }
    }

    private func visibleAppContext(for session: InteractionSession) -> AppContext? {
        session.targetApp ?? session.destination.appContext ?? session.source.appContext
    }

    private func appContextRole(for session: InteractionSession) -> String {
        if session.targetApp != nil || session.destination.appContext != nil {
            return "Target"
        }

        return "Source"
    }

    private func hasReviewableAIResponse(_ session: InteractionSession) -> Bool {
        session.mode == .askAI && nonEmpty(session.generatedText) != nil
    }

    private func usesDiscardAsCancel(for session: InteractionSession) -> Bool {
        session.mode == .askAI
            && session.state == .awaitingUserReview
            && hasReviewableAIResponse(session)
    }

    private func stateTitle(for state: InteractionState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .preparing:
            return "Preparing"
        case .recording:
            return "Recording"
        case .transcribing:
            return "Transcribing"
        case .processing:
            return "Processing"
        case .awaitingUserReview:
            return "Review"
        case .inserting:
            return "Inserting"
        case .reading:
            return "Reading"
        case .completed:
            return "Done"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func iconName(for mode: InteractionMode) -> String {
        switch mode {
        case .dictateVerbatim:
            return "mic.fill"
        case .readback:
            return "speaker.wave.2.fill"
        case .askAI:
            return "sparkles"
        case .transformText:
            return "wand.and.stars"
        }
    }

    private func cancelTitle(for session: InteractionSession) -> String {
        session.mode == .readback || session.state == .reading ? "Stop" : "Cancel"
    }

    private func cancelIcon(for session: InteractionSession) -> String {
        session.mode == .readback ? "stop.fill" : "xmark.circle"
    }

    private func nonEmpty(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if canImport(PreviewsMacros)
#Preview {
    InteractionPanelView()
        .environment(AppState.shared)
}
#endif
