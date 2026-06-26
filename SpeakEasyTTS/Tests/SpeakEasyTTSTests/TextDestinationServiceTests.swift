import AppKit
import Foundation
import Testing
@testable import SpeakEasyTTS

@Suite
struct TextDestinationServiceTests {
    @Test
    func emptyTextFailsBeforeResolvingTarget() {
        let harness = DestinationHarness(target: .current)
        let service = harness.makeService()
        let result = writeSynchronously(TextDestinationRequest(text: "   "), service: service)

        #expect(result == .failure(.emptyText))
        #expect(harness.events.isEmpty)
    }

    @Test
    func missingTargetFailsBeforeTouchingPasteboard() {
        let harness = DestinationHarness(target: nil)
        let service = harness.makeService()
        let result = writeSynchronously(TextDestinationRequest(text: "hello"), service: service)

        #expect(result == .failure(.targetUnavailable))
        #expect(harness.events == ["target"])
    }

    @Test
    func unsupportedDestinationFailsBeforeTouchingPasteboard() {
        let harness = DestinationHarness(target: .current)
        let service = harness.makeService()
        let result = writeSynchronously(
            TextDestinationRequest(
                text: "hello",
                destination: InteractionDestination(kind: .speech)
            ),
            service: service
        )

        #expect(result == .failure(.unsupportedDestination(.speech)))
        #expect(harness.events.isEmpty)
    }

    @Test
    func targetAppInsertPreservesPasteboardAroundPasteCommand() {
        let harness = DestinationHarness(target: .current, activatesTarget: true)
        let service = harness.makeService()
        let destination = InteractionDestination(kind: .targetApp, writeMode: .insert)
        var result: Result<TextDestinationResult, TextDestinationError>?
        service.write(TextDestinationRequest(text: "  dictated text  ", destination: destination)) { writeResult in
            result = writeResult
            harness.events.append("completion")
        }

        #expect(result == .success(TextDestinationResult(destination: destination)))
        #expect(harness.events == [
            "target",
            "snapshot",
            "write:  dictated text  ",
            "activate",
            "delay:0.15",
            "paste",
            "delay:0.35",
            "restore:1",
            "completion"
        ])
    }

    @Test
    func targetAppWriteModesUseSamePasteboardSafePath() {
        for mode in [TextWriteMode.insert, .replaceSelection, .append] {
            let harness = DestinationHarness(target: .current)
            let service = harness.makeService()
            let destination = InteractionDestination(kind: .targetApp, writeMode: mode)
            let result = writeSynchronously(
                TextDestinationRequest(text: "hello", destination: destination),
                service: service
            )

            #expect(result == .success(TextDestinationResult(destination: destination)))
            #expect(harness.events.contains("paste"))
            #expect(harness.events.last == "restore:1")
        }
    }

    @Test
    func restoreStillRunsWhenTargetActivationFails() {
        let harness = DestinationHarness(target: .current, activatesTarget: false)
        let service = harness.makeService()
        let result = writeSynchronously(TextDestinationRequest(text: "hello"), service: service)

        #expect((try? result.get()) != nil)
        #expect(harness.events.contains("delay:0.05"))
        #expect(harness.events.last == "restore:1")
    }

    private func writeSynchronously(
        _ request: TextDestinationRequest,
        service: TextDestinationService
    ) -> Result<TextDestinationResult, TextDestinationError> {
        var resolved: Result<TextDestinationResult, TextDestinationError>?
        service.write(request) { result in
            resolved = result
        }

        return resolved ?? .failure(.targetUnavailable)
    }
}

private final class DestinationHarness {
    var events: [String] = []
    private let target: NSRunningApplication?
    private let activatesTarget: Bool

    init(
        target: NSRunningApplication?,
        activatesTarget: Bool = true
    ) {
        self.target = target
        self.activatesTarget = activatesTarget
    }

    func makeService() -> TextDestinationService {
        TextDestinationService(
            targetApplication: { [self] in
                events.append("target")
                return target
            },
            activateTarget: { [self] _ in
                events.append("activate")
                return activatesTarget
            },
            writePasteboardString: { [self] text in
                events.append("write:\(text)")
            },
            makePasteboardSnapshot: { [self] in
                events.append("snapshot")
                return [NSPasteboardItem()]
            },
            restorePasteboardSnapshot: { [self] items in
                events.append("restore:\(items.count)")
            },
            postPasteCommand: { [self] in
                events.append("paste")
            },
            scheduleAfter: { [self] delay, work in
                events.append(String(format: "delay:%.2f", delay))
                work()
            }
        )
    }
}
