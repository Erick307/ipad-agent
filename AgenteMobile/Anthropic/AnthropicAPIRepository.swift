//
//  AnthropicAPIRepository.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import Foundation

// MARK: - Private API Request/Response Models

private struct MessageRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [APIMessage]
    let tools: [ToolDefinition]?
    let thinking: ThinkingConfig
    let output_config: OutputConfig
}

private struct ThinkingConfig: Encodable {
    let type: String
}

private struct OutputConfig: Encodable {
    /// low | medium | high | xhigh | max. Defaults to medium when omitted.
    let effort: String
}

private struct APIResponse: Decodable {
    let id: String
    /// Decoded as raw JSON so blocks round-trip into the history unchanged.
    let content: [JSONValue]
    let stop_reason: StopReason
}

// MARK: - AnthropicAPIRepository

/// Talks to the Anthropic Messages API over HTTP.
final class AnthropicAPIRepository: AnthropicRepository {
    private let apiKeyStore: APIKeyStore
    private let apiBaseURL: String
    private let model: String
    private let maxTokens: Int

    /// Room for write_file inputs that carry a whole file plus adaptive thinking.
    private static let defaultMaxTokens = 16_000

    /// Simple file read/write tasks don't need deep thinking; low keeps it cheap and fast.
    private static let defaultEffort = "low"

    /// 2026-10-21 rejects `temperature`, `top_p`, `top_k`, documents in assistant turns and
    /// citations in user turns. This app sends none of them, so nothing else had to change.
    private static let apiVersion = "2026-10-21"

    /// Thinking adds time to every turn, so allow longer than URLSession's 60s default.
    private static let requestTimeout: TimeInterval = 600

    init(apiKeyStore: APIKeyStore) {
        self.apiKeyStore = apiKeyStore
        self.apiBaseURL = AppConstants.ANTHROPIC_BASE_URL
        self.model = AppConstants.MODEL
        self.maxTokens = Self.defaultMaxTokens
    }

    // MARK: - AnthropicRepository

    func sendMessage(
        messages: [APIMessage],
        system: String,
        tools: [ToolDefinition]
    ) async throws -> ClaudeResponse {
        let request = MessageRequest(
            model: model,
            max_tokens: maxTokens,
            system: system,
            messages: messages,
            tools: tools.isEmpty ? nil : tools,
            thinking: ThinkingConfig(type: "adaptive"),
            output_config: OutputConfig(effort: Self.defaultEffort)
        )

        let response = try await callClaudeAPI(request)

        let blocks = response.content.compactMap { $0.objectValue }

        let textContent = blocks
            .filter { $0["type"]?.stringValue == "text" }
            .compactMap { $0["text"]?.stringValue }
            .joined(separator: "\n\n")

        let toolCalls: [ToolCall] = blocks
            .filter { $0["type"]?.stringValue == "tool_use" }
            .compactMap { block in
                guard let toolId = block["id"]?.stringValue,
                      let toolName = block["name"]?.stringValue,
                      let inputDict = block["input"]?.objectValue else { return nil }
                return ToolCall(id: toolId, name: toolName, input: inputDict)
            }

        print("✅ Parsed response:")
        print("   Text: \(textContent.isEmpty ? "(empty)" : String(textContent.prefix(50)))…")
        print("   Tool calls: \(toolCalls.count)")
        print("   Stop reason: \(response.stop_reason.rawValue)")

        return ClaudeResponse(
            id: response.id,
            textContent: textContent,
            toolCalls: toolCalls,
            stopReason: response.stop_reason,
            content: response.content
        )
    }

    // MARK: - Private Methods

    private func callClaudeAPI(_ request: MessageRequest) async throws -> APIResponse {
        // Read on every request so a key saved in settings applies immediately
        guard let apiKey = apiKeyStore.currentKey else {
            throw AnthropicAPIError.missingAPIKey
        }

        let url = URL(string: "\(apiBaseURL)/messages")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.timeoutInterval = Self.requestTimeout

        urlRequest.httpBody = try JSONEncoder().encode(request)

        print("🔵 Sending API request…")
        print("   Model: \(request.model)")
        print("   Messages: \(request.messages.count)")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error \(httpResponse.statusCode): \(errorBody)")
            throw AnthropicAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        print("✅ API Response received")
        return try JSONDecoder().decode(APIResponse.self, from: data)
    }
}

// MARK: - Error Types

enum AnthropicAPIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key set. Tap the key icon to add one."
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let code, let message):
            return "API Error (\(code)): \(message)"
        }
    }
}
