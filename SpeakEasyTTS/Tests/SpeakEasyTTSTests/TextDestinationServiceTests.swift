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

        #expect(result == .success(TextDestinationResult(destination: harness.resolved(destination))))
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

            #expect(result == .success(TextDestinationResult(destination: harness.resolved(destination))))
            #expect(harness.events.contains("paste"))
            #expect(harness.events.last == "restore:1")
        }
    }

    @Test
    func recoverableTargetStillUsesPasteboardSafePath() {
        let harness = DestinationHarness(target: .current, targetIsRecoverableFallback: true)
        let service = harness.makeService()
        let destination = InteractionDestination(kind: .targetApp, writeMode: .insert)
        let result = writeSynchronously(
            TextDestinationRequest(text: "hello", destination: destination),
            service: service
        )

        #expect(result == .success(TextDestinationResult(destination: harness.resolved(destination))))
        #expect(harness.events.contains("paste"))
        #expect(harness.events.last == "restore:1")
    }

    @Test
    func intendedTargetMismatchFailsBeforeTouchingPasteboard() {
        let mismatchedContext = AppContext(
            bundleIdentifier: "com.example.OtherTarget",
            appName: "Other",
            processIdentifier: 999,
            capturedAt: Date(timeIntervalSince1970: 5_001)
        )
        let harness = DestinationHarness(target: .current)
        let service = harness.makeService()
        let destination = InteractionDestination(
            kind: .targetApp,
            appContext: mismatchedContext,
            writeMode: .insert
        )
        let result = writeSynchronously(
            TextDestinationRequest(text: "hello", destination: destination),
            service: service
        )

        #expect(result == .failure(.targetUnavailable))
        #expect(harness.events == ["target"])
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
    let context = AppContext(
        bundleIdentifier: "com.example.Target",
        appName: "Target",
        processIdentifier: 123,
        capturedAt: Date(timeIntervalSince1970: 5_000)
    )
    var events: [String] = []
    private let target: NSRunningApplication?
    private let targetIsRecoverableFallback: Bool
    private let activatesTarget: Bool

    init(
        target: NSRunningApplication?,
        targetIsRecoverableFallback: Bool = false,
        activatesTarget: Bool = true
    ) {
        self.target = target
        self.targetIsRecoverableFallback = targetIsRecoverableFallback
        self.activatesTarget = activatesTarget
    }

    func resolved(_ destination: InteractionDestination) -> InteractionDestination {
        InteractionDestination(
            kind: destination.kind,
            appContext: context,
            writeMode: destination.writeMode
        )
    }

    func makeService() -> TextDestinationService {
        TextDestinationService(
            resolveTarget: { [self] intendedTarget in
                events.append("target")
                guard let target else { return nil }
                if let intendedTarget,
                   intendedTarget != context {
                    return nil
                }

                if targetIsRecoverableFallback {
                    return .recoverable(target, context)
                }
                return .focused(target, context)
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
