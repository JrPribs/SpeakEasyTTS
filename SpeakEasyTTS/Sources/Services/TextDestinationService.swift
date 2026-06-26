// TextDestinationService.swift
// Writes text to user destinations while preserving pasteboard contents.

import AppKit
import Foundation

struct TextDestinationRequest: Equatable {
    var text: String
    var destination: InteractionDestination

    init(
        text: String,
        destination: InteractionDestination = InteractionDestination(kind: .targetApp, writeMode: .insert)
    ) {
        self.text = text
        self.destination = destination
    }
}

struct TextDestinationResult: Equatable {
    var destination: InteractionDestination
}

enum TextDestinationError: LocalizedError, Equatable {
    case emptyText
    case unsupportedDestination(InteractionDestinationKind)
    case targetUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "No text was provided for insertion."
        case .unsupportedDestination(let kind):
            return "Unsupported text destination: \(kind.rawValue)."
        case .targetUnavailable:
            return "Could not find a target app for text insertion."
        }
    }
}

final class TextDestinationService {
    typealias Completion = (Result<TextDestinationResult, TextDestinationError>) -> Void

    private let targetApplication: () -> NSRunningApplication?
    private let activateTarget: (NSRunningApplication) -> Bool
    private let writePasteboardString: (String) -> Void
    private let makePasteboardSnapshot: () -> [NSPasteboardItem]
    private let restorePasteboardSnapshot: ([NSPasteboardItem]) -> Void
    private let postPasteCommand: () -> Void
    private let scheduleAfter: (TimeInterval, @escaping () -> Void) -> Void

    init(appContextService: AppContextService) {
        let pasteboard = NSPasteboard.general
        self.targetApplication = {
            appContextService.targetApplicationForUserInteraction()
        }
        self.activateTarget = { target in
            target.activate(options: [])
        }
        self.writePasteboardString = { text in
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
        self.makePasteboardSnapshot = {
            Self.makePasteboardSnapshot(from: pasteboard)
        }
        self.restorePasteboardSnapshot = { items in
            Self.restorePasteboardSnapshot(items, to: pasteboard)
        }
        self.postPasteCommand = {
            Self.postCommandKey(0x09) // V
        }
        self.scheduleAfter = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    init(
        appContextService: AppContextService = AppContextService(),
        targetApplication: @escaping () -> NSRunningApplication? = { nil },
        activateTarget: @escaping (NSRunningApplication) -> Bool = { _ in false },
        writePasteboardString: @escaping (String) -> Void = { _ in },
        makePasteboardSnapshot: @escaping () -> [NSPasteboardItem] = { [] },
        restorePasteboardSnapshot: @escaping ([NSPasteboardItem]) -> Void = { _ in },
        postPasteCommand: @escaping () -> Void = {},
        scheduleAfter: @escaping (TimeInterval, @escaping () -> Void) -> Void = { _, work in work() }
    ) {
        self.targetApplication = targetApplication
        self.activateTarget = activateTarget
        self.writePasteboardString = writePasteboardString
        self.makePasteboardSnapshot = makePasteboardSnapshot
        self.restorePasteboardSnapshot = restorePasteboardSnapshot
        self.postPasteCommand = postPasteCommand
        self.scheduleAfter = scheduleAfter
    }

    func write(_ request: TextDestinationRequest, completion: @escaping Completion) {
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.failure(.emptyText))
            return
        }

        guard request.destination.kind == .targetApp else {
            completion(.failure(.unsupportedDestination(request.destination.kind)))
            return
        }

        guard let target = targetApplication() else {
            completion(.failure(.targetUnavailable))
            return
        }

        let snapshot = makePasteboardSnapshot()
        writePasteboardString(request.text)

        let didActivate = activateTarget(target)
        let pasteDelay: TimeInterval = didActivate ? 0.15 : 0.05
        scheduleAfter(pasteDelay) { [postPasteCommand, restorePasteboardSnapshot, scheduleAfter] in
            postPasteCommand()

            scheduleAfter(0.35) {
                restorePasteboardSnapshot(snapshot)
                completion(.success(TextDestinationResult(destination: request.destination)))
            }
        }
    }

    private static func makePasteboardSnapshot(from pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        pasteboard.pasteboardItems?.map { original in
            let copy = NSPasteboardItem()

            for type in original.types {
                if let data = original.data(forType: type) {
                    copy.setData(data, forType: type)
                } else if let string = original.string(forType: type) {
                    copy.setString(string, forType: type)
                }
            }

            return copy
        } ?? []
    }

    private static func restorePasteboardSnapshot(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
    }

    private static func postCommandKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
