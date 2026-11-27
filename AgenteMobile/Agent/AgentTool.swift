//
//  AgentTool.swift
//  AgenteMobile
//

import Foundation

/// A tool Claude can call. Each tool describes itself to the API and runs itself.
///
/// To add a tool, write a type that conforms to this protocol and register it in
/// `AppContainer`. The agent loop and the system prompt pick it up from there.
protocol AgentTool {
    var name: String { get }
    var description: String { get }
    var inputSchema: ToolInputSchema { get }

    /// Runs the tool and returns the text Claude will read.
    /// Throw on failure: the loop sends the error back to Claude flagged with `is_error`.
    func execute(_ input: ToolInput) async throws -> String
}

extension AgentTool {
    var definition: ToolDefinition {
        ToolDefinition(name: name, description: description, input_schema: inputSchema)
    }
}
