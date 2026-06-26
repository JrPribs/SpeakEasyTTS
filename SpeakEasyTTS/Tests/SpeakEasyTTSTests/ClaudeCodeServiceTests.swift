import Testing
@testable import SpeakEasyTTS

@Suite
struct ClaudeCodeServiceTests {
    @Test
    func planReadbackDetailLevelCanBeChanged() {
        let service = ClaudeCodeService()

        #expect(service.planReadbackDetailLevel == .concise)

        service.updatePlanReadbackDetailLevel(.detailed)

        #expect(service.planReadbackDetailLevel == .detailed)
    }
}
