//
//  AnthropicRepository.swift
//  AgenteMobile
//

import Foundation

/// Sends one request to Claude and returns its response.
///
/// The agent loop depends on this protocol rather than on the HTTP client,
/// so tests can swap in a scripted repository and run without a network.
protocol AnthropicRepository {
    func sendMessage(
        messages: [APIMessage],
        system: String,
        tools: [ToolDefinition]
    ) async throws -> ClaudeResponse
}
