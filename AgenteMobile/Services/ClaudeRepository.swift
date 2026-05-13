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

// MARK: - API Request/Response Models

private struct MessageRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [APIMessage]
}

private struct APIMessage: Codable {
    let role: String
    let content: String
}

private struct APIResponse: Codable {
    let id: String
    let content: [ContentBlock]
    let stop_reason: String
}

private struct ContentBlock: Codable {
    let type: String
    let text: String?
}

class ClaudeRepository {
    // MARK: - Configuration
    private let apiKey: String
    private let apiBaseURL = "https://api.anthropic.com/v1"
    private let model = "claude-3-5-sonnet-20241022"
    private let maxTokens = 1024

    init(apiKey: String = "") {
        // Use provided key or load from environment
        if !apiKey.isEmpty {
            self.apiKey = apiKey
        } else {
            // For development: hardcode or read from environment
            self.apiKey = Self.loadAPIKey()
        }
    }

    // MARK: - Public Methods

    func sendMessage(
        messages: [Message],
        systemPrompt: String
    ) async throws -> ClaudeResponse {
        // Convert app messages to API format
        let apiMessages = messages.map { message in
            APIMessage(
                role: message.role,
                content: message.content
            )
        }

        // Create request
        let request = MessageRequest(
            model: model,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: apiMessages
        )

        // Send to Anthropic API
        let response = try await callClaudeAPI(request)

        // Parse response
        let textContent = response.content
            .first(where: { $0.type == "text" })?
            .text ?? "No response received"

        return ClaudeResponse(
            id: response.id,
            textContent: textContent,
            toolCalls: nil // Tool calling not implemented yet
        )
    }

    // MARK: - Private Methods

    private func callClaudeAPI(_ request: MessageRequest) async throws -> APIResponse {
        // Build URL
        let url = URL(string: "\(apiBaseURL)/messages")!

        // Build URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        // Encode request body
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error: \(httpResponse.statusCode)")
            print("Response: \(errorBody)")
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Decode response
        let decoder = JSONDecoder()
        let decodedResponse = try decoder.decode(APIResponse.self, from: data)

        return decodedResponse
    }

    private static func loadAPIKey() -> String {
        // Load from app constants
        let key = AppConstants.ANTHROPIC_API_KEY

        guard !key.isEmpty && key != "sk-ant-" else {
            print("⚠️ Warning: No API key configured. Please add your Anthropic API key to Constants.swift")
            return ""
        }

        return key
    }
}

// MARK: - Error Types

enum ClaudeAPIError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let code, let message):
            return "API Error (\(code)): \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}
