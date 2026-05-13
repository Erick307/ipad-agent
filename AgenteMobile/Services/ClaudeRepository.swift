//
//  ClaudeRepository.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import Foundation

struct ToolCall {
    let id: String
    let name: String
    let input: ToolInput
}

struct ToolInput: Codable {
    let filename: String
    let content: String
}

struct ClaudeResponse {
    let id: String
    let textContent: String
    let toolCalls: [ToolCall]?
}

class ClaudeRepository {
    func sendMessage(
        messages: [Message],
        systemPrompt: String
    ) async throws -> ClaudeResponse {
        // TODO: Implement Claude API call with tool calling
        throw NSError(domain: "NotImplemented", code: -1)
    }
}
