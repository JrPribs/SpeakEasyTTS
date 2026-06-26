// ShortcutRecorderView.swift
// Settings UI for recording keyboard shortcuts

import AppKit
import SwiftUI

struct ShortcutRecorderRow: View {
    let title: String
    let shortcut: KeyboardShortcut
    let onRecord: (KeyboardShortcut) -> String?
    let onReset: () -> Void

    @State private var isRecording = false
    @State private var validationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()

                Button {
                    validationMessage = nil
                    isRecording = true
                } label: {
                    Label(isRecording ? "Recording" : shortcut.displayName, systemImage: "keyboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    validationMessage = nil
                    isRecording = false
                    onReset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help("Restore default")
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if isRecording {
                ShortcutCaptureView(
                    onShortcut: { capturedShortcut in
                        if let message = onRecord(capturedShortcut) {
                            validationMessage = message
                        } else {
                            validationMessage = nil
                            isRecording = false
                        }
                    },
                    onCancel: {
                        validationMessage = nil
                        isRecording = false
                    }
                )
                .frame(width: 1, height: 1)
            }
        }
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let onShortcut: (KeyboardShortcut) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onShortcut = onShortcut
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onShortcut = onShortcut
        nsView.onCancel = onCancel
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class ShortcutCaptureNSView: NSView {
    var onShortcut: ((KeyboardShortcut) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async {
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = ShortcutModifiers(eventModifierFlags: event.modifierFlags)
        let keyCode = UInt32(event.keyCode)

        if keyCode == KeyCodeDisplayName.escape && modifiers.isEmpty {
            onCancel?()
            return
        }

        onShortcut?(KeyboardShortcut(keyCode: keyCode, modifiers: modifiers))
    }
}

private extension ShortcutModifiers {
    init(eventModifierFlags flags: NSEvent.ModifierFlags) {
        var modifiers: ShortcutModifiers = []
        let deviceFlags = flags.intersection(.deviceIndependentFlagsMask)

        if deviceFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if deviceFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if deviceFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if deviceFlags.contains(.control) {
            modifiers.insert(.control)
        }

        self = modifiers
    }
}
