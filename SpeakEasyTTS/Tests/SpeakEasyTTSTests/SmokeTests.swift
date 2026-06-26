import Testing
@testable import SpeakEasyTTS

@Suite
struct SmokeTests {
    @Test
    func defaultSpeechSettingsUseNativePlayback() {
        #expect(SpeechSettings.default.ttsEngine == .native)
        #expect(SpeechSettings.default.selectedVoiceId == nil)
    }
}
