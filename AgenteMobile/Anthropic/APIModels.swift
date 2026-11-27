//
//  APIModels.swift
//  AgenteMobile
//
//  Types shared between the agent and the Anthropic Messages API.
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

// MARK: - Responses

/// Why Claude stopped generating, decoded from `stop_reason`.
///
/// `unknown` keeps a value added to the API after this app shipped, so a new
/// stop reason fails the turn with a clear error instead of failing to decode.
enum StopReason: Decodable, Equatable {
    case endTurn
    case maxTokens
    case stopSequence
    case toolUse
    /// A server-side tool loop (web search, code execution) hit its iteration limit.
    case pauseTurn
    case refusal
    case modelContextWindowExceeded
    case unknown(String)

    init(rawValue: String) {
        switch rawValue {
        case "end_turn": self = .endTurn
        case "max_tokens": self = .maxTokens
        case "stop_sequence": self = .stopSequence
        case "tool_use": self = .toolUse
        case "pause_turn": self = .pauseTurn
        case "refusal": self = .refusal
        case "model_context_window_exceeded": self = .modelContextWindowExceeded
        default: self = .unknown(rawValue)
        }
    }

    init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    /// The value exactly as the API sends it.
    var rawValue: String {
        switch self {
        case .endTurn: return "end_turn"
        case .maxTokens: return "max_tokens"
        case .stopSequence: return "stop_sequence"
        case .toolUse: return "tool_use"
        case .pauseTurn: return "pause_turn"
        case .refusal: return "refusal"
        case .modelContextWindowExceeded: return "model_context_window_exceeded"
        case .unknown(let value): return value
        }
    }
}

struct ToolCall {
    let id: String
    let name: String
    /// Raw tool input exactly as returned by the API.
    /// Each tool has a different shape, so tools read it through `ToolInput`.
    let input: [String: JSONValue]
}

struct ClaudeResponse {
    let id: String
    /// All `text` blocks joined, for display.
    let textContent: String
    let toolCalls: [ToolCall]
    let stopReason: StopReason
    /// Every content block exactly as returned (text, tool_use, thinking, ...).
    /// Append this to the history unchanged so no block is lost between turns.
    let content: [JSONValue]
}

// MARK: - Messages

/// A `tool_result` content block sent back in the user turn.
struct APIToolResultBlock: Encodable {
    let type: String = "tool_result"
    let tool_use_id: String
    let content: String
    /// Tells Claude the tool failed and `content` holds the error message.
    let is_error: Bool

    enum CodingKeys: String, CodingKey {
        case type, tool_use_id, content, is_error
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

// MARK: - Tool Definitions

/// A tool as the API sees it: its name, what it does, and the input it takes.
struct ToolDefinition: Encodable {
    let name: String
    let description: String
    let input_schema: ToolInputSchema
}

struct ToolInputSchema: Encodable {
    let type: String = "object"
    let properties: [String: PropertySchema]
    let required: [String]

    enum CodingKeys: String, CodingKey {
        case type, properties, required
    }
}

struct PropertySchema: Encodable {
    let type: String
    let description: String
}
