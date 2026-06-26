// ReadbackModels.swift
// Request and profile models for speech readback processing.

import Foundation

enum ReadbackProfile: String, Codable, CaseIterable, Equatable, Hashable {
    case raw
    case cleanProse
    case technicalResponse
    case planSummary
    case taskList

    var displayName: String {
        switch self {
        case .raw:
            return "Raw"
        case .cleanProse:
            return "Clean Prose"
        case .technicalResponse:
            return "Summarized Response"
        case .planSummary:
            return "Plan Summary"
        case .taskList:
            return "Task List"
        }
    }

    var defaultDetailLevel: ReadbackDetailLevel {
        switch self {
        case .raw, .cleanProse, .technicalResponse:
            return .standard
        case .planSummary, .taskList:
            return .concise
        }
    }

    var defaultProcessingOptions: ReadbackProcessingOptions {
        switch self {
        case .raw:
            return .preserveInput
        case .cleanProse:
            return ReadbackProcessingOptions(
                normalizeMarkdown: true,
                summarizeCodeBlocks: false,
                preserveTaskStructure: false
            )
        case .technicalResponse:
            return ReadbackProcessingOptions(
                normalizeMarkdown: true,
                summarizeCodeBlocks: true,
                preserveTaskStructure: true
            )
        case .planSummary:
            return ReadbackProcessingOptions(
                normalizeMarkdown: true,
                summarizeCodeBlocks: true,
                preserveTaskStructure: true
            )
        case .taskList:
            return ReadbackProcessingOptions(
                normalizeMarkdown: true,
                summarizeCodeBlocks: false,
                preserveTaskStructure: true
            )
        }
    }
}

enum ReadbackDetailLevel: String, Codable, CaseIterable, Equatable, Hashable {
    case concise
    case standard
    case detailed

    var displayName: String {
        switch self {
        case .concise:
            return "Brief"
        case .standard:
            return "Standard"
        case .detailed:
            return "Detailed"
        }
    }
}

struct ReadbackProcessingOptions: Codable, Equatable, Hashable {
    var normalizeMarkdown: Bool
    var summarizeCodeBlocks: Bool
    var preserveTaskStructure: Bool
    var requestAISummary: Bool

    static let preserveInput = ReadbackProcessingOptions(
        normalizeMarkdown: false,
        summarizeCodeBlocks: false,
        preserveTaskStructure: false,
        requestAISummary: false
    )

    init(
        normalizeMarkdown: Bool,
        summarizeCodeBlocks: Bool,
        preserveTaskStructure: Bool,
        requestAISummary: Bool = false
    ) {
        self.normalizeMarkdown = normalizeMarkdown
        self.summarizeCodeBlocks = summarizeCodeBlocks
        self.preserveTaskStructure = preserveTaskStructure
        self.requestAISummary = requestAISummary
    }
}

struct ReadbackRequest: Codable, Equatable, Hashable {
    var source: InteractionSource
    var text: String
    var profile: ReadbackProfile
    var detailLevel: ReadbackDetailLevel
    var processingOptions: ReadbackProcessingOptions

    init(
        source: InteractionSource,
        text: String,
        profile: ReadbackProfile = .raw,
        detailLevel: ReadbackDetailLevel? = nil,
        processingOptions: ReadbackProcessingOptions? = nil
    ) {
        self.source = source
        self.text = text
        self.profile = profile
        self.detailLevel = detailLevel ?? profile.defaultDetailLevel
        self.processingOptions = processingOptions ?? profile.defaultProcessingOptions
    }
}

struct ReadbackResult: Codable, Equatable, Hashable {
    var request: ReadbackRequest
    var spokenText: String
}

struct ReadbackPreferences: Codable, Equatable, Hashable {
    var defaultProfile: ReadbackProfile
    var defaultDetailLevel: ReadbackDetailLevel
    var requestAISummaryByDefault: Bool

    static let `default` = ReadbackPreferences(
        defaultProfile: .raw,
        defaultDetailLevel: .standard,
        requestAISummaryByDefault: false
    )

    var processingOptions: ReadbackProcessingOptions {
        var options = defaultProfile.defaultProcessingOptions
        options.requestAISummary = requestAISummaryByDefault
        return options
    }
}
