// FloatingOverlayView.swift
// Always-on-top floating pill widget for quick TTS access

import SwiftUI
import AppKit

/// Floating pill-shaped overlay that stays on top of all windows
struct FloatingOverlayView: View {
    @Environment(AppState.self) private var appState
    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var hasSelection = false
    @State private var selectionCheckTimer: Timer?
    
    var body: some View {
        HStack(spacing: 8) {
            // Speaker icon / status indicator
            statusIndicator
            
            if isExpanded || isHovering {
                expandedControls
            }
        }
        .padding(.horizontal, isExpanded || isHovering ? 16 : 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(hasSelection ? Color.green.opacity(0.3) : Color.clear)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: hasSelection ? .green.opacity(0.3) : .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .overlay(
            Capsule()
                .stroke(hasSelection ? Color.green.opacity(0.5) : Color.white.opacity(0.2), lineWidth: hasSelection ? 2 : 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            // If there's selected text, read it immediately on tap
            if hasSelection {
                appState.speakSelectedText()
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }
        }
        .onAppear {
            startSelectionMonitoring()
        }
        .onDisappear {
            stopSelectionMonitoring()
        }
    }
    
    // MARK: - Selection Monitoring
    
    private func startSelectionMonitoring() {
        // Check for selected text every 0.5 seconds
        selectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Only check if we have accessibility permissions
            if appState.clipboardService.hasAccessibilityPermissions() {
                let newHasSelection = appState.clipboardService.hasSelectedText()
                if newHasSelection != hasSelection {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasSelection = newHasSelection
                    }
                }
            }
        }
    }
    
    private func stopSelectionMonitoring() {
        selectionCheckTimer?.invalidate()
        selectionCheckTimer = nil
    }
    
    // MARK: - Status Indicator
    
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor)
                .frame(width: 32, height: 32)
            
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
    
    private var statusColor: Color {
        // If text is selected, show green (ready to read)
        if hasSelection && appState.playbackState == .idle {
            return .green
        }
        
        switch appState.playbackState {
        case .playing:
            return .green
        case .paused:
            return .orange
        case .idle:
            return .blue
        }
    }
    
    private var statusIcon: String {
        // If text is selected, show play icon (ready to read)
        if hasSelection && appState.playbackState == .idle {
            return "play.fill"
        }
        
        switch appState.playbackState {
        case .playing:
            return "speaker.wave.3.fill"
        case .paused:
            return "pause.fill"
        case .idle:
            return "speaker.wave.2"
        }
    }
    
    // MARK: - Expanded Controls
    
    private var expandedControls: some View {
        HStack(spacing: 12) {
            // Read Selection button
            Button {
                appState.speakSelectedText()
            } label: {
                Label("Read", systemImage: "text.cursor")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.2))
            .clipShape(Capsule())
            
            // Play/Pause/Stop controls
            if appState.playbackState != .idle {
                HStack(spacing: 6) {
                    Button {
                        appState.togglePlayPause()
                    } label: {
                        Image(systemName: appState.playbackState == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        appState.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Read Clipboard button
            Button {
                appState.speakFromClipboard()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Read from Clipboard")
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    FloatingOverlayView()
        .environment(AppState.shared)
        .padding(50)
        .background(Color.gray.opacity(0.3))
}
