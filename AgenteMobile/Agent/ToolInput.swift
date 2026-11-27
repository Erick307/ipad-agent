//
//  ToolInput.swift
//  AgenteMobile
//

import Foundation

/// The arguments Claude passed to a tool, with typed accessors that throw
/// when a parameter is missing or has the wrong type.
struct ToolInput {
    private let values: [String: JSONValue]

    init(_ values: [String: JSONValue]) {
        self.values = values
    }

    func string(_ key: String) throws -> String {
        guard let value = values[key]?.stringValue else {
            throw ToolInputError.missingParameter(key)
        }
        return value
    }
}

enum ToolInputError: LocalizedError, Equatable {
    case missingParameter(String)

    var errorDescription: String? {
        switch self {
        case .missingParameter(let key):
            return "Missing required string parameter '\(key)'"
        }
    }
}
