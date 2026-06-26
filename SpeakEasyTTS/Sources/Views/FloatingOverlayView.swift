// FloatingOverlayView.swift
// Always-on-top floating pill widget for quick TTS access

import SwiftUI
import AppKit

struct OverlayInteractionStatus: Equatable {
    enum Kind: Equatable {
        case noAccess
        case aiResponseReady
        case aiProcessing
        case askAIRecording
        case latchedDictation
        case recording
        case authorizing
        case reading
        case autoReading
        case selectedText
        case speaking
        case paused
        case ready
    }

    enum Tone: Equatable {
        case orange
        case pink
        case red
        case indigo
        case purple
        case blue
        case mint
        case green
    }

    var kind: Kind
    var title: String
    var badgeText: String?
    var systemImageName: String
    var helpText: String
    var tone: Tone

    var isActive: Bool {
        kind != .ready
    }

    static func resolve(
        hasAccessibilityPermissions: Bool,
        hasSelection: Bool,
        isAutoReading: Bool,
        dictationState: DictationState,
        triggerState: DictationTriggerState,
        playbackState: PlaybackState,
        activeSession: InteractionSession?
    ) -> OverlayInteractionStatus {
        if !hasAccessibilityPermissions {
            return OverlayInteractionStatus(
                kind: .noAccess,
                title: "No Access",
                badgeText: "LOCK",
                systemImageName: "lock.fill",
                helpText: "Open Accessibility Settings",
                tone: .orange
            )
        }

        if let activeSession,
           activeSession.state != .idle,
           !activeSession.state.isTerminal {
            if let status = resolveActiveSession(activeSession, dictationState: dictationState) {
                return status
            }
        }

        if isLatched(triggerState) {
            return OverlayInteractionStatus(
                kind: .latchedDictation,
                title: "Latched",
                badgeText: "PIN",
                systemImageName: "pin.fill",
                helpText: "Stop latched dictation and insert text",
                tone: .pink
            )
        }

        switch dictationState {
        case .authorizing:
            return OverlayInteractionStatus(
                kind: .authorizing,
                title: "Authorizing",
                badgeText: "AUTH",
                systemImageName: "lock.open",
                helpText: "Cancel dictation",
                tone: .indigo
            )
        case .recording:
            return OverlayInteractionStatus(
                kind: .recording,
                title: "Recording",
                badgeText: "REC",
                systemImageName: "mic.fill",
                helpText: helpTextForRecording(triggerState),
                tone: .red
            )
        case .idle:
            break
        }

        if isAutoReading {
            return OverlayInteractionStatus(
                kind: .autoReading,
                title: "Auto Read",
                badgeText: "READ",
                systemImageName: "waveform",
                helpText: "Reading selected text",
                tone: .purple
            )
        }

        if hasSelection && playbackState == .idle {
            return OverlayInteractionStatus(
                kind: .selectedText,
                title: "Selection",
                badgeText: nil,
                systemImageName: "text.cursor",
                helpText: "Read selected text",
                tone: .blue
            )
        }

        switch playbackState {
        case .playing:
            return OverlayInteractionStatus(
                kind: .speaking,
                title: "Speaking",
                badgeText: "READ",
                systemImageName: "speaker.wave.3.fill",
                helpText: "Pause speech",
                tone: .mint
            )
        case .paused:
            return OverlayInteractionStatus(
                kind: .paused,
                title: "Paused",
                badgeText: "PAUSE",
                systemImageName: "pause.fill",
                helpText: "Resume speech",
                tone: .orange
            )
        case .idle:
            return OverlayInteractionStatus(
                kind: .ready,
                title: "Ready",
                badgeText: nil,
                systemImageName: "speaker.wave.2.fill",
                helpText: "Expand overlay controls",
                tone: .blue
            )
        }
    }

    private static func resolveActiveSession(
        _ session: InteractionSession,
        dictationState: DictationState
    ) -> OverlayInteractionStatus? {
        switch session.mode {
        case .askAI:
            return resolveAskAI(session, dictationState: dictationState)
        case .dictateVerbatim:
            return nil
        case .readback:
            if session.state == .reading {
                return OverlayInteractionStatus(
                    kind: .reading,
                    title: "Reading",
                    badgeText: "READ",
                    systemImageName: "speaker.wave.3.fill",
                    helpText: "Stop reading",
                    tone: .mint
                )
            }
            return nil
        case .transformText:
            if session.state == .processing {
                return OverlayInteractionStatus(
                    kind: .aiProcessing,
                    title: "Processing",
                    badgeText: "AI",
                    systemImageName: "sparkles",
                    helpText: "Cancel active interaction",
                    tone: .purple
                )
            }
            return nil
        }
    }

    private static func resolveAskAI(
        _ session: InteractionSession,
        dictationState: DictationState
    ) -> OverlayInteractionStatus {
        if session.state == .awaitingUserReview,
           nonEmpty(session.generatedText) != nil {
            return OverlayInteractionStatus(
                kind: .aiResponseReady,
                title: "Response Ready",
                badgeText: "READY",
                systemImageName: "text.bubble.fill",
                helpText: "Review AI response",
                tone: .green
            )
        }

        switch session.state {
        case .preparing:
            return OverlayInteractionStatus(
                kind: .askAIRecording,
                title: "Ask AI",
                badgeText: "ASK",
                systemImageName: "mic.badge.plus",
                helpText: "Cancel prompt",
                tone: .indigo
            )
        case .recording:
            return OverlayInteractionStatus(
                kind: .askAIRecording,
                title: "Prompting",
                badgeText: "ASK",
                systemImageName: "mic.badge.plus",
                helpText: dictationState == .recording ? "Send prompt" : "Cancel prompt",
                tone: .red
            )
        case .transcribing, .processing:
            return OverlayInteractionStatus(
                kind: .aiProcessing,
                title: "Processing",
                badgeText: "AI",
                systemImageName: "sparkles",
                helpText: "Cancel AI response",
                tone: .purple
            )
        case .reading:
            return OverlayInteractionStatus(
                kind: .reading,
                title: "Reading",
                badgeText: "READ",
                systemImageName: "speaker.wave.3.fill",
                helpText: "Stop reading",
                tone: .mint
            )
        case .inserting:
            return OverlayInteractionStatus(
                kind: .aiProcessing,
                title: "Inserting",
                badgeText: "SEND",
                systemImageName: "arrow.down.doc.fill",
                helpText: "Cancel insertion",
                tone: .purple
            )
        case .idle, .awaitingUserReview, .completed, .failed, .cancelled:
            return OverlayInteractionStatus(
                kind: .aiProcessing,
                title: "Ask AI",
                badgeText: "AI",
                systemImageName: "sparkles",
                helpText: "Cancel active interaction",
                tone: .purple
            )
        }
    }

    private static func isLatched(_ triggerState: DictationTriggerState) -> Bool {
        switch triggerState {
        case .holding(_, let isLatched):
            return isLatched
        case .latched:
            return true
        case .inactive:
            return false
        }
    }

    private static func helpTextForRecording(_ triggerState: DictationTriggerState) -> String {
        if case .holding(let canLatch, _) = triggerState,
           canLatch {
            return "Release to finish. Press Space to latch."
        }

        return "Stop dictation and insert text"
    }

    private static func nonEmpty(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Floating pill-shaped overlay that stays on top of all windows
struct FloatingOverlayView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.floatingOverlay) private var floatingOverlay
    
    @State private var isPinnedExpanded = false
    @State private var isHovering = false
    @State private var isDragging = false
    @State private var isAutoReading = false
    @State private var pulseSelection = false
    @State private var hoverCollapseTask: Task<Void, Never>?
    @State private var autoReadDebounceTask: Task<Void, Never>?
    @State private var lastAutoReadSignature: String = ""
    @State private var lastAutoReadAt: Date = .distantPast
    
    private var collapsedWidth: CGFloat {
        appState.hasAccessibilityPermissions ? 50 : 100
    }
    private let expandedWidth: CGFloat = 362
    
    private var hasSelection: Bool {
        appState.hasSelectedText
    }
    
    private var shouldExpand: Bool {
        isPinnedExpanded || isHovering
    }
    
    private var controlsVisible: Bool {
        shouldExpand && !isDragging
    }

    private var overlayStatus: OverlayInteractionStatus {
        OverlayInteractionStatus.resolve(
            hasAccessibilityPermissions: appState.hasAccessibilityPermissions,
            hasSelection: hasSelection,
            isAutoReading: isAutoReading,
            dictationState: appState.dictationState,
            triggerState: appState.dictationTriggerState,
            playbackState: appState.playbackState,
            activeSession: appState.activeInteractionSession
        )
    }
    
    private var isActiveState: Bool {
        overlayStatus.isActive
    }
    
    var body: some View {
        HStack(spacing: 10) {
            statusButton

            if !shouldExpand && !appState.hasAccessibilityPermissions {
                Text("No Access")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }

            if controlsVisible {
                expandedControls
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .padding(.horizontal, shouldExpand ? 12 : 8)
        .padding(.vertical, 8)
        .frame(width: shouldExpand ? expandedWidth : collapsedWidth, alignment: .leading)
        .background(glassBackground)
        .overlay(glassEdges)
        .contentShape(Capsule())
        .opacity(shellOpacity)
        .scaleEffect(isHovering && !isDragging ? 1.013 : 1.0)
        .animation(.spring(response: 0.24, dampingFraction: 0.84), value: shouldExpand)
        .animation(.easeInOut(duration: 0.16), value: isHovering)
        .animation(.easeInOut(duration: 0.18), value: appState.playbackState)
        .animation(.easeInOut(duration: 0.18), value: overlayStatus.kind)
        .animation(.easeInOut(duration: 0.18), value: hasSelection)
        .onAppear {
            floatingOverlay.updateSize(width: shouldExpand ? expandedWidth : collapsedWidth)
        }
        .onChange(of: shouldExpand) { _, expanded in
            floatingOverlay.updateSize(width: expanded ? expandedWidth : collapsedWidth)
        }
        .onChange(of: appState.hasAccessibilityPermissions) { _, _ in
            if !shouldExpand {
                floatingOverlay.updateSize(width: collapsedWidth)
            }
        }
        .onHover { hovering in
            guard !isDragging else { return }
            hoverCollapseTask?.cancel()
            
            if hovering {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isHovering = true
                }
            } else {
                hoverCollapseTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 160_000_000)
                    if Task.isCancelled { return }
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isHovering = false
                    }
                }
            }
        }
        .onChange(of: appState.hasSelectedText) { _, newValue in
            if newValue && appState.settings.autoReadOnSelection {
                triggerAutoRead()
            } else if !newValue {
                cancelAutoRead()
            }
        }
        .onDisappear {
            hoverCollapseTask?.cancel()
            cancelAutoRead()
            floatingOverlay.endDrag()
        }
        .simultaneousGesture(dragGesture)
    }
    
    private var glassBackground: some View {
        ZStack {
            Color.black.opacity(0.82)

            statusColor.opacity(isActiveState ? 0.10 : 0.05)
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
    }

    private var glassEdges: some View {
        Capsule()
            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
    }

    private var shellOpacity: Double {
        if isHovering || shouldExpand || isActiveState {
            return 1.0
        }
        return 0.94
    }
    
    // MARK: - Drag
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { _ in
                let mouseLocation = NSEvent.mouseLocation
                if !isDragging {
                    isDragging = true
                    floatingOverlay.beginDrag(at: mouseLocation)
                }
                floatingOverlay.updateDrag(to: mouseLocation)
            }
            .onEnded { _ in
                isDragging = false
                floatingOverlay.endDrag()
            }
    }
    
    // MARK: - Actions
    
    private func handlePrimaryTap() {
        if appState.activeInteractionSession?.mode == .askAI {
            switch appState.activeInteractionSession?.state {
            case .recording:
                appState.toggleAskAI()
                return
            case .preparing, .processing, .transcribing, .awaitingUserReview, .reading, .inserting:
                withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                    isPinnedExpanded = true
                }
                return
            case .idle, .completed, .failed, .cancelled, .none:
                break
            }
        }

        if appState.dictationState == .recording {
            appState.stopDictationAndInsert()
            return
        }

        if appState.dictationState == .authorizing {
            appState.cancelDictation()
            return
        }

        if !appState.hasAccessibilityPermissions {
            appState.openAccessibilitySettings()
            return
        }
        
        if hasSelection {
            appState.speakSelectedText()
        } else {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                isPinnedExpanded.toggle()
            }
        }
    }
    
    private func triggerAutoRead() {
        autoReadDebounceTask?.cancel()
        
        let delay = appState.settings.autoReadDelay
        autoReadDebounceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { return }
                guard appState.settings.autoReadOnSelection, appState.hasSelectedText else { return }
                guard appState.playbackState == .idle else { return }
                
                appState.clipboardService.getSelectedText { text in
                    guard let text else { return }
                    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !normalized.isEmpty else { return }
                    
                    let signature = String(normalized.prefix(200))
                    let now = Date()
                    let justReadSameText = signature == lastAutoReadSignature && now.timeIntervalSince(lastAutoReadAt) < 2.0
                    guard !justReadSameText else { return }
                    
                    lastAutoReadSignature = signature
                    lastAutoReadAt = now
                    
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isAutoReading = true
                        pulseSelection = true
                    }
                    
                    appState.speak(normalized)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            pulseSelection = false
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isAutoReading = false
                        }
                    }
                }
            } catch {
                // Debounce task cancelled.
            }
        }
    }
    
    private func cancelAutoRead() {
        autoReadDebounceTask?.cancel()
        autoReadDebounceTask = nil
        withAnimation(.easeOut(duration: 0.16)) {
            isAutoReading = false
            pulseSelection = false
        }
    }
    
    // MARK: - UI
    
    private var statusButton: some View {
        Button(action: handlePrimaryTap) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                statusColor.opacity(0.96),
                                statusColor.opacity(0.74)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.55), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.7), lineWidth: 0.9)
                    )
                    .shadow(color: statusColor.opacity(0.38), radius: 8, x: 0, y: 5)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                if let badgeText = overlayStatus.badgeText {
                    Text(badgeText)
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.54))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                                )
                        )
                        .offset(x: 13, y: -15)
                }
                
                Circle()
                    .stroke(statusColor.opacity(0.35), lineWidth: 2)
                    .scaleEffect(pulseSelection ? 1.28 : 1.0)
                    .opacity(pulseSelection ? 0 : 1)
                    .frame(width: 34, height: 34)
            }
        }
        .buttonStyle(.plain)
        .help(primaryButtonHelpText)
    }
    
    private var expandedControls: some View {
        HStack(spacing: 8) {
            if let session = appState.activeInteractionSession,
               session.state != .idle,
               !session.state.isTerminal {
                activeSessionControls(for: session)
            } else {
                defaultControls
            }

            pinToggleButton
        }
        .foregroundStyle(.white.opacity(0.96))
    }

    private var defaultControls: some View {
        HStack(spacing: 8) {
            Button {
                appState.toggleDictation()
            } label: {
                Image(systemName: appState.dictationState == .idle ? "mic.fill" : "stop.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .red))
            .disabled(!appState.hasAccessibilityPermissions)
            .help(appState.dictationState == .idle ? "Start dictation" : "Stop dictation and insert")

            if appState.canCancelActiveInteraction {
                Button {
                    appState.cancelActiveInteraction()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(OverlayGlassIconButtonStyle(accent: .orange))
                .help("Cancel active interaction")
            }

            Button("Read") {
                appState.speakSelectedText()
            }
            .buttonStyle(OverlayGlassPillButtonStyle(accent: statusColor))
            .disabled(!appState.hasAccessibilityPermissions)
            .help("Read currently selected text")

            Button {
                appState.summarizeSelectedTextForSpeech()
            } label: {
                Image(systemName: "text.bubble")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .purple))
            .disabled(!appState.hasAccessibilityPermissions)
            .help("Summarize selected response and read it")
            
            HStack(spacing: 6) {
                Button {
                    appState.togglePlayPause()
                } label: {
                    Image(systemName: appState.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(OverlayGlassIconButtonStyle(accent: .green))
                .disabled(appState.playbackState == .idle && appState.currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button {
                    if appState.canCancelActiveInteraction {
                        appState.cancelActiveInteraction()
                    } else {
                        appState.stop()
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(OverlayGlassIconButtonStyle(accent: .orange))
                .disabled(appState.playbackState == .idle)
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.26))
                .frame(width: 0.8, height: 15)
            
            Button {
                appState.speakFromClipboard()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .blue))
            .help("Read clipboard text")

            Button {
                appState.speakClaudePlanFromPicker()
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .purple))
            .help("Read Claude Code plan")
        }
    }

    @ViewBuilder
    private func activeSessionControls(for session: InteractionSession) -> some View {
        switch session.mode {
        case .dictateVerbatim:
            dictationSessionControls
        case .askAI:
            askAIControls(for: session)
        case .readback:
            readbackSessionControls
        case .transformText:
            cancelInteractionButton(help: "Cancel active interaction")
        }
    }

    private var dictationSessionControls: some View {
        HStack(spacing: 8) {
            if appState.dictationState == .recording {
                Button {
                    appState.stopDictationAndInsert()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(OverlayGlassIconButtonStyle(accent: .red))
                .help("Stop dictation and insert")
            }

            if appState.canCancelActiveInteraction {
                cancelInteractionButton(help: "Cancel dictation")
            }
        }
    }

    @ViewBuilder
    private func askAIControls(for session: InteractionSession) -> some View {
        switch session.state {
        case .recording:
            Button {
                appState.toggleAskAI()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .green))
            .help("Send prompt")

            if appState.canCancelActiveInteraction {
                cancelInteractionButton(help: "Cancel prompt")
            }
        case .awaitingUserReview:
            aiResponseControls
        case .reading:
            cancelInteractionButton(help: "Stop reading")

            Button {
                appState.copyCurrentAIResponse()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .blue))
            .help("Copy AI response")
        case .preparing, .transcribing, .processing, .inserting:
            if appState.canCancelActiveInteraction {
                cancelInteractionButton(help: overlayStatus.helpText)
            }
        case .idle, .completed, .failed, .cancelled:
            EmptyView()
        }
    }

    private var aiResponseControls: some View {
        HStack(spacing: 8) {
            Button {
                appState.readCurrentAIResponse()
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .mint))
            .help("Read AI response")

            Button {
                appState.copyCurrentAIResponse()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .blue))
            .help("Copy AI response")

            Button {
                appState.insertCurrentAIResponse()
            } label: {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .green))
            .help("Insert AI response")

            Button {
                appState.discardCurrentAIResponse()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .orange))
            .help("Discard AI response")
        }
    }

    private var readbackSessionControls: some View {
        HStack(spacing: 8) {
            Button {
                appState.togglePlayPause()
            } label: {
                Image(systemName: appState.playbackState == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .green))
            .help(appState.playbackState == .playing ? "Pause speech" : "Resume speech")

            Button {
                appState.cancelActiveInteraction()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(OverlayGlassIconButtonStyle(accent: .orange))
            .help("Stop reading")
        }
    }

    private func cancelInteractionButton(help: String) -> some View {
        Button {
            appState.cancelActiveInteraction()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(OverlayGlassIconButtonStyle(accent: .orange))
        .help(help)
    }

    private var pinToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                isPinnedExpanded.toggle()
            }
        } label: {
            Image(systemName: isPinnedExpanded ? "pin.fill" : "pin")
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(OverlayGlassIconButtonStyle(accent: .gray))
        .help(isPinnedExpanded ? "Unpin expanded view" : "Pin expanded view")
    }

    private var statusColor: Color {
        overlayStatus.tone.color
    }

    private var statusIcon: String {
        overlayStatus.systemImageName
    }

    private var primaryButtonHelpText: String {
        overlayStatus.helpText
    }
}

private extension OverlayInteractionStatus.Tone {
    var color: Color {
        switch self {
        case .orange:
            return Color(nsColor: .systemOrange)
        case .pink:
            return Color(nsColor: .systemPink)
        case .red:
            return Color(nsColor: .systemRed)
        case .indigo:
            return Color(nsColor: .systemIndigo)
        case .purple:
            return Color(nsColor: .systemPurple)
        case .blue:
            return Color(nsColor: .systemBlue)
        case .mint:
            return Color(nsColor: .systemMint)
        case .green:
            return Color(nsColor: .systemGreen)
        }
    }
}

private struct OverlayGlassPillButtonStyle: ButtonStyle {
    let accent: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        Capsule()
                            .fill(accent.opacity(configuration.isPressed ? 0.18 : 0.10))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                    )
            }
            .shadow(color: accent.opacity(configuration.isPressed ? 0.08 : 0.18), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

private struct OverlayGlassIconButtonStyle: ButtonStyle {
    let accent: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: 24, height: 24)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(accent.opacity(configuration.isPressed ? 0.20 : 0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                    )
            }
            .shadow(color: accent.opacity(configuration.isPressed ? 0.07 : 0.16), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

#if canImport(PreviewsMacros)
#Preview {
    FloatingOverlayView()
        .environment(AppState.shared)
        .padding(60)
        .background(Color.gray.opacity(0.25))
}
#endif
