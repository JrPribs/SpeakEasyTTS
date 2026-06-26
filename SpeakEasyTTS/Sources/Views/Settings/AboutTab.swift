import SwiftUI

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "mic.and.signal.meter.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("SpeakEasy Flow")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("A lightweight menu bar app for dictation and text-to-speech")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)

            VStack(spacing: 8) {
                Text("Features:")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    FeatureRow(icon: "mic.fill", text: "Verbatim dictation (⌥D)")
                    FeatureRow(icon: "keyboard", text: "Read selected text (⌥S)")
                    FeatureRow(icon: "doc.on.clipboard", text: "Read from clipboard")
                    FeatureRow(icon: "text.cursor", text: "Read selected text")
                    FeatureRow(icon: "waveform", text: "Auto-read on selection")
                    FeatureRow(icon: "person.wave.2", text: "Multiple voice options")
                    FeatureRow(icon: "speedometer", text: "Adjustable speed")
                }
            }

            Spacer()

            Text("© 2024 SpeakEasy")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.blue)
            Text(text)
                .font(.caption)
        }
    }
}
