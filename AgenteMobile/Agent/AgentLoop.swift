//
//  AgentLoop.swift
//  AgenteMobile
//

import Foundation

/// Runs the conversation with Claude: sends the history, runs the tools Claude
/// asks for, sends the results back, and repeats until Claude ends its turn.
///
/// It knows nothing about the UI or about files. It gets the API and the tools
/// injected, so tests can drive it with a scripted repository and fake tools.
final class AgentLoop {
    private let repository: AnthropicRepository
    private let tools: [String: AgentTool]
    private let toolDefinitions: [ToolDefinition]
    private let systemPrompt: String
    private let maxSteps: Int

    /// The conversation in API format. Unlike the chat shown on screen, it keeps
    /// every tool_use and tool_result block, which Claude needs on the next request.
    private(set) var history: [APIMessage] = []

    /// - Parameter maxSteps: Maximum API round-trips per user message, to stop runaway tool loops.
    init(
        repository: AnthropicRepository,
        tools: [AgentTool],
        systemPrompt: String,
        maxSteps: Int = 10
    ) {
        self.repository = repository
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
        self.toolDefinitions = tools.map(\.definition)
        self.systemPrompt = systemPrompt
        self.maxSteps = maxSteps
    }

    /// Sends a user message and streams what happens until Claude ends its turn.
    /// The stream throws an `AgentError` if the loop stops early.
    func send(_ text: String) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(text) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Loop

    private func run(_ text: String, emit: (AgentEvent) -> Void) async throws {
        history.append(APIMessage(role: "user", text: text))

        for step in 1...maxSteps {
            let response = try await repository.sendMessage(
                messages: history,
                system: systemPrompt,
                tools: toolDefinitions
            )

            if !response.textContent.isEmpty {
                emit(.assistantText(response.textContent))
            }

            switch response.stopReason {
            case "tool_use" where !response.toolCalls.isEmpty:
                print("🛠️  Step \(step): Claude called \(response.toolCalls.count) tool(s)")
                history.append(assistantTurn(response))
                history.append(await toolResultsTurn(for: response.toolCalls, emit: emit))
                // Next iteration sends the results back so Claude can see them

            case "end_turn", "stop_sequence":
                // An empty assistant turn would be rejected on the next request
                if !response.content.isEmpty {
                    history.append(assistantTurn(response))
                }
                return

            case "max_tokens":
                // The response was cut off. A truncated tool_use input can still
                // parse as valid JSON (e.g. half a file), so never run its tools.
                throw AgentError.maxTokens

            case "refusal":
                throw AgentError.refusal

            default:
                throw AgentError.unexpectedStop(response.stopReason)
            }
        }

        print("⛔ Agent loop stopped: reached \(maxSteps) steps")
        throw AgentError.stepLimitReached(maxSteps)
    }

    /// The assistant turn exactly as the API returned it (text, tool_use, thinking...).
    /// The tool_use blocks must be in the history before the matching tool_result blocks.
    private func assistantTurn(_ response: ClaudeResponse) -> APIMessage {
        APIMessage(role: "assistant", blocks: response.content.map(AnyEncodable.init))
    }

    /// Runs every tool call and returns all results in a single user turn.
    private func toolResultsTurn(
        for toolCalls: [ToolCall],
        emit: (AgentEvent) -> Void
    ) async -> APIMessage {
        var blocks: [AnyEncodable] = []
        for toolCall in toolCalls {
            emit(.toolStarted(name: toolCall.name))
            let result = await execute(toolCall)
            emit(.toolFinished(name: toolCall.name, isError: result.isError))
            blocks.append(AnyEncodable(APIToolResultBlock(
                tool_use_id: toolCall.id,
                content: result.content,
                is_error: result.isError
            )))
        }
        return APIMessage(role: "user", blocks: blocks)
    }

    // MARK: - Tools

    /// Failures are still sent back to Claude (flagged with `is_error`) so it can
    /// retry or explain, instead of breaking the loop.
    private func execute(_ toolCall: ToolCall) async -> (content: String, isError: Bool) {
        guard let tool = tools[toolCall.name] else {
            print("⚠️ Unknown tool: \(toolCall.name)")
            return ("Error: Unknown tool '\(toolCall.name)'", true)
        }

        print("🔧 \(toolCall.name)")
        do {
            return (try await tool.execute(ToolInput(toolCall.input)), false)
        } catch {
            print("❌ \(toolCall.name) error: \(error)")
            return ("Error: \(error.localizedDescription)", true)
        }
    }
}
