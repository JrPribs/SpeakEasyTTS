// AIInteractionService.swift
// Provider-neutral AI hooks for optional interaction summaries.

import Foundation

protocol AIInteractionService {
    func summarizeReadback(_ request: AIReadbackSummaryRequest) async throws -> AIReadbackSummaryResponse
}

struct AIReadbackSummaryRequest: Codable, Equatable, Hashable {
    var readbackRequest: ReadbackRequest
    var deterministicText: String

    init(
        readbackRequest: ReadbackRequest,
        deterministicText: String
    ) {
        self.readbackRequest = readbackRequest
        self.deterministicText = deterministicText
    }
}

struct AIReadbackSummaryResponse: Codable, Equatable, Hashable {
    var summaryText: String

    init(summaryText: String) {
        self.summaryText = summaryText
    }
}
