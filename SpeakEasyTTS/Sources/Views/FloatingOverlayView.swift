// FloatingOverlayView.swift
// Always-on-top floating pill widget for quick TTS access

import SwiftUI
import AppKit

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
    private let expandedWidth: CGFloat = 298
    
    private var hasSelection: Bool {
        appState.hasSelectedText
    }
    
    private var shouldExpand: Bool {
        isPinnedExpanded || isHovering
    }
    
    private var controlsVisible: Bool {
        shouldExpand && !isDragging
    }
    
    private var isActiveState: Bool {
        hasSelection || isAutoReading || appState.playbackState != .idle
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
            Button("Read") {
                appState.speakSelectedText()
            }
            .buttonStyle(OverlayGlassPillButtonStyle(accent: statusColor))
            .disabled(!appState.hasAccessibilityPermissions)
            .help("Read currently selected text")
            
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
                    appState.stop()
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
        .foregroundStyle(.white.opacity(0.96))
    }
    
    private var statusColor: Color {
        if !appState.hasAccessibilityPermissions {
            return Color(nsColor: .systemOrange)
        }
        if isAutoReading {
            return Color(nsColor: .systemPurple)
        }
        if hasSelection && appState.playbackState == .idle {
            return Color(nsColor: .systemBlue)
        }
        
        switch appState.playbackState {
        case .playing:
            return Color(nsColor: .systemMint)
        case .paused:
            return Color(nsColor: .systemOrange)
        case .idle:
            return Color(nsColor: .systemBlue)
        }
    }
    
    private var statusIcon: String {
        if !appState.hasAccessibilityPermissions {
            return "lock.fill"
        }
        if isAutoReading {
            return "waveform"
        }
        if hasSelection && appState.playbackState == .idle {
            return "text.cursor"
        }
        
        switch appState.playbackState {
        case .playing:
            return "speaker.wave.3.fill"
        case .paused:
            return "pause.fill"
        case .idle:
            return "speaker.wave.2.fill"
        }
    }
    
    private var primaryButtonHelpText: String {
        if !appState.hasAccessibilityPermissions {
            return "Open Accessibility Settings"
        }
        if hasSelection {
            return "Read selected text"
        }
        return "Expand overlay controls"
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
