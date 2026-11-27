//
//  TestDoubles.swift
//  AgenteMobileTests
//

import Foundation
import Testing
@testable import AgenteMobile

/// Plays back scripted responses in order and records every request it gets.
@MainActor
final class MockAnthropicRepository: AnthropicRepository {
    struct Request {
        let messages: [APIMessage]
        let system: String
        let tools: [ToolDefinition]
    }

    private var responses: [ClaudeResponse]
    private(set) var requests: [Request] = []

    init(responses: [ClaudeResponse]) {
        self.responses = responses
    }

    func sendMessage(
        messages: [APIMessage],
        system: String,
        tools: [ToolDefinition]
    ) async throws -> ClaudeResponse {
        requests.append(Request(messages: messages, system: system, tools: tools))
        guard !responses.isEmpty else {
            Issue.record("The loop sent more requests than the test scripted")
            throw CancellationError()
        }
        return responses.removeFirst()
    }
}

/// A tool that records its calls and returns a fixed result, or throws.
@MainActor
final class FakeTool: AgentTool {
    struct Failure: LocalizedError {
        var errorDescription: String? { "disk is full" }
    }

    let name: String
    let description = "A fake tool for tests."
    let inputSchema = ToolInputSchema(properties: [:], required: [])
    private let result: String
    private let fails: Bool
    private(set) var calls: [ToolInput] = []

    init(name: String = "fake_tool", result: String = "fake result", fails: Bool = false) {
        self.name = name
        self.result = result
        self.fails = fails
    }

    func execute(_ input: ToolInput) async throws -> String {
        calls.append(input)
        if fails { throw Failure() }
        return result
    }
}

// MARK: - Response builders

extension ClaudeResponse {
    static func text(_ text: String, stopReason: String = "end_turn") -> ClaudeResponse {
        ClaudeResponse(
            id: "msg_text",
            textContent: text,
            toolCalls: [],
            stopReason: stopReason,
            content: [.object(["type": .string("text"), "text": .string(text)])]
        )
    }

    static func toolUse(
        _ name: String,
        id: String = "toolu_1",
        input: [String: JSONValue] = [:],
        stopReason: String = "tool_use"
    ) -> ClaudeResponse {
        ClaudeResponse(
            id: "msg_tool",
            textContent: "",
            toolCalls: [ToolCall(id: id, name: name, input: input)],
            stopReason: stopReason,
            content: [.object([
                "type": .string("tool_use"),
                "id": .string(id),
                "name": .string(name),
                "input": .object(input)
            ])]
        )
    }
}

// MARK: - Helpers

/// An `APIMessage` as the JSON the API would receive, so tests can inspect it.
func json(_ message: APIMessage) throws -> [String: JSONValue] {
    let data = try JSONEncoder().encode(message)
    return try #require(try JSONDecoder().decode(JSONValue.self, from: data).objectValue)
}

/// The first `tool_result` block in a user turn.
func toolResult(in message: APIMessage) throws -> [String: JSONValue] {
    let blocks = try #require(try json(message)["content"]?.arrayValue)
    return try #require(blocks.first?.objectValue)
}

/// Runs one user message through the loop and collects everything it emitted.
@MainActor
func run(_ agent: AgentLoop, _ text: String) async -> (events: [AgentEvent], error: Error?) {
    var events: [AgentEvent] = []
    do {
        for try await event in agent.send(text) {
            events.append(event)
        }
        return (events, nil)
    } catch {
        return (events, error)
    }
}
