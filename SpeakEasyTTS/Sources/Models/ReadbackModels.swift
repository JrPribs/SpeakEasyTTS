// ReadbackModels.swift
// Request and profile models for speech readback processing.

import Foundation

enum ReadbackProfile: String, Codable, CaseIterable, Equatable, Hashable {
    case raw
    case cleanProse
    case technicalResponse
    case planSummary
    case taskList

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
}

struct ReadbackProcessingOptions: Codable, Equatable, Hashable {
    var normalizeMarkdown: Bool
    var summarizeCodeBlocks: Bool
    var preserveTaskStructure: Bool

    static let preserveInput = ReadbackProcessingOptions(
        normalizeMarkdown: false,
        summarizeCodeBlocks: false,
        preserveTaskStructure: false
    )

    init(
        normalizeMarkdown: Bool,
        summarizeCodeBlocks: Bool,
        preserveTaskStructure: Bool
    ) {
        self.normalizeMarkdown = normalizeMarkdown
        self.summarizeCodeBlocks = summarizeCodeBlocks
        self.preserveTaskStructure = preserveTaskStructure
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
