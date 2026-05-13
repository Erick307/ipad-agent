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
        // Mock implementation - returns placeholder message
        // This will be replaced with real Anthropic API integration

        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let mockResponse = ClaudeResponse(
            id: UUID().uuidString,
            textContent: "🤖 AI is not connected yet. Real Claude API integration coming soon!",
            toolCalls: nil
        )

        return mockResponse
    }
}
