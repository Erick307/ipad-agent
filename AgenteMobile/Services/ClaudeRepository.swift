//
//  ClaudeRepository.swift
//  AgenteMobile
//
//  Created by Erick Silva
//

import Foundation

// MARK: - JSON Value

/// A type-safe representation of any JSON value.
///
/// Used for tool `input` fields which the Anthropic API defines as a generic
/// JSON object — keys can hold strings, numbers, booleans, arrays, or nested
/// objects, not just strings.
indirect enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            // Bool must be tested before Int — true/false would otherwise decode as 1/0
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported JSON value type"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):  try container.encode(s)
        case .int(let i):     try container.encode(i)
        case .double(let d):  try container.encode(d)
        case .bool(let b):    try container.encode(b)
        case .array(let a):   try container.encode(a)
        case .object(let o):  try container.encode(o)
        case .null:           try container.encodeNil()
        }
    }

    // MARK: Convenience accessors

    var stringValue: String? {
        guard case .string(let s) = self else { return nil }
        return s
    }

    var intValue: Int? {
        switch self {
        case .int(let i):    return i
        case .double(let d): return Int(exactly: d)
        default:             return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i):    return Double(i)
        default:             return nil
        }
    }

    var boolValue: Bool? {
        guard case .bool(let b) = self else { return nil }
        return b
    }

    var arrayValue: [JSONValue]? {
        guard case .array(let a) = self else { return nil }
        return a
    }

    var objectValue: [String: JSONValue]? {
        guard case .object(let o) = self else { return nil }
        return o
    }
}

// MARK: - Tool Types (used by ChatViewModel)

struct ToolCall {
    let id: String
    let name: String
    /// Raw tool input exactly as returned by the API.
    /// Each tool has a different shape, so callers extract what they need
    /// with e.g. `input["filename"]?.stringValue`.
    let input: [String: JSONValue]
}

struct ClaudeResponse {
    let id: String
    let textContent: String
    let toolCalls: [ToolCall]?
    let stopReason: String
}

// MARK: - API Message Content Types (internal, used by ChatViewModel)

/// A plain text content block for the assistant turn.
struct APITextBlock: Encodable {
    let type: String = "text"
    let text: String
}

/// A `tool_use` content block produced by the assistant.
struct APIToolUseBlock: Encodable {
    let type: String = "tool_use"
    let id: String
    let name: String
    let input: [String: JSONValue]
}

/// A `tool_result` content block sent back in the user turn.
struct APIToolResultBlock: Encodable {
    let type: String = "tool_result"
    let tool_use_id: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case type, tool_use_id, content
    }
}

/// Type-erased `Encodable` wrapper so we can mix different block types in an array.
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

/// Message content is either a plain string (simple turns) or an array of content
/// blocks (turns that contain `tool_use` / `tool_result` / mixed content).
enum MessageContent: Encodable {
    case string(String)
    case blocks([AnyEncodable])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):  try container.encode(s)
        case .blocks(let b):  try container.encode(b)
        }
    }
}

/// An Anthropic API message with flexible content.
struct APIMessage: Encodable {
    let role: String
    let content: MessageContent

    init(role: String, text: String) {
        self.role = role
        self.content = .string(text)
    }

    init(role: String, blocks: [AnyEncodable]) {
        self.role = role
        self.content = .blocks(blocks)
    }
}

// MARK: - Private API Request/Response Models

private struct MessageRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [APIMessage]
    let tools: [ToolDefinition]?

    enum CodingKeys: String, CodingKey {
        case model, max_tokens, system, messages, tools
    }
}

private struct ToolDefinition: Encodable {
    let name: String
    let description: String
    let input_schema: ToolInputSchema

    enum CodingKeys: String, CodingKey {
        case name, description, input_schema
    }
}

private struct ToolInputSchema: Encodable {
    let type: String
    let properties: [String: PropertySchema]
    let required: [String]
}

private struct PropertySchema: Encodable {
    let type: String
    let description: String
}

private struct APIResponse: Decodable {
    let id: String
    let content: [ResponseContentBlock]
    let stop_reason: String
}

/// A content block returned by the Anthropic API.
private struct ResponseContentBlock: Decodable {
    let type: String
    let text: String?
    let id: String?
    let name: String?
    let input: [String: JSONValue]?
}

// MARK: - ClaudeRepository

class ClaudeRepository {
    private let apiKey: String
    private let apiBaseURL: String
    private let model: String
    private let maxTokens: Int

    init(apiKey: String = "") {
        if !apiKey.isEmpty {
            self.apiKey = apiKey
        } else {
            self.apiKey = Self.loadAPIKey()
        }
        self.apiBaseURL = AppConstants.ANTHROPIC_BASE_URL
        self.model = AppConstants.MODEL
        self.maxTokens = AppConstants.MAX_TOKENS
    }

    // MARK: - Public Methods

    func sendMessage(
        apiMessages: [APIMessage],
        systemPrompt: String
    ) async throws -> ClaudeResponse {
        let request = MessageRequest(
            model: model,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages: apiMessages,
            tools: [
                writeFileToolDefinition(),
                readFileToolDefinition(),
                listFilesToolDefinition()
            ]
        )

        let response = try await callClaudeAPI(request)

        let textContent = response.content
            .first(where: { $0.type == "text" })?
            .text ?? ""

        let toolCalls: [ToolCall] = response.content
            .filter { $0.type == "tool_use" }
            .compactMap { block in
                guard let toolId = block.id,
                      let toolName = block.name,
                      let inputDict = block.input else { return nil }
                return ToolCall(id: toolId, name: toolName, input: inputDict)
            }

        print("✅ Parsed response:")
        print("   Text: \(textContent.isEmpty ? "(empty)" : String(textContent.prefix(50)))…")
        print("   Tool calls: \(toolCalls.count)")
        print("   Stop reason: \(response.stop_reason)")

        return ClaudeResponse(
            id: response.id,
            textContent: textContent,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls,
            stopReason: response.stop_reason
        )
    }

    // MARK: - Tool Definitions

    private func writeFileToolDefinition() -> ToolDefinition {
        ToolDefinition(
            name: "write_file",
            description: "Creates a new file or overwrites an existing file with the given content. Use this to save or update any document on the device.",
            input_schema: ToolInputSchema(
                type: "object",
                properties: [
                    "filename": PropertySchema(
                        type: "string",
                        description: "Name of the file (e.g. 'shopping_list.md'). Use .md extension for markdown."
                    ),
                    "content": PropertySchema(
                        type: "string",
                        description: "Full content to write to the file."
                    )
                ],
                required: ["filename", "content"]
            )
        )
    }

    private func readFileToolDefinition() -> ToolDefinition {
        ToolDefinition(
            name: "read_file",
            description: "Reads and returns the full content of an existing file on the device. Use this before editing a file so you have the current content.",
            input_schema: ToolInputSchema(
                type: "object",
                properties: [
                    "filename": PropertySchema(
                        type: "string",
                        description: "Name of the file to read (e.g. 'shopping_list.md')."
                    )
                ],
                required: ["filename"]
            )
        )
    }

    private func listFilesToolDefinition() -> ToolDefinition {
        ToolDefinition(
            name: "list_files",
            description: "Lists all files saved on the device. Use this to discover what files exist before reading or editing one.",
            input_schema: ToolInputSchema(
                type: "object",
                properties: [:],
                required: []
            )
        )
    }

    // MARK: - Private Methods

    private func callClaudeAPI(_ request: MessageRequest) async throws -> APIResponse {
        let url = URL(string: "\(apiBaseURL)/messages")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        urlRequest.httpBody = try JSONEncoder().encode(request)

        print("🔵 Sending API request…")
        print("   Model: \(request.model)")
        print("   Messages: \(request.messages.count)")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ API Error \(httpResponse.statusCode): \(errorBody)")
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        print("✅ API Response received")
        return try JSONDecoder().decode(APIResponse.self, from: data)
    }

    private static func loadAPIKey() -> String {
        let key = AppConstants.ANTHROPIC_API_KEY
        guard !key.isEmpty && key != "sk-ant-" else {
            print("⚠️ Warning: No API key configured.")
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
