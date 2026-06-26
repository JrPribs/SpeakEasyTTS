// ReadbackPipeline.swift
// Coordinates readback request processing before speech synthesis.

import Foundation

struct ReadbackPipeline {
    func process(_ request: ReadbackRequest) -> ReadbackResult {
        ReadbackResult(request: request, spokenText: request.text)
    }
}
