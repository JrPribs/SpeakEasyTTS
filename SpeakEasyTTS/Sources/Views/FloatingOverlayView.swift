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
    @State private var autoReadDebounceTask: Task<Void, Never>?
    @State private var lastSelectedText: String = ""
    @State private var isAutoReading = false
    @State private var pulseAnimation = false
    
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
                .fill(backgroundFillColor)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: shadowColor, radius: 10, x: 0, y: 5)
        )
        .overlay(
            Capsule()
                .stroke(strokeColor, lineWidth: hasSelection || isAutoReading ? 2 : 1)
        )
        .scaleEffect(pulseAnimation ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            handleTap()
        }
        .onAppear {
            startSelectionMonitoring()
        }
        .onDisappear {
            stopSelectionMonitoring()
        }
    }
    
    // MARK: - Background Colors
    
    private var backgroundFillColor: Color {
        if !appState.hasAccessibilityPermissions {
            return Color.orange.opacity(0.2)
        }
        if isAutoReading {
            return Color.purple.opacity(0.3)
        }
        if hasSelection {
            return Color.green.opacity(0.3)
        }
        return Color.clear
    }
    
    private var shadowColor: Color {
        if !appState.hasAccessibilityPermissions {
            return .orange.opacity(0.3)
        }
        if isAutoReading {
            return .purple.opacity(0.4)
        }
        if hasSelection {
            return .green.opacity(0.3)
        }
        return .black.opacity(0.2)
    }
    
    private var strokeColor: Color {
        if !appState.hasAccessibilityPermissions {
            return Color.orange.opacity(0.6)
        }
        if isAutoReading {
            return Color.purple.opacity(0.6)
        }
        if hasSelection {
            return Color.green.opacity(0.5)
        }
        return Color.white.opacity(0.2)
    }
    
    // MARK: - Tap Handler
    
    private func handleTap() {
        // If no accessibility permissions, open settings
        if !appState.hasAccessibilityPermissions {
            appState.openAccessibilitySettings()
            return
        }
        
        // If there's selected text, read it immediately on tap
        if hasSelection {
            appState.speakSelectedText()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded.toggle()
            }
        }
    }
    
    // MARK: - Selection Monitoring
    
    private func startSelectionMonitoring() {
        // Log initial accessibility status
        print("🔍 Starting selection monitoring. Accessibility granted: \(appState.hasAccessibilityPermissions)")
        
        // Check for selected text every 0.5 seconds
        selectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak appState] _ in
            guard let appState = appState else { return }
            
            // Only check if we have accessibility permissions
            if appState.hasAccessibilityPermissions {
                let newHasSelection = appState.clipboardService.hasSelectedText()
                if newHasSelection != hasSelection {
                    print("📝 Selection state changed: \(newHasSelection)")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasSelection = newHasSelection
                    }
                    
                    // Handle auto-read on selection
                    if newHasSelection && appState.settings.autoReadOnSelection {
                        triggerAutoRead()
                    } else if !newHasSelection {
                        cancelAutoRead()
                    }
                }
            }
        }
    }
    
    private func stopSelectionMonitoring() {
        selectionCheckTimer?.invalidate()
        selectionCheckTimer = nil
        cancelAutoRead()
    }
    
    // MARK: - Auto-Read Logic
    
    private func triggerAutoRead() {
        // Cancel any existing debounce task
        autoReadDebounceTask?.cancel()
        
        let delay = appState.settings.autoReadDelay
        
        autoReadDebounceTask = Task { @MainActor in
            do {
                // Wait for debounce delay
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Check if task was cancelled
                if Task.isCancelled { return }
                
                // Check if still has selection and auto-read is enabled
                guard hasSelection && appState.settings.autoReadOnSelection else { return }
                
                // Don't auto-read if already playing
                guard appState.playbackState == .idle else { return }
                
                // Show auto-reading indicator with pulse animation
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAutoReading = true
                }
                
                // Pulse animation
                withAnimation(.easeInOut(duration: 0.15)) {
                    pulseAnimation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        pulseAnimation = false
                    }
                }
                
                print("🎙️ Auto-reading selected text...")
                appState.speakSelectedText()
                
                // Reset auto-reading indicator after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAutoReading = false
                    }
                }
            } catch {
                // Task was cancelled
            }
        }
    }
    
    private func cancelAutoRead() {
        autoReadDebounceTask?.cancel()
        autoReadDebounceTask = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            isAutoReading = false
        }
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
        .overlay(
            // Pulse ring when ready to read
            Circle()
                .stroke(hasSelection && appState.playbackState == .idle ? Color.green : Color.clear, lineWidth: 2)
                .frame(width: 38, height: 38)
                .opacity(pulseAnimation ? 0.8 : 0)
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
        )
    }
    
    private var statusColor: Color {
        // No accessibility permissions - show warning
        if !appState.hasAccessibilityPermissions {
            return .orange
        }
        
        // Auto-reading state
        if isAutoReading {
            return .purple
        }
        
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
        // No accessibility permissions - show lock
        if !appState.hasAccessibilityPermissions {
            return "lock.fill"
        }
        
        // Auto-reading indicator
        if isAutoReading {
            return "waveform"
        }
        
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
